typedef 12 PciBarAddrSize;
typedef 64 PciBarDataSize;
typedef 64 PciDmaAddrSize;
typedef 64 PciDmaDataSize;

typedef Bit#(PciDmaAddrSize) PciDmaAddr;
PciDmaAddr pciDmaWord = fromInteger(valueOf(PciDmaDataSize) / 8);
