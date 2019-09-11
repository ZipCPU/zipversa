////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	udpproto.c
//
// Project:	ZipVersa, Versa Brd implementation using ZipCPU infrastructure
//
// Purpose:	To encapsulate common functions associated with the UDP protocol
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
#include <string.h>
#include "pkt.h"
#include "ipproto.h"
#include "ipcksum.h"

unsigned	udp_headersize(void) {
	return 8;
}

NET_PACKET *new_udppkt(unsigned len) {
	NET_PACKET	*pkt;

	pkt = new_ippkt(len + udp_headersize());
	pkt->p_user   += udp_headersize();
	pkt->p_length -= udp_headersize();
}

extern	void	tx_udp(NET_PACKET *pkt, unsigned src, unsigned dest, unsigned sport, unsigned dport);

void	rx_udp(NET_PACKET *pkt) {
	unsigned ln = ((pkt->p_user[4] & 0x0ff) << 8)
		| (pkt->p_user[5] & 0x0ff);

	pkt->p_user   += udp_headersize();
	if (ln <= 8)
		pkt->p_length = 0;
	else if (pkt->p_length > ln)
		pkt->p_length = ln - udp_headersize();
	else
		pkt->p_length -= udp_headersize();
}

unsigned	udp_sport(NET_PACKET *pkt) {
	unsigned sport = ((pkt->p_user[0] & 0x0ff) << 8)
		| (pkt->p_user[1] & 0x0ff);

	return sport;
}

unsigned	udp_dport(NET_PACKET *pkt) {
	unsigned dport = ((pkt->p_user[2] & 0x0ff) << 8)
		| (pkt->p_user[3] & 0x0ff);

	return dport;
}

void	dump_udppkt(NET_PACKET *pkt) {
	unsigned	cksum, sport, dport, len, pktsum;

	sport = udp_sport(pkt);
	dport = udp_dport(pkt);
	len = ((pkt->p_user[4] & 0x0ff) << 8)
		| (pkt->p_user[5] & 0x0ff);

	pktsum = ((pkt->p_user[6] & 0x0ff) << 8)
		| (pkt->p_user[7] & 0x0ff);

	pkt->p_user[6] = 0; pkt->p_user[7] = 0;
	cksum = ipcksum(len, pkt->p_user);

	// Put the checksum values back
	pkt->p_user[6] = (cksum >> 8) & 0x0ff;
	pkt->p_user[7] = (cksum     ) & 0x0ff;

	printf("UDP SPORT : %d\n", sport);
	printf("UDP DPORT : %d\n", dport);
	printf("UDP LENGTH: %d bytes", len);
	if (len != pkt->p_length)
		printf(" -- DOESN\'T MATCH %d\n", pkt->p_length);
	printf("UDP CKSUM : %04x", pktsum);
	if (pktsum != cksum)
		printf(" -- DOESN\'T MATCH %04x\n", cksum);
	printf("UDP DATA  :\n");
	for(unsigned k=8; k<len; k++) {
		if ((k & 0x0f) == 8)
			printf("%*s: ", 14, "");
		printf("%08x ", pkt->p_user[k]);
		if ((k & 0x0f) == 0)
			printf(" ");
		else if ((k & 0x0f) == 7)
			printf("\n");
	} if ((len & 0x0f) != 8)
		printf("\n");
}
