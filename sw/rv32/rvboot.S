################################################################################
##
## Filename: 	rvboot.S
##
## Project:	ZipVersa, Versa Brd implementation using ZipCPU infrastructure
##
## Purpose:	This small piece of assembly code is designed to precede the
##		library crt0.S code.  It sets the stack, and then jumps to the
##		other code.
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

#include "custom_ops.S"

.section	.start,"ax",@progbits
	.global	_rvboot
_rvboot:
reset_vec:
	# Load the global pointer
.option push
.option norelax
1:
	auipc gp, %pcrel_hi(__global_pointer$)
	addi  gp, gp, %pcrel_lo(1b)
	j	.Lcontinue_boot
.balign 16
irq_vector:

	picorv32_setq_insn(q2, x1)
	picorv32_setq_insn(q3, x2)

	lui x1, %hi(irq_regs)
	addi x1, x1, %lo(irq_regs)

	picorv32_getq_insn(x2, q0)
	sw x2,   0*4(x1)

	picorv32_getq_insn(x2, q2)
	sw x2,   1*4(x1)

	picorv32_getq_insn(x2, q3)
	sw x2,   2*4(x1)

	sw x3,   3*4(x1)
	sw x4,   4*4(x1)
	sw x5,   5*4(x1)
	sw x6,   6*4(x1)
	sw x7,   7*4(x1)
	sw x8,   8*4(x1)
	sw x9,   9*4(x1)
	sw x10, 10*4(x1)
	sw x11, 11*4(x1)
	sw x12, 12*4(x1)
	sw x13, 13*4(x1)
	sw x14, 14*4(x1)
	sw x15, 15*4(x1)
	sw x16, 16*4(x1)
	sw x17, 17*4(x1)
	sw x18, 18*4(x1)
	sw x19, 19*4(x1)
	sw x20, 20*4(x1)
	sw x21, 21*4(x1)
	sw x22, 22*4(x1)
	sw x23, 23*4(x1)
	sw x24, 24*4(x1)
	sw x25, 25*4(x1)
	sw x26, 26*4(x1)
	sw x27, 27*4(x1)
	sw x28, 28*4(x1)
	sw x29, 29*4(x1)
	sw x30, 30*4(x1)
	sw x31, 31*4(x1)

	# Call interrupt handler C function
	lui	sp,%hi(irq_stack)
	addi	sp,sp,%lo(irq_stack)
	## arg0 = address of regs
	lui	a0,%hi(irq_regs)
	addi	a0,sp,%lo(irq_regs)
	## arg1 = interrupt type
	picorv32_getq_insn(a1, q1)

	// Call to the C IRQ function
	jal ra, irq

	// Restore registers

	// new irq_regs address returned from C code in a0
	addi x1, a0, 0

	lw x2,   0*4(x1)
	picorv32_setq_insn(q0, x2)

	lw x2,   1*4(x1)
	picorv32_setq_insn(q1, x2)

	lw x2,   2*4(x1)
	picorv32_setq_insn(q2, x2)

	lw x3,   3*4(x1)
	lw x4,   4*4(x1)
	lw x5,   5*4(x1)
	lw x6,   6*4(x1)
	lw x7,   7*4(x1)
	lw x8,   8*4(x1)
	lw x9,   9*4(x1)
	lw x10, 10*4(x1)
	lw x11, 11*4(x1)
	lw x12, 12*4(x1)
	lw x13, 13*4(x1)
	lw x14, 14*4(x1)
	lw x15, 15*4(x1)
	lw x16, 16*4(x1)
	lw x17, 17*4(x1)
	lw x18, 18*4(x1)
	lw x19, 19*4(x1)
	lw x20, 20*4(x1)
	lw x21, 21*4(x1)
	lw x22, 22*4(x1)
	lw x23, 23*4(x1)
	lw x24, 24*4(x1)
	lw x25, 25*4(x1)
	lw x26, 26*4(x1)
	lw x27, 27*4(x1)
	lw x28, 28*4(x1)
	lw x29, 29*4(x1)
	lw x30, 30*4(x1)
	lw x31, 31*4(x1)

	picorv32_getq_insn(x1, q1)
	picorv32_getq_insn(x2, q2)

	picorv32_retirq_insn()



.Lcontinue_boot:
	# Load the stack pointer
	la	sp,_top_of_stack
	# Make sure bus errors cause an interrupt
	li	x5,-1
	picorv32_maskirq_insn(x5,x5)
	andi	x5,x5,~4
	picorv32_maskirq_insn(x5,x5)
	# Copy the initialized data from flash to its location in ram
	jal	_bootloader
	# Clear any other registers
	#  Don't need to clear X0, hardware already does that
	#  Don't need to clear x1, we'll use it in a moment
	#  Don't want to clear x2 (sp) or x3 (gp), they'll be set on startup
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
	# Jump to the traditional crt0.S code
	jal	_start
	.global	_sim_shutdown
_sim_shutdown:			# Halt the Verilator Simulation
	# First flush any remaining UART characters through the interface
.Lflush_uart:
	la	a0,_uart
	lw	s0,12(a0)
	andi	s0,s0,256
	bnez	s0,.Lflush_uart
	;
	# Now set the halt bit in the external GPIO register
	la	a0,_gpio	# Load the _gpio register into a0
	li	s0,0x40004	# Turn on the HALT output in the GPIO register
	sw	s0,0(a0)
	.global	_hw_shutdown	# Repeat until done
#
# Halt the CPU by creating an endless loop
_hw_shutdown:
	jal	_hw_shutdown

.section	.irq
	.global	irq_regs
irq_regs:
	.fill 32,4
	.fill 128,4
	.global	irq_stack
irq_stack:
