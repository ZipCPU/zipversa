////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	pkt.c
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
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include "board.h"
#include "pkt.h"
#include "ethproto.h"

#ifndef	NULL
#define	NULL	(void *)0l
#endif

extern	void	tx_busy(NET_PACKET *);

NET_PACKET	*rx_pkt(void) {
#ifdef	NET1_ACCESS
	if (_net1->n_rxcmd & ENET_RXAVAIL) {
		NET_PACKET	*pkt = malloc(sizeof(pkt)
			+ (ENET_RXLEN(_net1->n_rxcmd))+2);

		pkt->p_usage_count = 1;
		pkt->p_rawlen = (ENET_RXLEN(_net1->n_rxcmd))+2;
		pkt->p_length = pkt->p_rawlen-2;
		pkt->p_raw  = &pkt->p_raw[0];
		pkt->p_user = &pkt->p_raw[0];
		memcpy(pkt->p_raw, (char *)_netbrx, pkt->p_rawlen);

		_net1->n_rxcmd = ENET_RXCLRERR;

		return pkt;
	}
#endif
	return NULL;
}

void	pkt_reset(NET_PACKET *pkt) {
	if (NULL == pkt)
		return;

	pkt->p_length= pkt->p_rawlen;
	pkt->p_user = pkt->p_raw;
}

void	tx_pkt(NET_PACKET *pkt) {
#ifdef	NET1_ACCESS
	if (_net1->n_txcmd & ENET_TXBUSY)
		tx_busy(pkt);
	else {
		memcpy((char *)_netbtx, pkt->p_user, pkt->p_length);
		_net1->n_txcmd = ENET_TXGO | pkt->p_length;
		dump_ethpkt(pkt);
		free_pkt(pkt);
	}
#else
	free_pkt(pkt);
#endif
}

NET_PACKET	*new_pkt(unsigned msglen) {
	NET_PACKET	*pkt;
	unsigned	pktlen;

	pkt = (NET_PACKET *)malloc(sizeof(NET_PACKET) + sizeof(msglen));
	pkt->p_usage_count = 1;
	pkt->p_raw = (char *)&pkt->p_raw;
	pkt->p_user= pkt->p_raw;
	pkt->p_rawlen = msglen;
	pkt->p_length = pkt->p_rawlen;

	return pkt;
}

void	free_pkt(NET_PACKET *pkt) {
	if (NULL == pkt)
		return;
	if (pkt->p_usage_count > 0)
		pkt->p_usage_count --;
	if (pkt->p_usage_count == 0)
		free(pkt);
}
