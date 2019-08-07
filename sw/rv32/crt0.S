.section	.start,"ax",@progbits
	.global	_start
_start:
	# Load the stack pointer
	la	sp,_top_of_stack
	# Clear the BSS segment
	la	a0,_ram_image_end
	la	a1,_bss_image_end
	li	s0,0
.Lfill_bss_loop:
	sb	s0,0(a0)
	addi	a0,a0,1
	blt	a0,a1,.Lfill_bss_loop
	# Jump to the main program
	jal	main
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
