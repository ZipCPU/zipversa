////////////////////////////////////////////////////////////////////////////////
//
// Filename:	sw/host/udpsocket.h
//
// Project:	ZipVersa, Versa Brd implementation using ZipCPU infrastructure
//
// Purpose:	To encapsulate the writing to and reading-from a UDP network
//		port (socket).
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
#ifndef	UDPSOCKET_H
#define	UDPSOCKET_H

#include <unistd.h>
#include <sys/socket.h>
#include <arpa/inet.h>

class	UDPSOCKET {
private:
	int			m_skt;
	struct	sockaddr_in	m_addr;
public:
	UDPSOCKET(const char *ipaddr, bool verbose = false);
	~UDPSOCKET(void) {
		close(m_skt);
	}
	void	bind(void);
	ssize_t	read(void *buf, size_t count, unsigned timeout_ms = 0);
	ssize_t	write(const void *buf, size_t count);
	bool	operator!(void) {
		return (m_skt < 0);
	}
	operator bool(void) {
		return (m_skt >= 0);
	}
};

extern	const	int	DEF_REQEST_PORT, DEF_REPLY_PORT;

#endif
