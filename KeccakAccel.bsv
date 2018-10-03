import BUtils::*;
import FIFOF::*;
import GetPut::*;
import Connectable::*;
import AccelConfig::*;
import AvalonSlave::*;
import AvalonMaster::*;
import Keccak::*;
import KeccakGlobals::*;

typedef AvalonRequest#(PciDmaAddrSize, PciDmaDataSize) DmaReq;

interface KeccakAccel;
	(* prefix="" *)
	interface AvalonSlaveWires#(PciBarAddrSize, PciBarDataSize) barWires;
	(* prefix="dma" *)
	interface AvalonMasterWires#(PciDmaAddrSize, PciDmaDataSize) dmaWires;
	(* always_ready, prefix="", result="ins" *)
	method Bit#(1) ins;
endinterface

(* synthesize *)
module mkKeccakAccel(KeccakAccel);
	FIFOF#(void) irqFifo <- mkFIFOF;
	AvalonSlave#(PciBarAddrSize, PciBarDataSize) pcibar <- mkAvalonSlave;
	AvalonMaster#(PciDmaAddrSize, PciDmaDataSize) pcidma <- mkAvalonMaster;
	FIFOF#(Bit#(PciDmaDataSize)) pcidmaResp <- mkFIFOF;

	let keccak <- mkKeccak;
	FIFOF#(void) pendingPermutation <- mkFIFOF;

	LBit#(Rate) permutCounterRst = fromInteger(rate - 1);
	Reg#(LBit#(Rate)) permutCounter <- mkReg(permutCounterRst);

	Reg#(PciDmaAddr) dmaAddr <- mkReg(0);
	Reg#(PciDmaAddr) dmaStopAddr <- mkReg(0);
	FIFOF#(Tuple2#(Bool, PciDmaAddr)) dmaReadInFlight <- mkSizedFIFOF(16);

	function Action startPermutationIfNeeded =
		when(!pendingPermutation.notEmpty, action
			if (permutCounter == 0) begin
				pendingPermutation.enq(?);
				permutCounter <= permutCounterRst;
			end else begin
				permutCounter <= permutCounter - 1;
			end
		endaction);

	mkConnection(pcidma.busServer.response, toPut(pcidmaResp));

	rule do_permutation;
		keccak.go;
		pendingPermutation.deq;
	endrule

	rule getInput (dmaAddr < dmaStopAddr && !pcidmaResp.notEmpty);
		pcidma.busServer.request.put(AvalonRequest { command: Read, addr: dmaAddr, data: ? });
		let newDmaAddr = dmaAddr + pciDmaWord;
		dmaReadInFlight.enq(tuple2(newDmaAddr >= dmaStopAddr, dmaAddr));
		dmaAddr <= newDmaAddr;
	endrule

	rule putOutput;
		let data <- toGet(pcidmaResp).get;
		let stream <- keccak.squeeze;
		let {last, addr} <- toGet(dmaReadInFlight).get;
		if (last)
			irqFifo.enq(?);
		pcidma.busServer.request.put(AvalonRequest { command: Write, addr: addr, data: data ^ stream });
		startPermutationIfNeeded;
	endrule

	(* preempts = "handleCmd, (getInput, putOutput)" *)
	rule handleCmd;
		let cmd <- pcibar.busClient.request.get;
		(* split *)
		case (cmd.command)
		Write:
			case (cmd.addr) matches
			0: // reset
				action
					keccak.init;
					irqFifo.clear;
					permutCounter <= fromInteger(rate);
				endaction
			1: // absorb word (then start permutation if needed)
				action
					keccak.absorb(cmd.data);
					startPermutationIfNeeded;
				endaction
			2: // set DMA address
				action
					dmaAddr <= cmd.data;
					dmaStopAddr <= cmd.data;
				endaction
			3: // set DMA stop address and start squeezing
				action
					dmaStopAddr <= cmd.data;
				endaction
			4: // acknowledge IRQ was received
				action
					irqFifo.clear;
				endaction
			endcase
		Read:
			case (cmd.addr) matches
			default:
				action
					pcibar.busClient.response.put(64'hBADC0FFEDEADC0DE);
				endaction
			endcase
		endcase
	endrule

	interface barWires = pcibar.slaveWires;
	interface dmaWires = pcidma.masterWires;
	method ins = irqFifo.notEmpty ? 1 : 0;
endmodule
