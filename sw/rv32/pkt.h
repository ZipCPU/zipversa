////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	pkt.h
//
// Project:	ZipVersa, Versa Brd implementation using ZipCPU infrastructure
//
// Purpose:	Describes a packet that can be received, shared, processed,
//		and transmitted again
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
#ifndef	PKT_H
#define	PKT_H

typedef struct {
	int	p_usage_count, p_rawlen, p_length;
	char	*p_raw,	// Points to the beginning of raw packet memory
		*p_user;// Packet memory at the current protocol area
} NET_PACKET;

extern	NET_PACKET	 *rx_pkt(void);
extern	void		pkt_reset(NET_PACKET *pkt);
extern	void		tx_pkt(NET_PACKET *pkt);
extern	NET_PACKET	*new_pkt(unsigned msglen);
extern	void		free_pkt(NET_PACKET *pkt);

#endif
