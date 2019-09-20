################################################################################
##
## Filename:	rv32/Makefile
##
## Project:	ZipVersa, Versa Brd implementation using ZipCPU infrastructure
##
## Purpose:	Direct and guide the building of the RV32 programs found in
##		this directory
##
## Creator:	Dan Gisselquist, Ph.D.
##		Gisselquist Technology, LLC
##
################################################################################
##
## Copyright (C) 2019, Gisselquist Technology, LLC
##
## This program is free software (firmware): you can redistribute it and/or
## modify it under the terms of  the GNU General Public License as published
## by the Free Software Foundation, either version 3 of the License, or (at
## your option) any later version.
##
## This program is distributed in the hope that it will be useful, but WITHOUT
## ANY WARRANTY; without even the implied warranty of MERCHANTIBILITY or
## FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
## for more details.
##
## You should have received a copy of the GNU General Public License along
## with this program.  (It's in the $(ROOT)/doc directory.  Run make with no
## target there if the PDF file isn't present.)  If not, see
## <http://www.gnu.org/licenses/> for a copy.
##
## License:	GPL, v3, as defined and found on www.gnu.org,
##		http://www.gnu.org/licenses/gpl.html
##
##
################################################################################
##
##
.PHONY: all
PROGRAMS := gettysburg job pingtest fftsimtest fftmain
all:	$(PROGRAMS)
#
#
CROSS := riscv32-unknown-elf
CC	:=$(CROSS)-gcc
AS	:=$(CROSS)-as
LD	:=$(CROSS)-ld
NM	:=$(CROSS)-nm
OBJDIR	:= obj-rv32
RDELF	:= $(CROSS)-readelf
OBJDUMP := $(CROSS)-objdump
SUBMAKE:= $(MAKE) --no-print-directory -C
BAREMETAL:= -ffreestanding -nostdlib
#
#
NETPROTO:= pkt.c ethproto.c arp.c ipproto.c ipcksum.c icmp.c udpproto.c
NETLIB  := $(addprefix $(OBJDIR)/,$(subst .c,.o,$(NETPROTO)))
SOURCES := gettysburg.c txfns.c pingtest.c fftsimtest.c fftmain.c $(NETPROTO)
HEADERS := $(foreach hdr,$(subst .c,.o,$(SOURCES)),$(wildcard $(hdr))) board.h
INCS    := -I../../rtl -I.
LFLAGS  := -T board.ld
LFLAGSD := -T sdram.ld
CFLAGS  := -O3 $(INCS)
# RVLIB   := $(OBJDIR)/crt0.o syscalls.c
RVLIB   := $(OBJDIR)/rvboot.o $(OBJDIR)/bootloader.o $(OBJDIR)/syscalls.o $(OBJDIR)/irq.o $(OBJDIR)/txfns.o
MAP     := -Wl,-Map=$(OBJDIR)/$@.map
#
# For source analysis, the following macros are defined:
#

%.o: $(OBJDIR)/%.o
$(OBJDIR)/%.o: %.c
	$(mk-objdir)
	$(CC) $(CFLAGS) -c $< -o $@
$(OBJDIR)/%.o: %.S
	$(mk-objdir)
	$(AS) -march=rv32imc $< -o $@
$(OBJDIR)/rvboot.o: rvboot.S
	$(mk-objdir)
	$(CC) -c -I ../../../picorv32/firmware -march=rv32imc $< -o $@
$(OBJDIR)/bootloader.o: bootloader.c
	$(mk-objdir)
	$(CC) $(CFLAGS) $(BAREMETAL) -c $< -o $@
# $(OBJDIR)/hello.o: hello.c
#	$(mk-objdir)
#	$(CC) -O3 -c $< -o $@
$(OBJDIR)/txfns.o: txfns.c
	$(mk-objdir)
	$(CC) $(CFLAGS) $(BAREMETAL) -c $< -o $@
$(OBJDIR)/gettysburg.o: gettysburg.c
	$(mk-objdir)
	$(CC) $(CFLAGS) $(BAREMETAL) -c $< -o $@
$(OBJDIR)/%.s: %.c
	$(mk-objdir)
	$(CC) $(CFLAGS) -S $< -o $@
$(OBJDIR)/%.txt: $(OBJDIR)/%.o
	bash -c "$(RDELF) -a $^ ; $(OBJDUMP) -S -Dr $^ " | tee $@
%.txt: %
	bash -c "$(RDELF) -a $^ ; $(OBJDUMP) -S -Dr $^ " > $@

gettysburg: $(OBJDIR)/gettysburg.o $(OBJDIR)/txfns.o $(OBJDIR)/crt0.o board.ld
	$(CC) $(CFLAGS) $(BAREMETAL) $(LFLAGS) $(OBJDIR)/crt0.o $(OBJDIR)/gettysburg.o $(OBJDIR)/txfns.o -o $@

job: $(OBJDIR)/job.o $(RVLIB)
	$(CC) $(CFLAGS) $(LFLAGS) $(RVLIB) $(OBJDIR)/job.o -o $@

pingtest: $(OBJDIR)/pingtest.o $(RVLIB)
pingtest: $(NETLIB)
	$(CC) $(CFLAGS) $(LFLAGS) -Wl,-Map=$(OBJDIR)/pingtest.map $^ -o $@

fftsimtest: $(OBJDIR)/fftsimtest.o $(RVLIB)
fftsimtest: $(NETLIB)
	$(CC) $(CFLAGS) $(LFLAGS) -Wl,-Map=$(OBJDIR)/fftsimtest.map $^ -o $@

fftmain: $(OBJDIR)/fftmain.o $(RVLIB)
fftmain: $(NETLIB)
	$(CC) $(CFLAGS) $(LFLAGS) -Wl,-Map=$(OBJDIR)/fftmain.map $^ -o $@

define	mk-objdir
	@bash -c "if [ ! -e $(OBJDIR) ]; then mkdir -p $(OBJDIR)/; fi"
endef

define	build-depends
	@echo "Building dependency file(s)"
	$(mk-objdir)
	@$(CC) $(CFLAGS) -MM $(SOURCES) > $(OBJDIR)/xdepends.txt
	@sed -e 's/^.*.o: /$(OBJDIR)\/&/' < $(OBJDIR)/xdepends.txt > $(OBJDIR)/depends.txt
	@rm $(OBJDIR)/xdepends.txt
endef

tags: $(SOURCES) $(HEADERS)
	@echo "Generating tags"
	@ctags $(SOURCES) $(HEADERS)

.PHONY: clean
clean:
	rm -f $(PROGRAMS)
	rm -rf $(addsuffix .map,$(PROGRAMS))
	rm -rf $(addsuffix .txt,$(PROGRAMS))
	rm -rf $(OBJDIR)/ tags

$(OBJDIR)/depends.txt: tags
	$(build-depends)

.PHONY: depends
depends:
	$(build-depends)

ifneq ($(MAKECMDGOALS),clean)
-include $(OBJDIR)/depends.txt
endif
