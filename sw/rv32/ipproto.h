////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	ipproto.h
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
#ifndef	IP_H
#define	IP_H

#include "pkt.h"

extern	NET_PACKET *new_ippkt(unsigned len);
extern	void	tx_ippkt(NET_PACKET *pkt, unsigned subproto, unsigned src, unsigned dest);
extern	void	rx_ippkt(NET_PACKET *pkt);
extern	void	dump_ippkt(NET_PACKET *pkt);
extern unsigned	ippkt_src(NET_PACKET *pkt);
extern unsigned	ippkt_dst(NET_PACKET *pkt);
extern unsigned	ippkt_subproto(NET_PACKET *pkt);

#endif
