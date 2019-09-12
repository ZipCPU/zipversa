////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	ethproto.c
//
// Project:	ZipVersa, Versa Brd implementation using ZipCPU infrastructure
//
// Purpose:	To encapsulate common functions associated with the ethernet
//		protocol portion of the network stack.
//
// 	The network controller handles some of this for us--it handles the
//	CRC and source MAC address for us.  As a result, instead of sending
//	a 6+6+2 byte header, we only need to handle a 6+2 byte header.
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
#include "ethproto.h"
#include "ipproto.h"
#include "arp.h"
#include "etcnet.h"

ETHERNET_MAC	my_mac_addr = DEFAULTMAC;

unsigned eth_headersize() {
	return 8;	// Bytes
}

NET_PACKET	*new_ethpkt(unsigned ln) {
	NET_PACKET	*pkt;

	pkt = new_pkt(ln+10);
	printf("ETHPKT: ln = %2d, p_user = &p_raw[%3d]\n",
		pkt->p_length, pkt->p_user - pkt->p_raw);
		
	pkt->p_length -= 10;
	pkt->p_user += 8;
	return pkt;
}
	
void	tx_ethpkt(NET_PACKET *pkt, unsigned ethtype, ETHERNET_MAC mac) {
	// Destination MAC

	pkt->p_user   -= eth_headersize();
	pkt->p_length += eth_headersize();

	pkt->p_user[0] = (mac >> 40l) & 0x0ff;
	pkt->p_user[1] = (mac >> 32l) & 0x0ff;
	pkt->p_user[2] = (mac >> 24) & 0x0ff;
	pkt->p_user[3] = (mac >> 16) & 0x0ff;
	pkt->p_user[4] = (mac >>  8) & 0x0ff;
	pkt->p_user[5] = (mac      ) & 0x0ff;
	//
	pkt->p_user[6] = (ethtype >> 8) & 0x0ff;
	pkt->p_user[7] = (ethtype     ) & 0x0ff;

	tx_pkt(pkt);
}

extern	void	rx_ethpkt(NET_PACKET *pkt) {
	pkt->p_user   += 8;
	pkt->p_length -= 8;
}

void	dump_ethpkt(NET_PACKET *pkt) {
	pkt_reset(pkt);

	printf("ETH PROTO: %02x%02x\n", pkt->p_user[8] & 0x0ff,
			pkt->p_user[9] & 0x0ff);
	printf("ETH MAC  : %02x:%02x:%02x:%02x:%02x:%02x\n",
			pkt->p_user[0] & 0x0ff,
			pkt->p_user[1] & 0x0ff,
			pkt->p_user[2] & 0x0ff,
			pkt->p_user[3] & 0x0ff,
			pkt->p_user[4] & 0x0ff,
			pkt->p_user[5] & 0x0ff);

	pkt->p_user += 8; pkt->p_length -= 8;
	dump_ippkt(pkt);
	pkt->p_user -= 8; pkt->p_length += 8;
	printf("ETH CRC  : %02x%02x\n",
			pkt->p_user[pkt->p_length] & 0x0ff,
			pkt->p_user[pkt->p_length+1] & 0x0ff);
}

extern	void	ethpkt_mac(NET_PACKET *pkt, ETHERNET_MAC *mac) {
	ETHERNET_MAC	smac;

	smac = 0;
	smac = (pkt->p_user[0] & 0x0ff);
	smac = (pkt->p_user[1] & 0x0ff) | (smac << 8);
	smac = (pkt->p_user[2] & 0x0ff) | (smac << 8);
	smac = (pkt->p_user[3] & 0x0ff) | (smac << 8);
	smac = (pkt->p_user[4] & 0x0ff) | (smac << 8);
	smac = (pkt->p_user[5] & 0x0ff) | (smac << 8);
	*mac = smac;
}

unsigned ethpkt_ethtype(NET_PACKET *pkt) {
	unsigned	v;
	v = (pkt->p_user[6] & 0x0ff) << 6;
	v = v | (pkt->p_user[7] & 0x0ff);

	return v;
}
