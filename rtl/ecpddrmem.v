////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	ecpddrmem.v
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
module	ecpddrmem #(
	parameter	NLANES = 2	// Number of data bytes
	) (
	input	wire			i_clk, i_rst,
	input	wire			i_mem_clk, i_rst2x,
	input	wire [NLANES*4-1:0]	i_dqm,
	input	wire [NLANES*8*4-1:0]	i_data,
	input	wire [NLANES*4-1:0]	i_dqs_control,
	input	wire			i_oe,
	output	wire [NLANES*8*4-1:0]	o_data,
	inout	wire [NLANES*8*4-1:0]	io_dq,
	inout	wire [NLANES*4-1:0]	io_dqs
	);

	DDRDLLA
	ddrdllai(.CLK(i_mem_clk),
		.UDDCNTLN(!update),
		.FREEZE(freeze),
		.DDRDEL(ddrdll_delay),
		.LOCK(_lock));

	ODDRX2F
	clkoddr(
		.SCLK(i_clk),
		.ECLK(i_mem_clk),
		.RST(i_rst2x),
		.D0(0), .D1(1), .D2(0), .D3(1),
		.Q(o_clk_p));

	generate for(lane=0; lane<NLANES; lane=lane+1)
	begin
		wire		i_dqs, o_dqs, t_dqs;
		wire		dqsr90, dqsw270, dqsw;
		wire	[2:0]	rdpntr, wrpntr;
		wire	[6:0]	rdly;

		for(bit=0; bit<9; bit=bit+1)
		begin
			// Expect 9-bits per lane: 8-bits of data + DQM bit
			// DQS is treated special and outside this loop

			integer	pinmap = lane * 9 + bit;
			wire		i_pin, o_pin;
			wire	[3:0]	l_topin, l_from_pin;

			if (bit < 8)
			begin
				assign	l_topin = {
					i_data[3*NLANES*8 + lane*8 + bit],
					i_data[2*NLANES*8 + lane*8 + bit],
					i_data[1*NLANES*8 + lane*8 + bit],
					i_data[0*NLANES*8 + lane*8 + bit] };
			end else begin
				assign	l_topin = {
					i_dqm[lane*4+3],
					i_dqm[lane*4+2],
					i_dqm[lane*4+1],
					i_dqm[lane*4+0] };
			end

			DELAYF #(.DEL_MODE("DQS_ALIGNED_X2"))
			dly_incoming(.A(i_pin),
				.LOADN(1), .MOVE(0), .DIRECTION(0),
				.Z(i_pin_delayed));
			IDDRX2DQA
			incoming_data(
				.RST(i_rst2x),
				.D(i_pin)
				.DQSR90(dqsr90),
				.ECLK(i_mem_clk),	//
				.SCLK(i_clk),
				.RDPNTR0(rdpntr[0]),
				.RDPNTR1(rdpntr[1]),
				.RDPNTR2(rdpntr[2]),
				.WRPNTR0(wrpntr[0]),
				.WRPNTR1(wrpntr[1]),
				.WRPNTR2(wrpntr[2]),
				.Q0(l_frompin[lane]),	// Data at positive edge of DQS
				.Q1(l_frompin[lane]),
				.Q2(l_frompin[lane]),	// Data at positive edge of DQS
				.Q3(l_frompin[lane])
				//.QWL()	// Data output used for write leveling
				);

			TSHX2DQA
			data_line_tristate(
				.SCLK(i_clk),
				.ECLK(i_mem_clk),
				.RST(i_rst2x),
				.T0(!oe_dq),		// T0 is output first,
				.T1(!oe_dq),		// then T1
				.DQSW270(dqsw270),
				.Q(t_pin));

			ODDRX2DQA	// Generate the DQ data output with x2 gearing for DDR3
			outgoing_data(
				.D0(l_topin[0]),	// First
				.D1(l_topin[1]),
				.D2(l_topin[2]),
				.D3(l_topin[3]),	// Last
				.RST(i_rst2x),
				.SCLK(i_clk),
				.ECLK(i_mem_clk),
				.DQSW270(dqsw270),
				.O(o_pin));

			BB(.I(o_pin), .T(t_pin), .O(i_pin), .B(io_dq[pinmap]));
		end

		DQSBUFM #(
			.DQS_LI_DEL_ADJ("MINUS"),
			.DQS_LI_DEL_VAL(1),
			.DQS_LO_DEL_ADJ("MINUS"),
			.DQS_LO_DEL_VAL(4),
		) dqs_strobe_control_block(
			// Input/control pins
			.SCLK(i_clk),		// System clock
			.ECLK(i_mem_clk),	// Edge clock
			.RST(i_reset),		// System Reset
			//
			.DDRDEL(ddrdll_delay),	// Delay code from DDRDLL
			.PAUSE(pause | _dly_sel.storage[i] ?),
			//
			// Control
			.RDLOADN(0),
			.RDMOVE(0),
			.RDDIRECTION(1),
			.WRMOVE(0),
			.WRDIRECTION(1),
			//
			//
//
// dqs_read is true if we are reading data
//
			.READ0(dqs_read),
			.READ1(dqs_read),
			.READCLKSEL0(rdly[0]),
			.READCLKSEL1(rdly[0]),
			.READCLKSEL2(rdly[0]),
			.DQSI(i_dqs),
			//
			// Output pins
			.DQSR90(dqsr90),
			.DQSW(dqsw),
			.DQSW270(dqsw270),
			.RDPNTR0(rdpntr[0]),
			.RDPNTR1(rdpntr[1]),
			.RDPNTR2(rdpntr[2]),
			.WRPNTR0(wrpntr[0]),
			.WRPNTR1(wrpntr[1]),
			.WRPNTR2(wwrntr[2]),
			.DATAVALID(datavalid[i]),
			.BURSTDET(burstdet)
		);

		TSHX2DQSA
		tristate_dqs(
			.SCLK(i_clk),
			.ECLK(i_mem_clk),
			.RST(i_rst2x),
			.T0(~(i_oe|dqs_postamble)),
			.T1(~(i_oe|dqs_preamble)),
			.DQSW(dqsw),
			.Q(t_dqs));

		/*
		// Generate outgoing DQS signals
		ODDRX2DQSB
		gendqs(
			.SCLK(i_clk),
			.ECLK(i_mem_clk),
			.RST(i_rst2x),
			.DQSW270(i_mem_clk_270),
			//
			.D0(),	// First
			.D1(),
			.D2(),
			.D3(),	// Last
			.O(o_dqs);
		//
		// Not used here
		*/

		BB(.I(o_dqs), .T(t_dqs), .O(i_dqs), .B(io_dqs[bit]));

	end endgenerate

endmodule
