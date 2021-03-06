################################################################################
##
## Filename:	./rtl.make.inc
##
## Project:	ZipVersa, Versa Brd implementation using ZipCPU infrastructure
##
## DO NOT EDIT THIS FILE!
## Computer Generated: This file is computer generated by AUTOFPGA. DO NOT EDIT.
## DO NOT EDIT THIS FILE!
##
## CmdLine:	autofpga autofpga -d -o . allclocks.txt global.txt dlyarbiter.txt version.txt buserr.txt pwrcount.txt bustimer.txt wbfft.txt spio.txt gpio.txt wbuconsole.txt bkram.txt flash.txt picorv.txt pic.txt mdio1.txt enet.txt enetscope.txt flashscope.txt mem_flash_bkram.txt mem_bkram_only.txt
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
RVCPUD := picorv
RVCPU  := $(addprefix $(RVCPUD)/,picorv32.v wb_picorv32.v)
GPIO := wbgpio.v

FLASH := qflexpress.v

WBUBUSD := wbubus
WBUBUS  := $(addprefix $(WBUBUSD)/,wbuconsole.v wbufifo.v wbucompactlines.v wbucompress.v wbudecompress.v wbudeword.v wbuexec.v wbuidleint.v wbuinput.v wbuoutput.v wbureadcw.v wbusixchar.v wbutohex.v wbconsole.v)
NETDELAY := ecpnetdly.v

FFTD := fft
FFT  := $(addprefix $(FFTD)/,wbfft.v bimpy.v butterfly.v convround.v fftmain.v fftstage.v hwbfly.v laststage.v longbimpy.v qtrstage.v shiftaddmpy.v)
BUSPICD := cpu
BUSPIC  := $(addprefix $(BUSPICD)/,icontrol.v)
ZIPTIMERD := cpu
ZIPTIMER  := $(addprefix $(ZIPTIMERD)/,ziptimer.v)
TFRVALUE := tfrvalue.v

SPIO := spio.v debouncer.v ledbouncer.v

CONSOLED := wbubus
CONSOLE  := $(addprefix $(CONSOLED)/,txuartlite.v rxuartlite.v ufifo.v)
BKRAM := memdev.v

ENETMDIO := enetctrl.v

BUSDLYD := cpu
BUSDLY  := $(addprefix $(BUSDLYD)/,busdelay.v wbpriarbiter.v)
SCOPE := wbscope.v

ENETD := enet
ENET  := $(addprefix $(ENETD)/,enetpackets.v addecrc.v addemac.v addepad.v addepreamble.v txespeed.v txeaddr.v rxecrc.v rxehwmac.v rxeipchk.v rxemin.v rxepreambl.v rxewrite.v ecpiddr.v ecpoddr.v)
SCOPC := wbscopc.v

VFLIST := main.v  $(RVCPU) $(GPIO) $(FLASH) $(WBUBUS) $(NETDELAY) $(FFT) $(BUSPIC) $(ZIPTIMER) $(TFRVALUE) $(SPIO) $(CONSOLE) $(BKRAM) $(ENETMDIO) $(BUSDLY) $(SCOPE) $(ENET) $(SCOPC)
AUTOVDIRS :=  -y picorv -y wbubus -y fft -y cpu -y enet
