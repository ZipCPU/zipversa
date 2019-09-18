////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	ecpnetdly.v
//
// Project:	ZipVersa, Versa Brd implementation using ZipCPU infrastructure
//
// Purpose:	The ECP5 needs a delay to control the various I/Os with respect
//		to the clock--just to get them all aligned.  This particular
//	module creates a user commandable delay, based around the DELAYF
//	programmable delay element.
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
module	ecpnetdly(i_clk, i_reset, i_commanded_delay, o_current_delay,
		i_pin, o_pin);
	parameter	NP = 4;
	parameter	NBITS= 16;
	parameter	CKDIV= 2;
	//
	localparam	DOWN = 1'b1;
	localparam	UP   = 1'b0;
	//
	input	wire			i_clk, i_reset;
	input	wire	[NBITS-1:0]	i_commanded_delay;
	output	wire	[NBITS-1:0]	o_current_delay;
	input	wire	[NP-1:0]	i_pin;
	output	wire	[NP-1:0]	o_pin;

	reg	[NBITS-1:0]	current_delay;
	reg	[CKDIV-1:0]	clock_divider;
	reg			ck_stb;
	wire	[NP-1:0]	dly_cflag;
	reg			r_syncd, dly_move, dly_direction;
	reg			maxed_out;
	genvar			gk;

	initial	r_syncd = 0;
	always @(posedge i_clk)
	if (i_reset)
		r_syncd <= 0;
	else if ((dly_direction == DOWN)&&(dly_move)&&(&dly_cflag))
		r_syncd <= 1;

	initial	clock_divider = 1;
	initial	ck_stb = 0;
	always @(posedge i_clk)
		{ ck_stb, clock_divider } <= clock_divider + 1;

	initial	maxed_out = 0;
	always @(posedge i_clk)
	if (dly_move)
		maxed_out <= (dly_direction == UP)&&(|dly_cflag);

	initial	current_delay = 0;
	always @(posedge i_clk)
	if (i_reset || !r_syncd)
		current_delay <= 0;
	else if (ck_stb && dly_move)
	begin
		if (dly_direction == DOWN)
			current_delay <= (current_delay != 0) ? current_delay - 1 : 0;
		else
			current_delay <= current_delay + ((dly_cflag == 0) ? 1:0);
	end

	assign	o_current_delay = current_delay;

	initial	dly_direction = DOWN;
	always @(posedge i_clk)
	if (!ck_stb && !dly_move)
	begin
		if (i_reset || !r_syncd)
			dly_direction <= DOWN;
		else
			dly_direction <= (current_delay > i_commanded_delay) ? DOWN:UP;
	end

	initial	dly_move = 0;
	always @(posedge i_clk)
	if (ck_stb)
	begin
		if (dly_move)
			dly_move <= 0;
		else if (!r_syncd)
			dly_move <= 1;
		else if (dly_direction == DOWN && ((current_delay != 0) || !(&dly_cflag)))
			dly_move <= 1;
		else if (dly_direction == UP && (dly_cflag == 0) && !maxed_out)
			dly_move <= 1;
	end

	generate begin : DELAY_IMPLEMENTATION
	for(gk=0; gk<NP; gk=gk+1)
	// begin : INDIVIDUAL PIN DELAY

`ifndef	FORMAL
`ifdef	YOSYS
`define	YOSYS_NOT_FORMAL
`endif
`endif

`ifdef	YOSYS_NOT_FORMAL

		DELAYF
		delayi(.LOADN(1'b1), .MOVE(dly_move), .DIRECTION(dly_direction),
			.A(i_pin[gk]), .Z(o_pin[gk]), .CFLAG(dly_cflag[gk]));

`else

		assign	o_pin[gk] = i_pin[gk];

`ifdef	VERILATOR
		assign	dly_cflag[gk] = 1;
`endif
`endif

	// end
	end endgenerate

`ifdef	FORMAL
	reg	f_past_valid;

	initial	f_past_valid = 0;
	always @(posedge i_clk)
		f_past_valid <= 1;

	(* anyconst *) reg [NBITS-1:0]	f_delay_max;
	reg	[NBITS-1:0]	f_pin_delay	[0:NP-1];

	always @(*)
		assume(f_delay_max > 0);

	always @(*)
		assert(ck_stb == (clock_divider == 0));

	generate for(gk=0; gk<NP; gk=gk+1)
	begin

		always @(*)
		if (!f_past_valid)
			assume(f_pin_delay[gk] <= f_delay_max);

		assign dly_cflag[gk] = (dly_direction == DOWN)
			?  (f_pin_delay[gk] == 0)
			:  (f_pin_delay[gk] == f_delay_max);

		always @(*)
			assert(f_pin_delay[gk] <= f_delay_max);

		always @(posedge i_clk)
		if (ck_stb && dly_move && !dly_cflag[gk])
		begin
			if (dly_direction == DOWN)
				f_pin_delay[gk] <= f_pin_delay[gk] - 1;
			else
				f_pin_delay[gk] <= f_pin_delay[gk] + 1;
		end

		if (gk > 0)
		begin
			always @(*)
			if (r_syncd)
				assert(f_pin_delay[gk] == f_pin_delay[0]);
		end
	end endgenerate

	always @(*)
		assert(f_delay_max >= o_current_delay);

	always @(posedge i_clk)
	if (maxed_out)
		assert(dly_direction == DOWN || !$rose(dly_move));

	always @(*)
	if (r_syncd)
		assert((&dly_cflag) || (dly_cflag == 0));

	always @(*)
	if (r_syncd && dly_direction == DOWN)
		assert((current_delay == 0) == (&dly_cflag));

	always @(*)
	if (r_syncd)
		assert(current_delay == f_pin_delay[0]);

	always @(posedge i_clk)
	if (f_past_valid && dly_move)
		assert($stable(dly_direction));

	reg	cvr_useful;
	(* anyconst *)	reg	[$clog2(NP)-1:0]	cvr_pin;
	always @(*)
		assume(cvr_pin < NP);

	always @(*)
	if (!f_past_valid)
		assume(f_pin_delay[cvr_pin] == f_delay_max);


	always @(*)
		cvr_useful = (f_delay_max >= 7);

	always @(*)
		cover(cvr_useful && r_syncd);

	always @(*)
		cover(cvr_useful && r_syncd && (dly_direction == UP));

	always @(posedge i_clk)
		cover(cvr_useful && r_syncd && $rose(dly_move));

	always @(*)
		cover(cvr_useful && r_syncd && o_current_delay == f_delay_max);
`endif
endmodule
