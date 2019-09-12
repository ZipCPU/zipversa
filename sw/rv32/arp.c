////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	arp.c
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
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include "arp.h"
#include "board.h"
#include "etcnet.h"
#include "protoconst.h"
#include "ethproto.h"

#define	ARP_REQUEST	1
#define	ARP_REPLY	2

///////////
//
//
// Simplified ARP table and ARP requester
//
//
///////////
unsigned	arp_requests_sent = 0;
uint32_t	my_ip_router = DEFAULT_ROUTERIP;
ETHERNET_MAC	router_mac_addr;

typedef	struct	{
	int		valid;
	unsigned	age, ipaddr;
	ETHERNET_MAC	mac;
} ARP_TABLE_ENTRY;

#define	NUM_ARP_ENTRIES	8
ARP_TABLE_ENTRY	arp_table[NUM_ARP_ENTRIES];

//
// Keep track of a log of all of our work for debugging purposes
typedef struct	{
	unsigned ipaddr;
	ETHERNET_MAC	mac;
} ARP_TABLE_LOG_ENTRY;

int	arp_logid = 0;
ARP_TABLE_LOG_ENTRY	arp_table_log[32];


static const char arp_packet[] = {
		// 0xff, 0xff, 0xff, 0xff, 0xff, 0xff,
		// 0x00, 0x00,
		0x00, 0x01, 0x08, 0x00,	// Ethernet, ARP EtherType
		0x06, 0x04, 0x00, 0x01,	// Addr length(s x2), Operation (Req)
		0, 0, 0, 0, 0, 0, 0, 0, 
		0, 0, 0, 0, 0, 0, 0, 0, 
		0, 0, 0, 0 };


void	init_arp_table(void) {
	for(int k=0; k<NUM_ARP_ENTRIES; k++)
		arp_table[k].valid = 0;
}

int	get_next_arp_index(void) {
	int	eid, eldest = 0, unused_id = -1, oldage = 0, found=-1;
	for(eid=0; eid<NUM_ARP_ENTRIES; eid++) {
		if (!arp_table[eid].valid) {
			unused_id = eid;
			break;
		} else if (arp_table[eid].age > oldage) {
			oldage = arp_table[eid].age;
			eldest = eid;
		}
	}

	if (unused_id >= 0)
		return unused_id;
	return eldest;
}

NET_PACKET *new_arp(void) {
	return	new_ethpkt(28);
}

void	send_arp_request(int ipaddr) {
	NET_PACKET *pkt;
printf("Building ARP request\n");
	pkt = new_arp();
printf("Packet at 0x%08x, p_user = 0x%08x, p_raw = 0x%08x\n",
	(unsigned)pkt,
	(unsigned)pkt->p_user,
	(unsigned)pkt->p_raw);

if (pkt->p_length != sizeof(arp_packet)) {
	printf("ERR: ARM-PACKET SIZE =%3d, new packet size of %3d\n",
		(unsigned)sizeof(arp_packet), pkt->p_length);
}
	memcpy(pkt->p_user, arp_packet, sizeof(arp_packet));

printf("Setting ARP packet\n");
	pkt->p_user[ 7] = ARP_REQUEST;

	// Initial ETHERTYPE_ARP is in the arp_packet array
	// pkt->p_buf[6] = (ETHERTYPE_ARP >> 8)&0x0ff;
	// pkt->p_buf[7] = (ETHERTYPE_ARP & 0x0ff);

	// My mac address
	pkt->p_user[ 8] = (my_mac_addr >> 40) & 0x0ff;
	pkt->p_user[ 9] = (my_mac_addr >> 32) & 0x0ff;
	pkt->p_user[10] = (my_mac_addr >> 24) & 0x0ff;
	pkt->p_user[11] = (my_mac_addr >> 16) & 0x0ff;
	pkt->p_user[12] = (my_mac_addr >>  8) & 0x0ff;
	pkt->p_user[13] = (my_mac_addr      ) & 0x0ff;

	// My IP address
	pkt->p_user[14] = (my_ip_addr >> 24) & 0x0ff;
	pkt->p_user[15] = (my_ip_addr >> 16) & 0x0ff;
	pkt->p_user[16] = (my_ip_addr >>  8) & 0x0ff;
	pkt->p_user[17] = (my_ip_addr      ) & 0x0ff;

	// Target addresses are initially all set to zero
	pkt->p_user[18] = 0;
	pkt->p_user[19] = 0;
	pkt->p_user[20] = 0;
	pkt->p_user[21] = 0;
	pkt->p_user[22] = 0;
	pkt->p_user[23] = 0;
	pkt->p_user[24] = (ipaddr >> 24)&0x0ff;
	pkt->p_user[25] = (ipaddr >> 16)&0x0ff;
	pkt->p_user[26] = (ipaddr >>  8)&0x0ff;
	pkt->p_user[27] = (ipaddr      )&0x0ff;

printf("Calling tx_ethpkt()\n");
	arp_requests_sent++;
	ETHERNET_MAC broadcast = 0x0fffffffffffful;
	printf("Requesting ARP packet\n");
	tx_ethpkt(pkt, ETHERTYPE_ARP, broadcast);
}

int	arp_lookup(unsigned ipaddr, ETHERNET_MAC *mac) {
	int	eid, eldest = 0, unused_id = -1, oldage = 0, found=-1;

	if (((((ipaddr ^ my_ip_addr) & my_ip_mask) != 0)
		|| (ipaddr == my_ip_router))
			&&(router_mac_addr)) {
printf("MAC ADDR is that of the router\n");
		*mac = router_mac_addr;
		return 0;
	}

	for(eid=0; eid<NUM_ARP_ENTRIES; eid++) {
		if (arp_table[eid].valid) {
			if (arp_table[eid].ipaddr == ipaddr) {
				arp_table[eid].age = 0;
				*mac = arp_table[eid].mac;
				return 0;
			} else if (arp_table[eid].age > oldage) {
				oldage = arp_table[eid].age++;
				eldest = eid;
				if (oldage >= 0x010000)
					arp_table[eid].valid = 0;
			} else
				arp_table[eid].age++;
		}
	}

printf("NO MAC FOUND, SENDING ARP REQUEST\n");

	send_arp_request(ipaddr);
	return 1;
}

void	arp_table_add(unsigned ipaddr, ETHERNET_MAC mac) {
	ETHERNET_MAC	lclmac;
	int		eid;

	arp_table_log[arp_logid].ipaddr = ipaddr;
	arp_table_log[arp_logid].mac = mac;
	arp_logid++;
	arp_logid&= 31;
	

	if (ipaddr == my_ip_addr)
		return;
	// Missing the 'if'??
	else if (ipaddr == my_ip_router) {
		router_mac_addr = mac;
	} else if (arp_lookup(ipaddr, &lclmac)==0) {
		if (mac != lclmac) {
			for(eid=0; eid<NUM_ARP_ENTRIES; eid++) {
				if ((arp_table[eid].valid)&&
					(arp_table[eid].ipaddr == ipaddr)) {
					volatile int *ev = &arp_table[eid].valid;
					// Prevent anyone from using an invalid
					// entry while we are updating it
					*ev = 0;
					arp_table[eid].age = 0;
					arp_table[eid].mac = mac;
					*ev = 1;
					break;
				}
			}
		}
	} else {
		volatile int *ev = &arp_table[eid].valid;
		eid = get_next_arp_index();

		// Prevent anyone from using an invalid entry while we are
		// updating it
		*ev = 0;
		arp_table[eid].age = 0;
		arp_table[eid].ipaddr = ipaddr;
		arp_table[eid].mac = mac;
		*ev = 1;
	}
}

void	send_arp_reply(ETHERNET_MAC dest_mac_addr, unsigned dest_ip_addr) {
	NET_PACKET *pkt;
	pkt = new_arp();

	memcpy(pkt->p_user, arp_packet, sizeof(arp_packet));

	pkt->p_user[ 7] = ARP_REPLY;

	// My mac address
	pkt->p_user[ 8] = (my_mac_addr >> 40) & 0x0ff;
	pkt->p_user[ 9] = (my_mac_addr >> 32) & 0x0ff;
	pkt->p_user[10] = (my_mac_addr >> 24) & 0x0ff;
	pkt->p_user[11] = (my_mac_addr >> 16) & 0x0ff;
	pkt->p_user[12] = (my_mac_addr >>  8) & 0x0ff;
	pkt->p_user[13] = (my_mac_addr      ) & 0x0ff;

	// My IP address
	pkt->p_user[14] = (my_ip_addr >> 24) & 0x0ff;
	pkt->p_user[15] = (my_ip_addr >> 16) & 0x0ff;
	pkt->p_user[16] = (my_ip_addr >>  8) & 0x0ff;
	pkt->p_user[17] = (my_ip_addr      ) & 0x0ff;

	// Target addresses are initially all set to zero
	pkt->p_user[18] = (dest_mac_addr >> 40) & 0x0ff;
	pkt->p_user[19] = (dest_mac_addr >> 32) & 0x0ff;
	pkt->p_user[20] = (dest_mac_addr >> 24) & 0x0ff;
	pkt->p_user[21] = (dest_mac_addr >> 16) & 0x0ff;
	pkt->p_user[22] = (dest_mac_addr >>  8) & 0x0ff;
	pkt->p_user[23] = (dest_mac_addr      ) & 0x0ff;
	pkt->p_user[24] = (dest_ip_addr >> 24)&0x0ff;
	pkt->p_user[25] = (dest_ip_addr >> 16)&0x0ff;
	pkt->p_user[26] = (dest_ip_addr >>  8)&0x0ff;
	pkt->p_user[27] = (dest_ip_addr      )&0x0ff;

	tx_ethpkt(pkt, ETHERTYPE_ARP, dest_mac_addr);
}

void	rx_arp(NET_PACKET *pkt) {
	for(unsigned k=0; k<6; k++) {
		// Ignore any malformed packets
		if (pkt->p_user[k] != arp_packet[k]) {
			printf("Ignoring ARP packet\n");
			free_pkt(pkt);
			return;
		}
	}

	uint64_t	src_mac;
	unsigned	src_ip;

	src_mac = (pkt->p_user[ 8] & 0x0ff);
	src_mac = (pkt->p_user[ 9] & 0x0ff) | (src_mac << 8);
	src_mac = (pkt->p_user[10] & 0x0ff) | (src_mac << 8);
	src_mac = (pkt->p_user[11] & 0x0ff) | (src_mac << 8);
	src_mac = (pkt->p_user[12] & 0x0ff) | (src_mac << 8);
	src_mac = (pkt->p_user[13] & 0x0ff) | (src_mac << 8);

	src_ip = (pkt->p_user[14] & 0x0ff);
	src_ip = (pkt->p_user[15] & 0x0ff) | (src_ip << 8);
	src_ip = (pkt->p_user[16] & 0x0ff) | (src_ip << 8);
	src_ip = (pkt->p_user[17] & 0x0ff) | (src_ip << 8);


	if (pkt->p_user[7] == 1) {
		// This is an ARP request that we need to reply to
		send_arp_reply(src_mac, src_ip);
	} else if (pkt->p_user[7] == 2) {
		// This is a reply to (hopefully) one of our prior requests
		arp_table_add(src_ip, src_mac);
	}

	free_pkt(pkt);
}
