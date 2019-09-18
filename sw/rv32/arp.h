////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	arp.h
//
// Project:	ZipVersa, Versa Brd implementation using ZipCPU infrastructure
//
// Purpose:	To encapsulate common functions associated with the ARP protocol
//		and hardware (ethernet MAC) address resolution.
//
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
#ifndef	ARP_H
#define	ARP_H

#include "ethproto.h"

extern	uint32_t	my_ip_router;

extern	void	init_arp_table(void);
extern	void	send_arp_request(int ipaddr);
extern	int	arp_lookup(unsigned ipaddr, ETHERNET_MAC *mac);
// extern	void	arp_table_add(unsigned ipaddr, unsigned long mac);
extern	void	send_arp_reply(ETHERNET_MAC dest_mac_addr, unsigned dest_ip_addr);
extern	void	rx_arp(NET_PACKET *pkt);
extern	void	dump_arppkt(NET_PACKET *pkt);

#endif
