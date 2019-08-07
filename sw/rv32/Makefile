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
PROGRAMS := gettysburg
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
SOURCES := gettysburg.c txfns.c
HEADERS := $(foreach hdr,$(subst .c,.o,$(SOURCES)),$(wildcard $(hdr))) board.h
INCS    := -I../../rtl -I.
LFLAGS  := -T board.ld
LFLAGSD := -T sdram.ld
CFLAGS  := -O3 $(INCS)
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
	$(OBJDUMP) -S -Dr $^ > $@

gettysburg: $(OBJDIR)/gettysburg.o $(OBJDIR)/txfns.o $(OBJDIR)/crt0.o board.ld
	$(CC) $(CFLAGS) $(BAREMETAL) $(LFLAGS) $(OBJDIR)/crt0.o $(OBJDIR)/gettysburg.o $(OBJDIR)/txfns.o -o $@

simple_ping: $(OBJDIR)/simple_ping.o
simple_ping: $(OBJDIR)/arp.o $(OBJDIR)/ipcksum.o
	$(CC) -Wl,-Map=simple_ping.map $(CFLAGS) $(LFLAGS) $^ -o $@

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
	rm -rf $(OBJDIR)/

$(OBJDIR)/depends.txt: tags
	$(build-depends)

.PHONY: depends
depends:
	$(build-depends)

ifneq ($(MAKECMDGOALS),clean)
-include $(OBJDIR)/depends.txt
endif
