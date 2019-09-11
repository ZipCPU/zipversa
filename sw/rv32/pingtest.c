////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	pingtest.c
//
// Project:	ZipVersa, Versa Brd implementation using ZipCPU infrastructure
//
// Purpose:	Test whether or not we can ping a given (fixed) host IP.
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
#include "ipproto.h"
#include "arp.h"
#include "icmp.h"
#include "protoconst.h"
#include "etcnet.h"
#include "ethproto.h"


// Acknowledge all interrupts, and shut all interrupt sources off
#define	CLEARPIC	0x7fff7fff
// Turn off the master interrupt generation
#define	DISABLEINTS	0x80000000

#define	REPEATING_TIMER	0x80000000

unsigned	heartbeats = 0, lasthello;
NET_PACKET	*waiting_pkt = NULL;

int	main(int argc, char **argv) {
	NET_PACKET	*rcvd;
	unsigned	now = 0, lastping = 0;
	unsigned	host_ip = DEFAULT_ROUTERIP;
	unsigned	pic;

	heartbeats = 0;
	lasthello  = 0;

	*_buspic = CLEARPIC;
	*_buspic = DISABLEINTS;

	*_systimer = REPEATING_TIMER | (CLKFREQUENCYHZ / 10); // 10Hz interrupt

	waiting_pkt = NULL;

	printf("Starting up\n");

	// We can still use the interrupt controller, we'll just need to poll it
	while(1) {
		heartbeats++;
		// Check for any interrupts
		pic = *_buspic;

		if (pic & BUSPIC_TIMER) {
			// We've received a timer interrupt
			now++;

			if ((now - lastping > 2)&&(waiting_pkt == NULL)) {
				icmp_send_ping(host_ip);

				lastping = now;
			}

			if ((now - lasthello) > 1200)
				printf("Hello, World!\n");

			*_buspic = BUSPIC_TIMER;
		}

		if (pic & BUSPIC_NETRX) {
			unsigned	ipsrc, ipdst;
			// We've received a packet
			rcvd = rx_pkt();
			*_buspic = BUSPIC_NETRX;

			switch(ethpkt_ethtype(rcvd)) {
			case ETHERTYPE_ARP:
				rx_arp(rcvd);
				break;
			case ETHERTYPE_IP:
				rx_ethpkt(rcvd);
				ipsrc = ippkt_src(rcvd);
				ipdst = ippkt_dst(rcvd);
				rx_ippkt(rcvd);
				switch(ippkt_subproto(rcvd)) {
					case IPPROTO_ICMP:
						if (rcvd->p_user[0] == ICMP_PING)							icmp_reply(ipsrc, rcvd);
						else
							printf("RX PING\n");
						break;
					default:
						rcvd->p_user = rcvd->p_raw;
						rcvd->p_length = rcvd->p_rawlen;
						pkt_reset(rcvd);
						dump_ethpkt(rcvd);
						break;
				}
				break;
			default:
				pkt_reset(rcvd);
				dump_ethpkt(rcvd);
				break;
			} free_pkt(rcvd);
		}

		if (pic & BUSPIC_NETTX) {
			// We've finished transmitting our last packet.
			// See if another's waiting, and then transmit that.a
			if (waiting_pkt != NULL) {
				NET_PACKET	*pkt = waiting_pkt;
				waiting_pkt = NULL;
				tx_pkt(pkt);
				*_buspic = BUSPIC_NETTX;
			}
		}
	}
}

void	tx_busy(NET_PACKET *txpkt) {
	if (waiting_pkt == NULL) {
		waiting_pkt = txpkt;
	}
}
