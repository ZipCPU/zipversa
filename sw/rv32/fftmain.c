////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	fftmain.c
//
// Project:	ZipVersa, Versa Brd implementation using ZipCPU infrastructure
//
// Purpose:	Execute a basic state machine
//
//	Upon either an incoming packet, or a complete outgoing packet, or
//	a completed FFT
//	...
//
//	1kpt FFT, requires 4kB memory
//	- Incoming data packet -> memory
//		It it doesn't match the expected packet, send a NAKA
//		If it does, ACK
//		If it's the next packet to the FFT
//			write to the FFT
//			Keep writing until all stored FFT data is written
//	- Incoming NAK
//		Repeat the requested  data
//	- FFT complete
//		Copy data to memory,
//			write first packet to the channel
//	- TX complete
//		Read FFT output to memory
//		
//	
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
#include <string.h>

#include "board.h"
#include "pkt.h"
#include "ipproto.h"
#include "arp.h"
#include "icmp.h"
#include "protoconst.h"
#include "etcnet.h"
#include "ethproto.h"
#include "txfns.h"
#include "udpproto.h"

#define	FFTPORT	6783
#define	FFT_SIZE	FFT_LENGTH


// Acknowledge all interrupts, and shut all interrupt sources off
#define	CLEARPIC	0x7fff7fff
// Turn off the master interrupt generation
#define	DISABLEINTS	0x80000000

#define	REPEATING_TIMER	0x80000000

unsigned	heartbeats = 0, lasthello;
NET_PACKET	*waiting_pkt = NULL;

void	fftpacket(NET_PACKET *pkt);
void	ffttimeout(void);

int	main(int argc, char **argv) {
	NET_PACKET	*rcvd;
	unsigned	now = 0, lastping = 0, lastfft = 0;
	unsigned	host_ip = DEFAULT_ROUTERIP;
	unsigned	pic;

	heartbeats = 0;
	lasthello  = 0;

	*_buspic = CLEARPIC;
	*_buspic = DISABLEINTS;

	// Clear the network reset
	_net1->n_txcmd = 0;
	{ // Set the MAC address
		char *macp = (char *)&_net1->n_mac;

		ETHERNET_MAC upper = DEFAULTMAC >> 32;
		unsigned	upper32 = (unsigned) upper;

		macp[1] = (upper32 >>  8) & 0x0ff;
		macp[0] = (upper32      ) & 0x0ff;
		macp[7] = (DEFAULTMAC >> 24) & 0x0ff;
		macp[6] = (DEFAULTMAC >> 16) & 0x0ff;
		macp[5] = (DEFAULTMAC >>  8) & 0x0ff;
		macp[4] = (DEFAULTMAC      ) & 0x0ff;
	}

	*_systimer = REPEATING_TIMER | (CLKFREQUENCYHZ / 10); // 10Hz interrupt

	waiting_pkt = NULL;

	printf("\n\n\n"
"+-----------------------------------------+\n"
"+----        Starting FFT test        ----+\n"
// "+----123456789               987654321----+\n"
"+-----------------------------------------+\n"
"\n\n\n");

	icmp_send_ping(host_ip);

	// We can still use the interrupt controller, we'll just need to poll it
	while(1) {
		heartbeats++;
		// Check for any interrupts
		pic = *_buspic;

		if (pic & BUSPIC_TIMER) {
			// We've received a timer interrupt
			now++;

			if ((now - lastping >= 200)&&(waiting_pkt == NULL)) {
				icmp_send_ping(host_ip);

				lastping = now;
			}
			if ((now - lastfft >= 5)&&(waiting_pkt == NULL)) {
				ffttimeout();

				lastfft = now;
			}

			if ((now - lasthello) >= 3000) {
				// Every five minutes, pause to say hello
				printf("\n\nHello, World! Ticks since startup = 0x%08x\n\n", *_pwrcount);
				lasthello = now;
			}

			*_buspic = BUSPIC_TIMER;
		}

		if (pic & BUSPIC_NETRX) {
			unsigned	ipsrc, ipdst;

			// We've received a packet
			rcvd = rx_pkt();
			*_buspic = BUSPIC_NETRX;
			if (NULL != rcvd) {

			// Don't let the subsystem free this packet (yet)
			rcvd->p_usage_count++;

			switch(ethpkt_ethtype(rcvd)) {
			case ETHERTYPE_ARP:
				printf("RXPKT - ARP\n");
				rx_ethpkt(rcvd);
				rx_arp(rcvd); // Frees the packet
				break;
			case ETHERTYPE_IP: {
				unsigned	subproto;

				printf("RXPKT - IP\n");
				rx_ethpkt(rcvd);

				ipsrc = ippkt_src(rcvd);
				ipdst = ippkt_dst(rcvd);
				subproto = ippkt_subproto(rcvd);
				rx_ippkt(rcvd);

				if (ipdst == my_ip_addr) {
				switch(subproto) {
					case IPPROTO_ICMP:
						if (rcvd->p_user[0]==ICMP_PING)
							icmp_reply(ipsrc, rcvd);
						// else
						//	ignore other ICMP pkts
						//
						// Free the packet
						free_pkt(rcvd);
						break;
					case IPPROTO_UDP:
						if (FFTPORT == udp_dport(rcvd)){
							rx_udp(rcvd);
							fftpacket(rcvd);
							// frees the packet
						} else
							free_pkt(rcvd);
						break;
					default:
						printf("UNKNOWN-IP -----\n");
						pkt_reset(rcvd);
						dump_ethpkt(rcvd);
						printf("\n");
						// Free the packet
						free_pkt(rcvd);
						break;
				}}}
				break;
			default:
				printf("Received unknown ether-type %d (0x%04x)\n",
					ethpkt_ethtype(rcvd),
					ethpkt_ethtype(rcvd));
				pkt_reset(rcvd);
				dump_ethpkt(rcvd);
				printf("\n");
				// Free the packet
				free_pkt(rcvd);
				break;
			}

			// Now we can free the packet ourselves
			free_pkt(rcvd);
		}} else if (_net1->n_rxcmd & ENET_RXCLRERR) {
			printf("Network has detected an error, %08x\n", _net1->n_rxcmd);
			_net1->n_rxcmd = ENET_RXCLRERR | ENET_RXCLR;
		}

		if (pic & BUSPIC_NETTX) {
			// We've finished transmitting our last packet.
			// See if another's waiting, and then transmit that.a
			if (waiting_pkt != NULL) {
				NET_PACKET	*pkt = waiting_pkt;
txstr("Re-transmitting the busy packet\n");
				waiting_pkt = NULL;
				tx_pkt(pkt);
				*_buspic = BUSPIC_NETTX;
			}
		}
	}
}

void	tx_busy(NET_PACKET *txpkt) {
	if (waiting_pkt == NULL) {
		// printf("TX-BUSY\n");
		waiting_pkt = txpkt;
	} else if (txpkt != waiting_pkt) {
txstr("Busy collision--deleting waiting packet\n");
		free_pkt(waiting_pkt);
		waiting_pkt = txpkt;
	}
}

typedef enum	FFT_STATE_E {
	FFT_INPUT, FFT_OUTPUT
} FFT_STATE;

int		fft_id    = -1;
unsigned	fft_srcip = 0;
int		fft_port  = 0;
int		fft_posn  = 0;
FFT_STATE	fft_state = FFT_INPUT;

void	reset_fft(void) {
	// A basic write to the control port will reset the FFT
	*_wbfft_ctrl = 0;
}

uint16_t	pkt_uint16(NET_PACKET *pkt, int pos) {
	unsigned	v;

	v = (pkt->p_user[pos  ] & 0x0ff);
	v = (pkt->p_user[pos+1] & 0x0ff) | (v << 8);

	return (uint16_t)v;
}

uint32_t	pkt_uint32(NET_PACKET *pkt, int pos) {
	unsigned	v = 0;

	v = (pkt->p_user[pos  ] & 0x0ff);
	v = (pkt->p_user[pos+1] & 0x0ff) | (v << 8);
	v = (pkt->p_user[pos+2] & 0x0ff) | (v << 8);
	v = (pkt->p_user[pos+3] & 0x0ff) | (v << 8);

	return v;
}

void	hton32(char *ptr, uint32_t val) {
	ptr[3] = val; val >>= 8;
	ptr[2] = val; val >>= 8;
	ptr[1] = val; val >>= 8;
	ptr[0] = val;
}

void	fftpacket(NET_PACKET *pkt) {
	NET_PACKET	*txpkt;
	unsigned	srcip, dstip, sport, ln;

	{
		char	*puser;
		int	length;

		puser = pkt->p_user;
		length= pkt->p_length;

		pkt_reset(pkt);
		rx_ethpkt(pkt);
		srcip = ippkt_src(pkt);
		dstip = ippkt_dst(pkt);
		rx_ippkt(pkt);

		sport = udp_sport(pkt);

		pkt->p_user   = puser;
		pkt->p_length = length;
	}
	unsigned	pkt_id, pkt_posn;

	pkt_id   = pkt_uint16(pkt, 0);
	pkt_posn = pkt_uint16(pkt, 2);

	printf("FFT PACKET %s: src=%3d.%3d.%3d.%3d:%d FFT ID #%d, posn:%4d\n",
			(fft_state == FFT_INPUT) ? "(IN )"
			: ((fft_state == FFT_OUTPUT) ? "(OUT)"
			: "(?\?\?)"),
			(srcip >> 24)&0x0ff,
			(srcip >> 16)&0x0ff,
			(srcip >>  8)&0x0ff,
			(srcip      )&0x0ff,
			sport, pkt_id, pkt_posn);
	switch(fft_state) {
	case FFT_INPUT: {
		if ((pkt_id == fft_id) && (srcip == fft_srcip)
				&& (fft_port == sport)
				&& (pkt_posn == fft_posn)) {

			for(unsigned k=4; k < pkt->p_length; k+=4) {
				_wbfft_data[fft_posn] = pkt_uint32(pkt, k);
				fft_posn++;
			}

			// ACK where we are at now in our current state
			txpkt = new_udppkt(4);

			txpkt->p_user[0] = (fft_id >> 8)&0x0ff;
			txpkt->p_user[1] = (fft_id     )&0x0ff;
			txpkt->p_user[2] = (fft_posn >> 8)&0x0ff;
			txpkt->p_user[3] = (fft_posn     )&0x0ff;

printf("Rcvd FFT data, FFT posn = %d\n", fft_posn);
			tx_udp(txpkt, fft_srcip, FFTPORT, fft_port);

			if (fft_posn == FFT_SIZE)
				fft_state = FFT_OUTPUT;
		} else if ((pkt_id != fft_id)
				|| (fft_port != sport)) {
			reset_fft();

			fft_id = pkt_id;
			fft_srcip = srcip;
			fft_port  = sport;
			fft_posn  = 0;

			// ACK where we are at now with this new packet
			txpkt = new_udppkt(4);

			txpkt->p_user[0] = (pkt_id >> 8)&0x0ff;
			txpkt->p_user[1] = (pkt_id     )&0x0ff;
			txpkt->p_user[2] = 0;
			txpkt->p_user[3] = 0;

printf("FFT: Rcvd from unknown source, %3d.%3d.%3d.%3d:%d!=%d, #%d!=#%d\n",
(srcip>>24)&0x0ff, (srcip>>16)&0x0ff, (srcip>>8)&0x0ff, srcip&0x0ff,
sport, fft_port, pkt_id, fft_id);

		if ((pkt_id == fft_id) && (srcip == fft_srcip)
	);
			tx_udp(txpkt, fft_srcip, FFTPORT, fft_port);
		} else {
			// ACK where we are at now in our current state
			txpkt = new_udppkt(4);

			txpkt->p_user[0] = (fft_id >> 8)&0x0ff;
			txpkt->p_user[1] = (fft_id     )&0x0ff;
			txpkt->p_user[2] = (fft_posn >> 8)&0x0ff;
			txpkt->p_user[3] = (fft_posn     )&0x0ff;

			tx_udp(txpkt, fft_srcip, FFTPORT, fft_port);
		}} break;
	case FFT_OUTPUT: {
		// In this case, the user requests the result and we provide
		// it to him.
		unsigned	pkt_id, pkt_posn;

		pkt_id   = pkt_uint16(pkt, 0);
		pkt_posn = pkt_uint16(pkt, 2);
		if((pkt_id == fft_id)&&(srcip == fft_srcip)) {
			// ACK where we are at now in our current state
			if (pkt_posn >= 2*FFT_LENGTH) {
				reset_fft();
				fft_state = FFT_INPUT;
			} else {
				ln = FFT_LENGTH - pkt_posn;
				if (ln >= 128)
					ln = 128;
				txpkt = new_udppkt(4 + ln*4);

				txpkt->p_user[0] = (fft_id >> 8)&0x0ff;
				txpkt->p_user[1] = (fft_id     )&0x0ff;
				txpkt->p_user[2] = (fft_posn >> 8)&0x0ff;
				txpkt->p_user[3] = (fft_posn     )&0x0ff;

				for(unsigned k=0; k<ln; k++)
					hton32(&txpkt->p_user[4+k*4],
						_wbfft_data[k+fft_posn]);
				// memcpy(&txpkt->p_user[4], (void *)_wbfft_data,
				//	ln*sizeof(unsigned));

				tx_udp(txpkt, fft_srcip, FFTPORT, fft_port);
			}
			if (pkt_posn > fft_posn)
				fft_posn = pkt_posn;
		} else if (pkt_id != fft_id) {
			reset_fft();

			fft_id    = pkt_id;
			fft_state = FFT_INPUT;
			fft_srcip = srcip;
			fft_posn  = 0;

			// ACK where we are at now with this new packet
			txpkt = new_udppkt(4);

			txpkt->p_user[0] = (pkt_id >> 8)&0x0ff;
			txpkt->p_user[1] = (pkt_id     )&0x0ff;
			txpkt->p_user[2] = 0;
			txpkt->p_user[3] = 0;

			tx_udp(txpkt, fft_srcip, FFTPORT, fft_port);
		}} break;
	default:
		fft_id = -1;
		reset_fft();
		fft_state = FFT_INPUT;
		break;
	}

	free_pkt(pkt);
}

void	ffttimeout(void) {
	NET_PACKET	*txpkt;
	unsigned	ln;

	switch(fft_state) {
	case FFT_INPUT: if (fft_posn > 0) {

		// ACK where we are at now in our current state
		txpkt = new_udppkt(4);

		txpkt->p_user[0] = (fft_id >> 8)&0x0ff;
		txpkt->p_user[1] = (fft_id     )&0x0ff;
		txpkt->p_user[2] = (fft_posn >> 8)&0x0ff;
		txpkt->p_user[3] = (fft_posn     )&0x0ff;

printf("FFT: TX INPUT IDLE, posn = %d\n", fft_posn);
		tx_udp(txpkt, fft_srcip, FFTPORT, fft_port);
		} break;
	case FFT_OUTPUT: {
		// In this case, the user requests the result and we provide
		// it to him.
		if (fft_posn < 2* FFT_SIZE) {
			// ACK where we are at now in our current state
			ln = 2*FFT_LENGTH - fft_posn;
			if (ln >= 128)
				ln = 128;
			if (ln <= 0) {
				fft_state = FFT_INPUT;
			} else {
				txpkt = new_udppkt(4 + ln*4);

				txpkt->p_user[0] = (fft_id >> 8)&0x0ff;
				txpkt->p_user[1] = (fft_id     )&0x0ff;
				txpkt->p_user[2] = (fft_posn >> 8)&0x0ff;
				txpkt->p_user[3] = (fft_posn     )&0x0ff;

				for(unsigned k=0; k<ln; k++)
					hton32(&txpkt->p_user[4+k*4],
						_wbfft_data[k+fft_posn - FFT_SIZE]);
				// memcpy(&txpkt->p_user[4], (void *)_wbfft_data,
				//	ln*sizeof(unsigned));

				tx_udp(txpkt, fft_srcip, FFTPORT, fft_port);
			}
		}}
		break;
	default:
		fft_id = -1;
		reset_fft();
		fft_state = FFT_INPUT;
		break;
	}
}
