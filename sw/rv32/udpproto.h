////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	udpproto.h
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
#ifndef	UDP_H
#define	UDP_H

#include "pkt.h"

extern	NET_PACKET *new_udppkt(unsigned len);
extern	void	tx_udp(NET_PACKET *pkt, unsigned dest, unsigned sport, unsigned dport);
extern	void	rx_udp(NET_PACKET *pkt);
extern	void	dump_udppkt(NET_PACKET *pkt);
extern unsigned	udp_sport(NET_PACKET *pkt);
extern unsigned	udp_dport(NET_PACKET *pkt);

#endif
