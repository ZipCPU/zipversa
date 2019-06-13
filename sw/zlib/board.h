////////////////////////////////////////////////////////////////////////////////
//
// Filename:	./board.h
//
// Project:	ZipVersa, Versa Brd implementation using ZipCPU infrastructure
//
// DO NOT EDIT THIS FILE!
// Computer Generated: This file is computer generated by AUTOFPGA. DO NOT EDIT.
// DO NOT EDIT THIS FILE!
//
// CmdLine:	autofpga autofpga -d -o . clock.txt global.txt dlyarbiter.txt version.txt buserr.txt pic.txt pwrcount.txt spio.txt rtclight.txt wbuconsole.txt bkram.txt zipmaster.txt mem_flash_bkram.txt mem_bkram_only.txt
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2019, Gisselquist Technology, LLC
//
// This program is free software (firmware): you can redistribute it and/or
// modify it under the terms of  the GNU General Public License as published
// by the Free Software Foundation, either version 3 of the License, or (at
// your option) any later version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTIBILITY or
// FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
// for more details.
//
// You should have received a copy of the GNU General Public License along
// with this program.  (It's in the $(ROOT)/doc directory.  Run make with no
// target there if the PDF file isn't present.)  If not, see
// <http://www.gnu.org/licenses/> for a copy.
//
// License:	GPL, v3, as defined and found on www.gnu.org,
//		http://www.gnu.org/licenses/gpl.html
//
//
////////////////////////////////////////////////////////////////////////////////
//
//
#ifndef	BOARD_H
#define	BOARD_H

// And, so that we can know what is and isn't defined
// from within our main.v file, let's include:
#include <design.h>

#include <design.h>
#include <cpudefs.h>

#define	_HAVE_ZIPSYS
#define	PIC	_zip->z_pic

#ifdef	INCLUDE_ZIPCPU
#ifdef INCLUDE_DMA_CONTROLLER
#define	_HAVE_ZIPSYS_DMA
#endif	// INCLUDE_DMA_CONTROLLER
#ifdef INCLUDE_ACCOUNTING_COUNTERS
#define	_HAVE_ZIPSYS_PERFORMANCE_COUNTERS
#endif	// INCLUDE_ACCOUNTING_COUNTERS
#endif // INCLUDE_ZIPCPU


#define BUSPIC(X) (1<<X)


typedef	struct	RTCLIGHT_S	{
	unsigned	r_clock, r_stopwatch, r_timer, r_alarm;
} RTCLIGHT;




#define	CLKFREQHZ	50000000


typedef struct  CONSOLE_S {
	unsigned	u_setup;
	unsigned	u_fifo;
	unsigned	u_rx, u_tx;
} CONSOLE;

#define	_uart_txbusy	((_uart->u_fifo & 0x10000)==0)


#define	SYSPIC(A)	(1<<(A))


#define	ALTPIC(A)	(1<<(A))


#define	_BOARD_HAS_VERSION
#define	_BOARD_HAS_BUSERR
static volatile unsigned *const _buserr = ((unsigned *)49156);
#ifdef	BUSPIC_ACCESS
#define	_BOARD_HAS_BUSPIC
static volatile unsigned *const _buspic = ((unsigned *)0x0000c008);
#endif	// BUSPIC_ACCESS
#ifdef	RTC_ACCESS
#define	_BOARD_HAS_RTC
static volatile RTCLIGHT *const _rtc = ((RTCLIGHT *)0x00008000);
#endif	// RTC_ACCESS
#ifdef	BKRAM_ACCESS
#define	_BOARD_HAS_BKRAM
extern char	_bkram[0x00010000];
#endif	// BKRAM_ACCESS
#ifdef	SPIO_ACCESS
#define	_BOARD_HAS_SPIO
static volatile unsigned *const _spio = ((unsigned *)49168);
#endif	// SPIO_ACCESS
#define	_BOARD_HAS_BUILDTIME
#ifdef	BUSCONSOLE_ACCESS
#define	_BOARD_HAS_BUSCONSOLE
static volatile CONSOLE *const _uart = ((CONSOLE *)16384);
#endif	// BUSCONSOLE_ACCESS
#ifdef	PWRCOUNT_ACCESS
static volatile unsigned *const _pwrcount = ((unsigned *)0x0000c00c);
#endif	// PWRCOUNT_ACCESS
//
// Interrupt assignments (3 PICs)
//
// PIC: buspic
#define	BUSPIC_RTC	BUSPIC(0)
#define	BUSPIC_SPIO	BUSPIC(1)
// PIC: syspic
#define	SYSPIC_DMAC	SYSPIC(0)
#define	SYSPIC_JIFFIES	SYSPIC(1)
#define	SYSPIC_TMC	SYSPIC(2)
#define	SYSPIC_TMB	SYSPIC(3)
#define	SYSPIC_TMA	SYSPIC(4)
#define	SYSPIC_ALT	SYSPIC(5)
#define	SYSPIC_BUS	SYSPIC(6)
#define	SYSPIC_UARTTXF	SYSPIC(7)
#define	SYSPIC_UARTRXF	SYSPIC(8)
// PIC: altpic
#define	ALTPIC_UIC	ALTPIC(0)
#define	ALTPIC_UOC	ALTPIC(1)
#define	ALTPIC_UPC	ALTPIC(2)
#define	ALTPIC_UTC	ALTPIC(3)
#define	ALTPIC_MIC	ALTPIC(4)
#define	ALTPIC_MOC	ALTPIC(5)
#define	ALTPIC_MPC	ALTPIC(6)
#define	ALTPIC_MTC	ALTPIC(7)
#define	ALTPIC_UARTTX	ALTPIC(8)
#define	ALTPIC_UARTRX	ALTPIC(9)
#endif	// BOARD_H