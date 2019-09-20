////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	fftsimtest.c
//
// Project:	ZipVersa, Versa Brd implementation using ZipCPU infrastructure
//
// Purpose:	Check the FFTs function apart from using the network, to make
//		sure we can get the results we expect.  This primarily tests
//	the WB to FFT wrapper, wbfft.v.  It also does it from within simulation
//	so we can have the confidence that it work or if not the ability to
//	dig into the core and see what is going right or wrong.
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
#include <stdio.h>
#include <stdlib.h>
#include "board.h"
#include "pkt.h"

#define	FFT_SIZE	FFT_LENGTH

void	reset_fft(void) {
	*_wbfft_ctrl = 0;
}

void	tx_busy(NET_PACKET *txpkt) {
	free_pkt(txpkt);
}

int	main(int argc, char **argv) {

	for(int dly=0; dly<5; dly++) {
		printf("FFT Test #1: impulse at %d\n", dly);

		reset_fft();
		*_buspic = BUSPIC_FFT;

		for(unsigned k=0; k<dly; k++)
			_wbfft_data[k] = 0;

		_wbfft_data[dly] = 0x7f00;

		for(unsigned k=dly+1; k<FFT_SIZE-1; k++)
			_wbfft_data[k] = 0;

		if ((*_buspic & BUSPIC_FFT)!=0) {
			printf("BUS PIC FFT responded too early ??\n");
			exit(-1);
		}

		_wbfft_data[FFT_SIZE-1] = 0;

		while((*_buspic & BUSPIC_FFT)==0)
			;

		printf( "  Result(s)\n"
			"  ------------\n");
		for(unsigned k=0; k<FFT_SIZE; k++)
			printf("   [%4d]: 0x%08x\n", k, _wbfft_data[k]);
	}
}
