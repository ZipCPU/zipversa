################################################################################
##
## Filename: 	rtl/helloworld/Makefile
##
## Project:	OpenArty, an entirely open SoC based upon the Arty platform
##
## Purpose:	To direct the Verilator build of the SoC sources.  The result
##		is C++ code (built by Verilator), that is then built (herein)
##	into a library.
##
##
## Creator:	Dan Gisselquist, Ph.D.
##		Gisselquist Technology, LLC
##
################################################################################
##
## Copyright (C) 2015-2019, Gisselquist Technology, LLC
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
all:
CXX := g++
YOSYS    := yosys
NEXTPNR  := nextpnr-ecp5
VDIRFB   := obj_dir
VERILATOR:= verilator
TOPLVL   := speechfifo
YSLOG    := $(TOPLVL).yslog
VLOGFIL  := $(TOPLVL).v
JSON     := $(TOPLVL).json
ECPCFG   := $(TOPLVL).cfg
SVF      := $(TOPLVL).svf
LPF      := speechfifo.lpf
VFLAGS   := -Wall --MMD --trace -y ../wbuart -cc
###
#
.PHONY: all Vspeechfifo program
all: speechfifo_tb $(SVF)

################################################################################
#
#
################################################################################
#
#
mkspeech: mkspeech.cpp
	$(CXX) mkspeech.cpp -o mkspeech

psalm.hex: psalm.txt mkspeech
	mkspeech psalm.txt -o psalm.hex

################################################################################
#
#	Build the Verilator-based simulation
#
################################################################################
#
#
Vspeechfifo: $(VDIRFB)/Vspeechfifo__ALL.a

$(VDIRFB)/Vspeechfifo.h: speechfifo.v psalm.hex
	$(VERILATOR) $(VFLAGS) speechfifo.v

$(VDIRFB)/Vspeechfifo__ALL.a: $(VDIRFB)/Vspeechfifo.cpp psalm.hex

$(VDIRFB)/V%.mk:  $(VDIRFB)/%.h
$(VDIRFB)/V%.h:   $(VDIRFB)/%.cpp
$(VDIRFB)/V%.cpp: %.v
	$(VERILATOR) $(VFLAGS) $*.v

$(VDIRFB)/V%__ALL.a: $(VDIRFB)/V%.cpp
	cd $(VDIRFB); make -f V$*.mk

VROOT := /usr/share/verilator/include
VFILES:= verilated.cpp
TBSOURCES := speechfifo_tb.cpp uartsim.cpp $(VROOT)/verilated_vcd_c.cpp $(VROOT)/verilated.cpp
speechfifo_tb: $(TBSOURCES) $(VDIRFB)/Vspeechfifo__ALL.a
	g++ -I $(VROOT) -I $(VDIRFB) $(TBSOURCES) $(VDIRFB)/Vspeechfifo__ALL.a -o $@

################################################################################
#
#	Build and program the actual binary onto the real hardware
#
################################################################################
#
#
$(JSON): $(VDIRFB)/Vspeechfifo__ALL.a
	$(YOSYS) -ql $(YSLOG) -p 'synth_ecp5 -json $(JSON) -top speechfifo' speechfifo.v ../wbuart/wbuart.v ../wbuart/txuart.v ../wbuart/rxuart.v ../wbuart/ufifo.v

$(ECPCFG): $(JSON)
	$(NEXTPNR) --json $(JSON) --freq 100 --lpf $(LPF) --textcfg $@ --um-45k --package CABGA381

$(SVF): $(ECPCFG)
	ecppack --svf-rowsize 100000 --svf $(SVF) $< $@

OPENOCD:= openocd -f openocd.cfg -c
program: $(SVF)
	$(OPENOCD) "transport select jtag; init; svf $<; exit"

################################################################################
#
#
################################################################################
#
#
tags: $(wildcard *.v) $(wildcard $(RTLDR)/*.v)
	ctags *.v $(RTLDR)/*.v


.PHONY: clean
clean:
	rm -rf tags $(VDIRFB) speechfifo_tb mkspeech psalm.hex
	rm -rf *.vcd speechfifo.svf speechfifo.json speechfifo.cfg
	rm -rf speechfifo.yslog

DEPS := $(wildcard $(VDIRFB)/*.d)

ifneq ($(MAKECMDGOALS),clean)
ifneq ($(DEPS),)
include $(DEPS)
endif
endif
