////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	icmp.h
//
// Project:	ZipVersa, Versa Brd implementation using ZipCPU infrastructure
//
// Purpose:	To send and reply to ICMP (ping) messages
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
#ifndef	ICMP_H
#define	ICMP_H

#include "pkt.h"

/*
extern	unsigned long ping_mac_addr;
extern	unsigned	ping_ip_addr;
extern	unsigned long	ping_mac_addr;
extern	unsigned	my_ip_addr;
extern	unsigned long	my_mac_addr = DEFAULTMAC, router_mac_addr = 0;
extern	unsigned	my_ip_mask = LCLNETMASK,
			my_ip_router = DEFAULT_ROUTERIP;
*/

extern	NET_PACKET *new_icmp(unsigned ln);
extern	void	icmp_reply(unsigned ipaddr, NET_PACKET *icmp_request);
extern	void	icmp_send_ping(unsigned int ipaddr);
extern	void	dump_icmp(NET_PACKET *pkt);

#endif
