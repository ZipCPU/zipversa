////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	bootloader.c
//
// Project:	ZipVersa, Versa Brd implementation using ZipCPU infrastructure
//
// Purpose:	To start a program from flash, loading its various components
//		into on-chip block RAM, or off-chip DDR3 SDRAM, as indicated
//	by the symbols/pointers within the program itself.  As you will notice
//	by the names of the symbols, it is assumed that a kernel will be placed
//	into block RAM.
//
//	This particular implementation depends upon the following symbols
//	being defined:
//
//	_rom:
//		The address of the beginning of a physical ROM device--often
//		a SPI flash device.  This is not the necessariliy the first
//		usable address on that device, as that is often reserved for
//		the first two FPGA configurations.
//
//		If no ROM device is present, set _rom=0 and the bootloader
//		will quietly and silently return.
//
//	_kram:
//		The first address of a fast RAM device (if present).  I'm
//		calling this device "Kernel-RAM", because (if present) it is
//		a great place to put kernel code.
//
//		if _kram == 0, no memory will be mapped to kernel RAM.
//
//	_ram:
//		The main RAM device of the system.  This is often the address
//		of the beginning of physical SDRAM, if SDRAM is present.
//
//	_kram_start:
//		The address of that location within _rom where the sections
//		needing to be moved begin at.
//
//	_kram_end:
//		The last address within the _kram device that needs to be
//		filled in.
//
//	_ram_image_start:
//		This address is more confusing.  This is equal to one past the
//		last used block RAM address, or the last used flash address if
//		no block RAM is used.  It is used for determining whether or not
//		block RAM was used at all.
//
//	_ram_image_end:
//		This is one past the last address in SDRAM that needs to be
//		set with valid data.
//
//		This pointer is made even more confusing by the fact that,
//		if there is nothing allocated in SDRAM, this pointer will
//		still point to block RAM.  To make matters worse, the MAP
//		file won't match the pointer in memory.  (I spent three days
//		trying to chase this down, and came up empty.  Basically,
//		the BFD structures may set this to point to block RAM, whereas
//		the MAP--which uses different data and different methods of
//		computation--may leave this pointing to SDRAM.  Go figure.)
//
//	_bss_image_end:
//		This is the last address of memory that must be cleared upon
//		startup, for which the program is assuming that it is zero.
//		While it may not be necessary to clear the BSS memory, since
//		BSS memory is always zero on power up, this bootloader does so
//		anyway--since we might be starting from a reset instead of power
//		up.
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2019, Gisselquist Technology, LLC
//
// This program is free software (firmware): you can redistribute it and/or
// modify it under the terms of the GNU General Public License as published
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
#include <stdint.h>
#include "board.h"		// Our current board support file
#include "bootloader.h"
// #include "txfns.h"

//
// We need to insist that the bootloader be kept in Flash, else it would depend
// upon running a routine from memory that ... wasn't in memory yet.  For this
// purpose, we place the bootloader in a special .boot section.  We'll also tell
// the linker, via the linker script, that this .boot section needs to be placed
// into flash.
//
extern	void	_bootloader(void) __attribute__ ((section (".boot")));

#ifndef	NULL
#define	NULL	(void *)0l
#endif

//
// bootloader()
//
// Here's the actual boot loader itself.  It copies three areas from flash:
//	1. An area from flash to block RAM
//	2. A second area from flash to SDRAM
//	3. The third area isn't copied from flash, but rather it is just set to
//		zero.  This is sometimes called the BSS segment.
//
void	_bootloader(void) {
// txstr("-------------------\nEntering Bootloader\n-------------------\n");
	if (_rom == NULL) {
		int	*wrp = _ram_image_end;
		while(wrp < _ram_image_end)
			*wrp++ = 0;
		return;
	}
	int *ramend = _ram_image_end, *bsend = _bss_image_end,
	    *kramdev = (_kram) ? _kram : _ram;

	int	*rdp = _kram_start, *wrp = (_kram) ? _kram : _ram;

	//
	// Load any part of the image into block RAM, but *only* if there's a
	// block RAM section in the image.  Based upon our LD script, the
	// block RAM should be filled from _blkram to _kernel_image_end.
	// It starts at _kram_start --- our last valid address within
	// the flash address region.
	//
	if (_kram_end != _kram_start) {
		while(wrp < _kram_end)
			*wrp++ = *rdp++;
	}

	if (NULL != _ram)
		wrp  = _ram;

	//
	// Now, we move on to the SDRAM image.  We'll here load into SDRAM
	// memory up to the end of the SDRAM image, _sdram_image_end.
	// As with the last pointer, this one is also created for us by the
	// linker.
	// 
	// while(wrp < sdend)	// Could also be done this way ...

	for(int i=0; i< ramend - _ram; i++)
		*wrp++ = *rdp++;

	//
	// Finally, we load BSS.  This is the segment that only needs to be
	// cleared to zero.  It is available for global variables, but some
	// initialization is expected within it.  We start writing where
	// the valid SDRAM context, i.e. the non-zero contents, end.
	//
	for(int i=0; i<bsend - ramend; i++)
		*wrp++ = 0;
}
