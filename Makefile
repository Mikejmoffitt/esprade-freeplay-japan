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

gaia: prg.bin
	mkdir -p ../gaia
# Program
	cp u42_ver.2 ../gaia/prg1.127
	cp u41_ver.2 ../gaia/prg2.128
# Objects
	cp esp_u63.u63 ../gaia/obj1.736
	cp esp_u64.u64 ../gaia/obj2.738
#	cp esp_u65.u65 ../gaia/
#	cp esp_u66.u66 ../gaia/
# Backgrounds
	cp esp_u54.u54 ../gaia/bg1.989
#	cp esp_u55.u55 ../gaia/
	cp esp_u52.u52 ../gaia/bg2.995
#	cp esp_u53.u53 ../gaia/
	cp esp_u51.u51 ../gaia/bg3.998
# Sound
	cp esp_u19.u19 ../gaia/snd1.447
	cp esp_u19.u19 ../gaia/snd2.454
	cp esp_u19.u19 ../gaia/snd3.455

test: gaia
	$(MAME) -debug gaia

clean:
	@-rm prg.bin
	@-rm prg.o
	@-rm prg.orig
	@-cp u42_ver.2.orig u42_ver.2
	@-cp u41_ver.2.orig u41_ver.2
	@-rm -rf ../gaia.
