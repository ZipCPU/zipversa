////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	ecpioddr.v
//
// Project:	ZipVersa, Versa Brd implementation using ZipCPU infrastructure
//
// Purpose:	
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
`default_nettype	none
//
module	ecpioddr(i_clk, i_oe, i_v, o_v, io_pin);
	input	wire		i_clk, i_oe;
	input	wire	[1:0]	i_v;
	output	wire	[1:0]	o_v;
	input	wire		io_pin;

	wire	o_pin;

	ODDRX1F
	ODDRi(
		.SCLK(i_clk),
		.RST(1'b0),
		.D0(i_v[1]),	// D0 is sent first
		.D1(i_v[0]),	// then D1
		.Q(o_pin));


	assign	io_pin = (i_oe) ? o_pin : 1'bz;

	IDDRX1F IDDRi(
		.RST(1'b0),
		.SCLK(i_clk),
		.D(io_pin),
		.Q1(o_v[1]),	// Q1 comes first
		.Q0(o_v[0]));	// then Q0

endmodule
