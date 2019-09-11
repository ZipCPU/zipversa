////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	ipproto.c
//
// Project:	ZipVersa, Versa Brd implementation using ZipCPU infrastructure
//
// Purpose:	To encapsulate common functions associated with the IP protocol
//		portion of the network stack.
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
#include <stdint.h>
#include "pkt.h"
#include "protoconst.h"
#include "ethproto.h"
#include "ipproto.h"
#include "icmp.h"
#include "ipcksum.h"
#include "arp.h"
#include "etcnet.h"

uint32_t	my_ip_addr = DEFAULTIP,
		my_ip_mask = LCLNETMASK;
unsigned	ip_pktid = (unsigned)(BIG_PRIME * 241ll);

unsigned	ip_headersize(void) {
	return 5*4;
}

NET_PACKET *new_ippkt(unsigned ln) {
	NET_PACKET	*pkt;

	pkt = new_ethpkt(ln+20);
	pkt->p_length -= 20;
	pkt->p_user += 20;
}

void	ip_set(NET_PACKET *pkt, unsigned subproto, unsigned src,
		unsigned dest) {
	unsigned	cksum;

	pkt->p_user[0] = 0x45;
	pkt->p_user[1] = 0x00;
	pkt->p_user[2] = 0x00;
	pkt->p_user[3] = 0x1c;
	//
	ip_pktid += BIG_PRIME; // A BIG prime number
	pkt->p_user[4] = (ip_pktid >> 8) & 0x0ff;
	pkt->p_user[5] = (ip_pktid & 0x0ff);
	pkt->p_user[6] = 0x00;	// Flags and
	pkt->p_user[7] = 0x00;	// Fragmentation offset
	//
	// Time-to-live, sub-protocol
	pkt->p_user[8] = 0x80;
	pkt->p_user[9] = subproto;
	pkt->p_user[10] = 0x00;	// Header checksum, come back for these
	pkt->p_user[11] = 0x00;
	//
	// My IP address
	pkt->p_user[12] = (src >> 24)&0x0ff;
	pkt->p_user[13] = (src >> 16)&0x0ff;
	pkt->p_user[14] = (src >>  8)&0x0ff;
	pkt->p_user[15] = (src      )&0x0ff;
	//
	// Destination IP address
	pkt->p_user[16] = (dest >> 24)&0x0ff;
	pkt->p_user[17] = (dest >> 16)&0x0ff;
	pkt->p_user[18] = (dest >>  8)&0x0ff;
	pkt->p_user[19] = (dest      )&0x0ff;
	//

	// Calculate the checksum
	cksum = ipcksum(ip_headersize(), pkt->p_user);
	pkt->p_user[10] = ((cksum>>8) & 0x0ff);
	pkt->p_user[11] = ( cksum     & 0x0ff);
}

void	tx_ippkt(NET_PACKET *pkt, unsigned subproto, unsigned src,
		unsigned dest) {
	if (pkt->p_user - pkt->p_raw <= 20+12) {
		printf("ERR: IPPKT doesn't have enough room for its headers\n");
		free_pkt(pkt);
		return;
	}

	pkt->p_user   -= ip_headersize();
	pkt->p_length += ip_headersize();
	ip_set(pkt, subproto, src, dest);

	ETHERNET_MAC	mac;
	if (arp_lookup(dest, &mac) == 0)
		return tx_ethpkt(pkt, ETHERTYPE_IP, mac);
	// return 1;
}

void	rx_ippkt(NET_PACKET *pkt) {
	unsigned	sz = (pkt->p_user[0] & 0x0f)*4;
	pkt->p_user   += sz;
	pkt->p_length -= sz;
}

unsigned	ippkt_src(NET_PACKET *pkt) {
	unsigned	ipsrc;

	ipsrc = (pkt->p_user[12] & 0x0ff);
	ipsrc = (pkt->p_user[13] & 0x0ff) | (ipsrc << 8);
	ipsrc = (pkt->p_user[14] & 0x0ff) | (ipsrc << 8);
	ipsrc = (pkt->p_user[15] & 0x0ff) | (ipsrc << 8);
	return ipsrc;
}

unsigned	ippkt_dst(NET_PACKET *pkt) {
	unsigned	ipdst;

	ipdst = (pkt->p_user[16] & 0x0ff);
	ipdst = (pkt->p_user[17] & 0x0ff) | (ipdst << 8);
	ipdst = (pkt->p_user[18] & 0x0ff) | (ipdst << 8);
	ipdst = (pkt->p_user[19] & 0x0ff) | (ipdst << 8);
	return ipdst;
}


unsigned	ippkt_subproto(NET_PACKET *pkt) {
	unsigned	subproto;

	subproto = (pkt->p_user[9] & 0x0ff);
	return subproto;
}

void	dump_ippkt(NET_PACKET *pkt) {
	unsigned	ihl = (pkt->p_user[0] & 0x0f)*5, proto, cksum, calcsum;

	printf("IP VERSION: %d\n", (pkt->p_user[0] >> 4) & 0x0f);
	printf("IP HDRLEN : %d bytes\n", ihl);
	unsigned pktln = ((pkt->p_user[2]&0x0ff)<< 8)
		| (pkt->p_user[3] & 0x0ff);
	printf("IP PKTLEN : %d", pktln);
	if (pktln > pkt->p_length) {
		printf(" --- LONGER THAN BUFFER!\n");
		return;
	} else if (pktln <= pkt->p_length)
		printf(" --- Smaller than buffer\n");

	printf("IP PKTLEN : %d", pktln);
	printf("IP PKTTTL : %d", pkt->p_user[8] & 0x0ff);
	proto = pkt->p_user[9] & 0x0ff;
	printf("IP PROTO  : %d", pkt->p_user[9] & 0x0ff);
	if (proto == IPPROTO_UDP)
		printf(" (UDP)\n");
	else if (proto == IPPROTO_TCP)
		printf(" (TCP)\n");
	else if (proto == IPPROTO_ICMP)
		printf(" (ICMP)\n");
	else
		printf("\n");
	cksum = ((pkt->p_user[10] & 0x0ff) << 8)
			| (pkt->p_user[11] & 0x0ff);
	calcsum = ipcksum(ihl*4, pkt->p_user);
	printf("IP CKSUM  : 0x%02x", cksum);
	if (cksum != calcsum)
		printf(" -- NO-MATCH against %04x\n", calcsum);
	else
		printf("\n");
	printf("IP SOURCE : %3d.%3d.%3d.%3d\n",
		pkt->p_user[12], pkt->p_user[13],
		pkt->p_user[14], pkt->p_user[15]);
	printf("IP DESTN  : %3d.%3d.%3d.%3d\n",
		pkt->p_user[16], pkt->p_user[17],
		pkt->p_user[18], pkt->p_user[19]);
	if ((pkt->p_user[0] & 0x0f) > 5) {
		printf("IP OPTIONS  : (Dump not yet supported)\n");
	}

	pkt->p_user   += ihl;
	pkt->p_length -= ihl;
	if (proto == IPPROTO_UDP) {
		// dump_udpproto(pkt);
	} else if (proto == IPPROTO_ICMP) {
		dump_icmp(pkt);
	} else if (proto == IPPROTO_TCP) {
		// dump_tcpproto(pkt);
	} else {
		printf("IP PAYLOAD: (dump not (yet) supported)\n");
	}
	pkt->p_user   -= ihl;
	pkt->p_length += ihl;
}
