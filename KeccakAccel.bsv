import BUtils::*;
import FIFOF::*;
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
	Reg#(Bool) irqFlag <- mkReg(False);
	AvalonSlave#(PciBarAddrSize, PciBarDataSize) pcibar <- mkAvalonSlave;
	AvalonMaster#(PciDmaAddrSize, PciDmaDataSize) pcidma <- mkAvalonMaster;

	let keccak <- mkKeccak;
	Reg#(Bool) startPermutation <- mkReg(False);

	Reg#(LBit#(Rate)) permutCounter <- mkRegU;

	Reg#(PciDmaAddr) dmaAddr <- mkReg(0);
	Reg#(PciDmaAddr) dmaStopAddr <- mkReg(0);
	FIFOF#(PciDmaAddr) dmaReadInFlight <- mkSizedFIFOF(16);

	function Action startPermutationIfNeeded =
		when(!startPermutation, action
			if (permutCounter == 0) begin
				startPermutation <= True;
				permutCounter <= fromInteger(rate);
			end else begin
				permutCounter <= permutCounter - 1;
			end
		endaction);

	rule do_permutation (startPermutation);
		keccak.go;
		startPermutation <= False;
	endrule

	rule getInput (dmaAddr < dmaStopAddr);
		pcidma.busServer.request.put(AvalonRequest { command: Read, addr: dmaAddr, data: ? });
		dmaReadInFlight.enq(dmaAddr);
		dmaAddr <= dmaAddr + pciDmaWord;
	endrule

	(* preempts = "putOutput, (getInput)" *)
	rule putOutput;
		let data <- pcidma.busServer.response.get;
		let stream <- keccak.squeeze;
		let addr <- toGet(dmaReadInFlight).get;
		if (addr == dmaAddr)
			irqFlag <= True;  // the last one
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
					irqFlag <= False;
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
					irqFlag <= False;
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
	method ins = irqFlag ? 1 : 0;
endmodule
