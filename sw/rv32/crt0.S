################################################################################
##
## Filename: 	crt0.S
##
## Project:	ZipVersa, Versa Brd implementation using ZipCPU infrastructure
##
## Purpose:	This small piece of assembly code starts a program.  As written,
##		the program must already exist in memory space.  This code
##	just clears the BSS segment--appropriate if the code is located in
##	flash.  Once done, main() is called with argc=0, argv=NULL,
##	and envp=NULL.  When (if) main returns, the program wants for the
##	serial port to flush, and then sets the halt wire (present only in
##	VERILATOR based simulations).  This will then halt any current
##	(or ongoing) simulation.
##
## Creator:	Dan Gisselquist, Ph.D.
##		Gisselquist Technology, LLC
##
################################################################################
##
## Copyright (C) 2019, Gisselquist Technology, LLC
##
## This program is free software (firmware): you can redistribute it and/or
## modify it under the terms of the GNU General Public License as published
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

.section	.start,"ax",@progbits
	.global	_rvboot
_rvboot:
	# Initialize the global pointer
.option push
.option norelax
1:
	auipc gp,%pcrel_hi(__global_pointer$)
	addi  gp,gp,%pcrel_lo(1b)
.option pop
	# Load the stack pointer
	la	sp,_top_of_stack
	# Clear any other registers
	#  Don't need to clear X0, hardware already does that
	#  Don't need to clear x1, we'll use it in a moment
	#  Don't want to clear x2 (sp) or x3 (gp), since we just set them
	li	x4,0
	li	x5,0
	li	x6,0
	li	x7,0
	li	x8,0
	li	x9,0
	li	x10,0
	li	x11,0
	li	x12,0
	li	x13,0
	li	x14,0
	li	x15,0
	li	x16,0
	li	x17,0
	li	x18,0
	li	x19,0
	li	x20,0
	li	x21,0
	li	x22,0
	li	x23,0
	li	x24,0
	li	x25,0
	li	x26,0
	li	x27,0
	li	x28,0
	li	x29,0
	li	x30,0
	li	x31,0
	# Clear the BSS segment
	la	t0,_ram_image_end
	la	t1,_bss_image_end
	li	t2,0
.Lfill_bss_loop:
	sb	t2,0(t0)
	addi	t0,t0,1
	blt	t0,t1,.Lfill_bss_loop
	# Set the arguments for main
	li	a0,0	# ARGC = 0
	li	a1,0	# ARGV = 0
	li	a2,0	# ENVP = 0;
	# Jump to the main program
	nop
	jal	main
	.global	_sim_shutdown
_sim_shutdown:			# Halt the Verilator Simulation
	# First flush any remaining UART characters through the interface
	la	t0,_uart
.Lflush_uart:
	lw	t1,12(t0)
	andi	t1,t1,256
	bnez	t1,.Lflush_uart
	;
	# Now set the halt bit in the external GPIO register
	la	t0,_gpio	# Load the _gpio register into a0
	li	t1,0x40004	# Turn on the HALT output in the GPIO register
	sw	t1,0(t0)
	.global	_hw_shutdown	# Repeat until done
#
# Halt the CPU by creating an endless loop
_hw_shutdown:
	jal	_hw_shutdown
