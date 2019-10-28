////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	sw/host/testfft.cpp
//
// Project:	ZipVersa, Versa Brd implementation using ZipCPU infrastructure
//
// Purpose:	
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
#include <stdint.h>
#include <math.h>
#include <assert.h>

#include "udpsocket.h"

const unsigned	FFT_SIZE = 1024;
const unsigned	MAXLN = 128;
const unsigned	TIMEOUT = 50;

unsigned	ffts_completed = 0;

uint16_t net_rd16t(char *pkt, int loc) {
	unsigned	v = 0;

	v = (pkt[loc  ] & 0x0ff);
	v = (pkt[loc+1] & 0x0ff) | (v << 8);

	return	v;
}

void	net_wr16t(char *pkt, int loc, uint16_t v) {

	pkt[loc  ] = (v >> 8);
	pkt[loc+1] = v;
}

uint32_t net_rd32t(char *pkt, int loc) {
	unsigned	v = 0;

	v = ((pkt[loc  ]) & 0x0ff);
	v = ((pkt[loc+1]) & 0x0ff) | (v << 8);
	v = ((pkt[loc+2]) & 0x0ff) | (v << 8);
	v = ((pkt[loc+3]) & 0x0ff) | (v << 8);

	return 	v;
}

void	net_wr32t(char *pkt, int loc, uint32_t v) {

	pkt[loc  ] = (v >> 24);
	pkt[loc+1] = (v >> 16);
	pkt[loc+2] = (v >>  8);
	pkt[loc+3] = v;
}

int	runfft_test(UDPSOCKET *skt, int *data) {
	char	*bufp;
	int		nr;
	unsigned	fpga_posn = 0, bufln;
	static	unsigned fft_id = 7;

	bufln = MAXLN*4 + 4;
	bufp = (char *)malloc(bufln);
	fft_id = (fft_id+1)&0x0ffff;

	//
	// Send the data to the FPGA
	//
	while(fpga_posn < FFT_SIZE) {
		net_wr16t(bufp, 0, fft_id);
		net_wr16t(bufp, 2, fpga_posn);

		for(unsigned k=0; k<MAXLN; k++)
			net_wr32t(bufp, 4+(k*4), data[k+fpga_posn]);
		skt->write(bufp, bufln);

		nr = skt->read(bufp, bufln, TIMEOUT);

		if (nr >= 4) {
			unsigned	pkt_id, pkt_posn;
			pkt_id   = net_rd16t(bufp, 0);
			pkt_posn = net_rd16t(bufp, 2);

			if (pkt_id != fft_id)
				fpga_posn = 0;
			else if (pkt_posn > fpga_posn) {
				fpga_posn = pkt_posn;
				if ((nr > 4) && (pkt_posn == FFT_SIZE))
					break;
			}
		} else if (nr < 0) {
			for(unsigned k=0; k < FFT_SIZE; k++)
				data[k] = -1;
			return -1;
		}
	}

	assert(fpga_posn == FFT_SIZE);

	//
	// Receive the return data into our buffer
	//
	while(fpga_posn < 2*FFT_SIZE) {
		net_wr16t(bufp, 0, fft_id);
		net_wr16t(bufp, 2, fpga_posn);

		skt->write(bufp, 4);

		if (nr < 4)
			nr = skt->read(bufp, bufln, TIMEOUT);
		if (nr >= 4) {
			unsigned	pkt_id, pkt_posn;

			pkt_id   = net_rd16t(bufp, 0);
			pkt_posn = net_rd16t(bufp, 2);

			if (pkt_id != fft_id)
				assert(0);
			else if ((nr > 4)&&(pkt_posn == fpga_posn)) {
				int *dat = &data[fpga_posn-FFT_SIZE];

				for(int k=0; k<(nr-4)/4; k++)
					*dat++ = net_rd32t(bufp,k*4+4);

				fpga_posn += (nr-4)/4;

				net_wr16t(bufp, 0, fft_id);
				net_wr16t(bufp, 2, fpga_posn);

				skt->write(bufp, 4);
			} else if ((nr == 4)&&(pkt_posn == 2*FFT_SIZE)) {
				break;
			}

		}
		nr = 0;
	}

	free(bufp);

	ffts_completed++;

	return 0;
}

void	sinewave_test(UDPSOCKET *skt, int mag, int bin, FILE *dbgfp = NULL) {
	int	sigbuf[FFT_SIZE];

	if (bin == 0) {
		for(unsigned k=0; k<FFT_SIZE; k++)
			sigbuf[k] = mag;
	} else if (bin < 0) {
		for(unsigned k=0; k<FFT_SIZE; k++)
			sigbuf[k] = mag * sin((2.0 * M_PI* k) / FFT_SIZE);
	} else {
		for(unsigned k=0; k<FFT_SIZE; k++)
			sigbuf[k] = mag * cos((2.0 * M_PI* k) / FFT_SIZE);
	}

	runfft_test(skt, sigbuf);
	if (dbgfp)
		fwrite(sigbuf, sizeof(int), FFT_SIZE, dbgfp);
}

void	impulse_test(UDPSOCKET *skt, int mag, int dly, FILE *dbgfp = NULL) {
	int	sigbuf[FFT_SIZE];

	for(unsigned k=0; k<FFT_SIZE; k++)
		sigbuf[k] = 0;
	sigbuf[dly] = mag;

	runfft_test(skt, sigbuf);
	if (dbgfp)
		fwrite(sigbuf, sizeof(int), FFT_SIZE, dbgfp);
}

int main(int argc, char **argv) {
	UDPSOCKET *skt = new UDPSOCKET("192.168.15.22");
	const char	*fname = "fftresult.bin";
	FILE	*fp = fopen(fname,"w");

	if (fp == NULL) {
		fprintf(stderr, "Could not open default output file, %s\n", fname);
		perror("O/S Err:");
		exit(EXIT_FAILURE);
	}
	skt->bind();

	impulse_test(skt, 0x7f00, 0, fp);
	impulse_test(skt, 0x7f00, 1, fp);
	impulse_test(skt, 0x7f00, 2, fp);
	impulse_test(skt, 0x7f00, 3, fp);

	printf("%d FFTs completed\n", ffts_completed);

	delete	skt;
	fclose(fp);
}

