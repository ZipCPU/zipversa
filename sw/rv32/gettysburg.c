////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	gettysburg.c
//
// Project:	ZipVersa, Versa Brd implementation using PicoRV32 infrastructure
//
// Purpose:	The classical "Hello, world!\r\n" program.  This one, however,
//		runs on the Versa board running the picoRV32.  It also outputs
//	the Gettysburg address, rather than just Hello World.
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
#include <unistd.h>

#include "board.h"
#include "txfns.h"

const char	address[] = 
"\r\n"
"+ ---------------------------------------------------------------------------- +\r\n"
"|                                                                              |\r\n"
"| Gettysburg Address                                                           |\r\n"
"| ----------------------                                                       |\r\n"
"|                                                                              |\r\n"
"| Four score and seven years ago our fathers brought forth on this continent,  |\r\n"
"| a new nation, conceived in Liberty, and dedicated to the proposition that    |\r\n"
"| all men are created equal.                                                   |\r\n"
"|                                                                              |\r\n"
"| Now we are engaged in a great civil war, testing whether that nation, or any |\r\n"
"| nation so conceived and so dedicated, can long endure.  We are met on a      |\r\n"
"| great battle-field of that war.  We have come to dedicate a portion of that  |\r\n"
"| field, as a final resting place for those who here gave their lives that     |\r\n"
"| that nation might live.  It is altogether fitting and proper that we should  |\r\n"
"| do this.                                                                     |\r\n"
"|                                                                              |\r\n"
"| But, in a larger sense, we can not dedicate-we can not consecrate-we can not |\r\n"
"| hallow-this ground.  The brave men, living and dead, who struggled here,     |\r\n"
"| have consecrated it, far above our poor power to add or detract.  The world  |\r\n"
"| will little note, nor long remember what we say here, but it can never       |\r\n"
"| forget what they did here.  It is for us the living, rather, to be dedicated |\r\n"
"| here to the unfinished work which they who fought here have thus far so      |\r\n"
"| nobly advanced.  It is rather for us to be here dedicated to the great task  |\r\n"
"| remaining before us-that from these honored dead we take increased devotion  |\r\n"
"| to that cause for which they gave the last full measure of devotion-that we  |\r\n"
"| here highly resolve that these dead shall not have died in vain-that this    |\r\n"
"| nation, under God, shall have a new birth of freedom-and that government of  |\r\n"
"| the people, by the people, for the people, shall not perish from the earth.  |\r\n"
"|                                                                              |\r\n"
"+------------------------------------------------------------------------------+\r\n";

int	main(int argc, char **argv) {
	// Print the Gettysburg address out the UART!
	txstr(address);
	return 0;
}
