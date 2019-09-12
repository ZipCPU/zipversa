////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	icmp.c
//
// Project:	ZipVersa, Versa Brd implementation using ZipCPU infrastructure
//
// Purpose:	To exercise the network port by ...
//
//	1. Pinging another system, at 1PPS
//	2. Replying to ARP requests
//	3. Replying to external 'pings' requests
//
//	To configure this for your network, you will need to adjust the
//	following constants within this file:
//
//	my_ip_addr
//		This is the (fixed) IP address of your Arty board.  The first
//		octet of the IP address is kept in the high order word.
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
#include <string.h>
#include "board.h"
#include "pkt.h"
#include "etcnet.h"
#include "protoconst.h"
#include "ipcksum.h"
#include "arp.h"
#include "ipproto.h"
#include "icmp.h"

// #define	CLKFREQHZ	50000000


// My network ID.  The 192.168.15 part comes from the fact that this is a
// local network.  The .22 (last octet) is due to the fact that this is
// an unused ID on my network.

unsigned	icmppkt_id = 0;

void	icmp_reply(unsigned ipaddr, NET_PACKET *icmp_request) {
	ETHERNET_MAC	hwaddr;
	int		maxsz = 2048;

	maxsz = 1<<((_net1->n_rxcmd>>24)&0x0f);
	if (maxsz > 2048)
		maxsz = 2048;

	int pktln = icmp_request->p_length;
	if (pktln < 8)
		pktln = 8;

	if (icmp_request->p_user[0] != ICMP_PING) {
		printf("ICMP: Message that\'s not a ping--not replying\n");
		return;
	} else if (pktln >= 1024) {
		printf("ICMP: Refusing to reply to a packet that\'s too large\n");
		return;
	}

	NET_PACKET	*pkt;
	unsigned	cksum;

	pkt = new_icmp(pktln);
	memcpy(pkt->p_user, icmp_request->p_user, pktln);
	pkt->p_user[0] = ICMP_ECHOREPLY;
	pkt->p_user[1] = 0;
	pkt->p_user[2] = 0;
	pkt->p_user[3] = 0;
		
	// Now, let's go fill in the IP and ICMP checksums
	cksum = ipcksum(pkt->p_length, pkt->p_user);
	pkt->p_user[2] = (cksum >> 8) & 0x0ff;
	pkt->p_user[3] = (cksum     ) & 0x0ff;

	tx_ippkt(pkt, IPPROTO_ICMP, my_ip_addr, ipaddr);
}

NET_PACKET *new_icmp(unsigned ln) {
	NET_PACKET	*pkt = new_ippkt(ln);
	printf("ICMP:   ln =%3d, p_user = &p_raw[%3d]\n",
		ln, pkt->p_user - pkt->p_raw);
	return	pkt;
}

void	icmp_send_ping(unsigned ping_ip_addr) {
	NET_PACKET *pkt;
	unsigned	cksum;

	// Form a packet to transmit
	pkt = new_icmp(8);

	//
	// Ping payload: type = 0x08 (PING, the response will be zero)
	//	CODE = 0
	//	Checksum will be filled in later
	pkt->p_user[0] = ICMP_PING;	
	pkt->p_user[1] = 0x00;
	pkt->p_user[2] = 0x00;
	pkt->p_user[3] = 0x00;
	//
	icmppkt_id += BIG_PRIME + (BIG_PRIME << 2);
	pkt->p_user[4] = (icmppkt_id >> 24)&0x0ff;
	pkt->p_user[5] = (icmppkt_id >> 16)&0x0ff;
	pkt->p_user[6] = (icmppkt_id >>  8)&0x0ff;
	pkt->p_user[7] = (icmppkt_id >>  0)&0x0ff;

	// Calculate the PING payload checksum
	// pkt->p_user[2] = 0;
	// pkt->p_user[3] = 0;
	cksum = ipcksum(8, pkt->p_user);
	pkt->p_user[2] = (cksum >> 8) & 0x0ff;
	pkt->p_user[3] = (cksum     ) & 0x0ff;

	// Finally, send the packet -- 9*4 = our total number of octets
	pkt->p_length = 8;
	tx_ippkt(pkt, IPPROTO_ICMP, my_ip_addr, ping_ip_addr);
}

void	dump_icmp(NET_PACKET *pkt) {
	unsigned 	cksum, pktsum;

	printf("ICMP TYPE : 0x%02x", pkt->p_user[0] & 0x0ff);
	printf("ICMP CODE : 0x%02x", pkt->p_user[1] & 0x0ff);
	if (pkt->p_user[0] == ICMP_PING)
		printf(" Ping request\n");
	else if (pkt->p_user[0] == ICMP_ECHOREPLY)
		printf(" Ping reply\n");
	else
		printf(" (Unknown ICMP)\n");

	pktsum = ((pkt->p_user[2] & 0x0ff) << 8)
			| (pkt->p_user[3] & 0x0ff);
	cksum = ipcksum(pkt->p_length, pkt->p_user);
	printf("ICMP CKSUM: 0x%02x", pktsum);
	if (cksum != pktsum)
		printf(" -- NO-MATCH against %04x\n", cksum);
	else
		printf("\n");

	printf("ICMP DATA :\n");
	for(unsigned k=4; k<pkt->p_length; k++) {
		printf("%02x ", pkt->p_user[k]);
		if ((k & 0x03)==3)
			printf("\n");
	} if (((pkt->p_length -1)&0x03)!=3)
		printf("\n");
}

