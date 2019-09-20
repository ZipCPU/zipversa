////////////////////////////////////////////////////////////////////////////////
//
// Filename:	sw/host/udpsocket.cpp
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
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <strings.h>
#include <ctype.h>
#include <string.h>
#include <signal.h>
#include <assert.h>

// #include "port.h"
#include <sys/mman.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <stdint.h>
// #include "hps.h"
#include <time.h>
#include "udpsocket.h"

#include <poll.h>

const int	DEF_REQUEST_PORT = 6783,
		DEF_REPLY_PORT = DEF_REQUEST_PORT+1;

UDPSOCKET::UDPSOCKET(const char *ipaddr, bool verbose) {
	char	*ptr;

	if (NULL == ipaddr)
		m_skt = -1;
	else {
		char	*iplcl = strdup(ipaddr);

		m_skt = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
		if (m_skt < 0) {
			fprintf(stderr, "Err: Could not allocate a socket\n");
			perror("O/S Err:");
			exit(EXIT_FAILURE);
		}

		memset((char *)&m_addr, 0, sizeof(m_addr));
		m_addr.sin_family = AF_INET;

		//
		// Set the port number
		//
		if (NULL != (ptr = strchr(iplcl, ':'))) {
			m_addr.sin_port = htons(atoi(ptr+1));
			if (m_addr.sin_port < 1024) {
				fprintf(stderr, "Err: Illegal port!\n");
				exit(EXIT_FAILURE);
			}
		} else {
			m_addr.sin_port = htons(DEF_REQUEST_PORT);
		}

		// Set the IP address
		if (isdigit(iplcl[0])) {
			if (NULL != (ptr = strchr(iplcl, ':')))
				*ptr = '\0';
			if (0 == inet_aton(iplcl, &m_addr.sin_addr)) {
				fprintf(stderr, "Err: Invalid IP address, %s\n", iplcl);
				exit(EXIT_FAILURE);
			}
		} else if (isalpha(iplcl[0])) {
			struct	hostent	*hp;
			char	*hname = strdup(iplcl), *ptr;
			if (NULL != (ptr = strchr(hname, ':')))
				*ptr = '\0';
			hp = gethostbyname(hname);
			if (hp == NULL) {
				fprintf(stderr, "Err: Could not get host entity for %s\n", hname);
				perror("O/S Err:");
				exit(EXIT_FAILURE);
			} bcopy(hp->h_addr, &m_addr.sin_addr.s_addr, hp->h_length);

			free(hname);
		} else {
			fprintf(stderr, "Err: Illegal IP address, %s\n", iplcl);
			exit(EXIT_FAILURE);
		}

		free(iplcl);
	}
}

ssize_t	UDPSOCKET::write(const void *buf, size_t len) {
	int	flags = MSG_DONTWAIT;	// was zero
	ssize_t	nw;
	nw = sendto(m_skt, buf, len, flags, (struct sockaddr *)&m_addr, 
		sizeof(m_addr));
	return nw;
}

void	UDPSOCKET::bind(void) {
	struct	addrinfo	hints, *res;
	char	portstr[64];

	sprintf(portstr, "%d", DEF_REPLY_PORT);

	hints.ai_family = AF_INET;	// Could be AF_UNSPEC
	hints.ai_socktype = SOCK_DGRAM;
	hints.ai_flags = AI_PASSIVE; // Fill in my IP for me
	hints.ai_protocol = 0; // Any protocol can be returned
	getaddrinfo("192.168.15.1", portstr, &hints, &res);

// printf("Cannonname = %s\n", (hints.ai_cannoname) ? hints.ai_cannonname : "(NULL)");
	if (::bind(m_skt, res->ai_addr, res->ai_addrlen) < 0) {
		perror("Bind O/S Err:");
		exit(EXIT_FAILURE);
	}
}

ssize_t	UDPSOCKET::read(void *buf, size_t len, unsigned timeout_ms) {
	int	flags = 0;
	ssize_t	nr;
	// struct	sockaddr_in	si_other;

	if (timeout_ms != 0) {
		struct	pollfd	pollfds;
		int	nr;

		pollfds.fd = m_skt;
		pollfds.events = POLLIN;

		nr = ::poll(&pollfds, 1, timeout_ms);

		if (nr == 0) {
printf("Timeout, revents = pollfds[0].revents = %d\n", pollfds.revents);
assert(pollfds.revents == 0);
			return 0;
		} else if (nr < 0) {
fprintf(stderr, "Poll error\n");
perror("O/S Err\n");
exit(EXIT_FAILURE);
		}
	}

	// memcpy(&si_other, &m_addr, sizeof(si_other));

	nr = recvfrom(m_skt, buf, len, flags, NULL, 0);
	if (nr < 0) {
		perror("O/S Err:");
		exit(-1);
	}
	return nr;
}

