BSCFLAGS=-aggressive-conditions \
	-steps-warn-interval 2000000 -steps-max-intervals 6000000 \
	-opt-undetermined-vals -unspecified-to X
BSCLIBS=keccak-bsv:avalon
BSCLFLAGS=-vdir . -bdir . -simdir . \
	-suppress-warnings S0089:S0073
SRCFILES=$(wildcard *.bsv keccak-bsv/*.bsv avalon/*.bsv)

all: mkKeccakAccel.v

mkKeccakAccel.v: KeccakAccel.bsv $(SRCFILES)
	bsc $(BSCFLAGS) $(BSCLFLAGS) -u -verilog -p +:$(BSCLIBS) $<
	cp $@ ./AccelSystem/synthesis/submodules/

clean:
	$(MAKE) -C keccak-bsv clean
	rm -f *.bo *.ba mk*.v mk*.cxx mk*.h mk*.o model_*.cxx model_*.h model_*.o
	rm -f tb tb.so
