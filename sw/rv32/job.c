////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	job.c
//
// Project:	ZipVersa, Versa Brd implementation using PicoRV32 infrastructure
//
// Purpose:	This is the C-library version of the I/O test.  We'll use
//		printf() to print a message to the stdio port.
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

const char	message[] = 
"\n"
"|------------------------------------------------------------------------------|\n"
"|                                                                              |\n"
"| Job, chapter 28                                                              |\n"
"| -------------------                                                          |\n"
"|                                                                              |\n"
"| Surely there is a vein for the silver, and a place for gold where they fine  |\n"
"|   it.                                                                        |\n"
"| Iron is taken out of the earth, and brass is molten out of the stone.        |\n"
"| He setteth an end to darkness, and searcheth out all perfection: the stones  |\n"
"|   of darkness, and the shadow of death.                                      |\n"
"| The flood breaketh out from the inhabitant; even the waters forgotten of the |\n"
"|   foot: they are dried up, they are gone away from men.                      |\n"
"| As for the earth, out of it cometh bread: and under it is turned up as it    |\n"
"|   were fire.                                                                 |\n"
"| The stones of it are the place of sapphires: and it hath dust of gold.       |\n"
"|                                                                              |\n"
"| There is a path which no fowl knoweth, and which the vulture's eye hath not  |\n"
"|   seen:                                                                      |\n"
"| The lion's whelps have not trodden it, nor the fierce lion passed by it.     |\n"
"| He putteth forth his hand upon the rock; he overturneth the mountains by the |\n"
"|   roots.                                                                     |\n"
"| He cutteth out rivers among the rocks; and his eye seeth every precious      |\n"
"|   thing.                                                                     |\n"
"| He bindeth the floods from overflowing; and the thing that is hid bringeth   |\n"
"|   he forth to light.                                                         |\n"
"|                                                                              |\n"
"| But where shall wisdom be found? and where is the place of understanding?    |\n"
"| Man knoweth not the price thereof; neither is it found in the land of the    |\n"
"|   living.                                                                    |\n"
"| The depth saith, It is not in me: and the sea saith, It is not with me.      |\n"
"| It cannot be gotten for gold, neither shall silver be weighed for the price  |\n"
"|   thereof.                                                                   |\n"
"| It cannot be valued with the gold of Ophir, with the precious onyx, or the   |\n"
"|   sapphire.                                                                  |\n"
"| The gold and the crystal cannot equal it: and the exchange of it shall not   |\n"
"|   be for jewels of fine gold.                                                |\n"
"| No mention shall be made of coral, or of pearls: for the price of wisdom is  |\n"
"|   above rubies.                                                              |\n"
"| The topaz of Ethiopia shall not equal it, neither shall it be valued with    |\n"
"|   pure gold.                                                                 |\n"
"|                                                                              |\n"
"| Whence then cometh wisdom? and where is the place of understanding?          |\n"
"| Seeing it is hid from the eyes of all living, and kept close from the fowls  |\n"
"|   of the air.                                                                |\n"
"| Destruction and death say, We have heard the fame thereof with our ears.     |\n"
"|                                                                              |\n"
"| God understandeth the way thereof, and he knoweth the place thereof.         |\n"
"| For he looketh to the ends of the earth, and seeth under the whole heaven;   |\n"
"| To make the weight for the winds; and he weigheth the waters by measure.     |\n"
"| When he made a decree for the rain, and a way for the lightning of the       |\n"
"|   thunder:                                                                   |\n"
"| Then did he see it, and declare it; he prepared it, yea, and searched it     |\n"
"|   out.                                                                       |\n"
"| And unto man he said, Behold, the fear of the LORD, that is wisdom; and to   |\n"
"|   depart from evil is understanding.                                         |\n"
"|                                                                              |\n"
"|------------------------------------------------------------------------------|\n";

int	main(int argc, char **argv) {
	// Print Job 28 the UART using the (newlib) C standard library!
	printf(message);
	return 0;
}
