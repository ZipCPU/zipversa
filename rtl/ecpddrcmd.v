////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	ecpddrcmd.v
//
// Project:	ZipVersa, Versa Brd implementation using ZipCPU infrastructure
//
// Purpose:	Use the OSHX2A primitive to output various command bits to the DDR3 SDRAM memory.
//		These include the RESET, CKE, CS_N, RAS_N, CAS_N, WE_N, BA[1:0], and ADDR[:0]
//	bits.
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
//
`default_nettype	none
//
//
module	ecpddrcmd #(parameter NWIDE = 4)
	(input	wire			i_clk, i_reset,
	input	wire			i_memclk,
	input	wire	[2*NWIDE-1:0]	i_data,
	output	wire	[NWIDE-1:0]	o_pins);

	generate for(k=0; k<NWIDE; k=k+1)
	begin
/*
		OSHX2A
		gencmd(
			.SCLK(i_clk),
			.RST(i_reset),
			.D0(NWIDE+k),
			.D1(k),
			//
			.ECLK(i_mem_clk),
			.Q(o_pins[k]));
*/

		ODDRX2F(
			.RST(i_reset),
			.SCLK(i_clk),
			.ECLK(i_memclk),
			.D0(i_data[NWIDE+k])
			.D1(i_data[NWIDE+k])
			.D2(i_data[k])
			.D3(i_data[k])
			.Q(o_pins[k]));

	end endgenerate

endmodule
