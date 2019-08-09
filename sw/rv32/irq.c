// This is free and unencumbered software released into the public domain.
//
// Anyone is free to copy, modify, publish, use, compile, sell, or
// distribute this software, either in source code form or as a compiled
// binary, for any purpose, commercial or non-commercial, and by any
// means.

// #include "firmware.h"
#include <stdint.h>
#include <stdbool.h>
#include "txfns.h"

uint32_t *irq(uint32_t *regs, uint32_t irqs)
{
	static unsigned int ext_irq_4_count = 0;
	static unsigned int ext_irq_5_count = 0;
	static unsigned int timer_irq_count = 0;

	// checking compressed isa q0 reg handling
	if ((irqs & 6) != 0) {
		uint32_t pc = (regs[0] & 1) ? regs[0] - 3 : regs[0] - 4;
		uint32_t instr = *(uint16_t*)pc;

		if ((instr & 3) == 3)
			instr = instr | (*(uint16_t*)(pc + 2)) << 16;

		if (((instr & 3) != 3) != (regs[0] & 1)) {
			txstr("Mismatch between q0 LSB and decoded instruction word! q0=0x");
			txhex(regs[0]);
			txstr(", instr=0x");
			if ((instr & 3) == 3)
				txhex(instr);
			else
				txhex(instr);
			txstr("\n");
			__asm__ volatile ("ebreak");
		}
	}

	if ((irqs & (1<<4)) != 0) {
		ext_irq_4_count++;
		// txstr("[EXT-IRQ-4]");
	}

	if ((irqs & (1<<5)) != 0) {
		ext_irq_5_count++;
		// txstr("[EXT-IRQ-5]");
	}

	if ((irqs & 1) != 0) {
		timer_irq_count++;
		// txstr("[TIMER-IRQ]");
	}

	if ((irqs & 6) != 0)
	{
		uint32_t pc = (regs[0] & 1) ? regs[0] - 3 : regs[0] - 4;
		uint32_t instr = *(uint16_t*)pc;

		if ((instr & 3) == 3)
			instr = instr | (*(uint16_t*)(pc + 2)) << 16;

		txstr("\n");
		txstr("------------------------------------------------------------\n");

		if ((irqs & 2) != 0) {
			if (instr == 0x00100073 || instr == 0x9002) {
				txstr("EBREAK instruction at 0x");
				txhex(pc);
				txstr("\n");
			} else {
				txstr("Illegal Instruction at 0x");
				txhex(pc);
				txstr(": 0x");
				txhex(instr);
				txstr("\n");
			}
		}

		if ((irqs & 4) != 0) {
			txstr("Bus error in Instruction at 0x");
			txhex(pc);
			txstr(": 0x");
			txhex(instr);
			txstr("\n");
		}

		for (int i = 0; i < 8; i++)
		for (int k = 0; k < 4; k++)
		{
			int r = i + k*8;

			if (r == 0) {
				txstr("pc  ");
			} else
			if (r < 10) {
				txchr('x');
				txchr('0' + r);
				txchr(' ');
				txchr(' ');
			} else
			if (r < 20) {
				txchr('x');
				txchr('1');
				txchr('0' + r - 10);
				txchr(' ');
			} else
			if (r < 30) {
				txchr('x');
				txchr('2');
				txchr('0' + r - 20);
				txchr(' ');
			} else {
				txchr('x');
				txchr('3');
				txchr('0' + r - 30);
				txchr(' ');
			}

			txhex(regs[r]);
			txstr(k == 3 ? "\n" : "    ");
		}

		txstr("------------------------------------------------------------\n");

		txstr("Number of fast external IRQs counted: ");
		txdecimal(ext_irq_4_count);
		txstr("\n");

		txstr("Number of slow external IRQs counted: ");
		txdecimal(ext_irq_5_count);
		txstr("\n");

		txstr("Number of timer IRQs counted: ");
		txdecimal(timer_irq_count);
		txstr("\n");

		__asm__ volatile ("ebreak");
	}

	return regs;
}

