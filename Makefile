AS=asl
P2BIN=p2bin
SRC=patch.s
BSPLIT=bsplit
MAME=mame

ASFLAGS=-i . -n -U

.PHONY: all clean prg.bin

all: prg.bin

prg.orig: u42_ver.2.orig u41_ver.2.orig
	stat u42_ver.2.orig
	stat u41_ver.2.orig
	$(BSPLIT) c u42_ver.2.orig u41_ver.2.orig prg.orig

prg.o: prg.orig
	$(AS) $(SRC) $(ASFLAGS) -o prg.o

prg.bin: prg.o
	$(P2BIN) $< $@ -r \$$-0xFFFFF
	$(BSPLIT) s prg.bin u42_ver.2 u41_ver.2

test: prg.bin
	$(MAME) -debug espradej

package: prg.bin
	zip espradej.zip esp_* u41_ver.2 u42_ver.2

clean:
	@-rm esprade.zip
	@-rm prg.bin
	@-rm prg.o
	@-rm prg.orig
	@-cp u42_ver.2.orig u42_ver.2
	@-cp u41_ver.2.orig u41_ver.2
