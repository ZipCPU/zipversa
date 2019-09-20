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
#include "txfns.h"


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
"+----       Starting Ping test        ----+\n"
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

			if ((now - lastping >= 20)&&(waiting_pkt == NULL)) {
				icmp_send_ping(host_ip);

				lastping = now;
			}

			if ((now - lasthello) >= 3000) {
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
						if (rcvd->p_user[0] == ICMP_PING)							icmp_reply(ipsrc, rcvd);
						else
							printf("RX PING <<------ SUCCESS!!!\n");
						// Free the packet
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
