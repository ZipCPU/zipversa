////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	rxecrc.v
//
// Project:	ZipVersa, Versa Brd implementation using ZipCPU infrastructure
//
// Purpose:	To detect any CRC errors in the packet as received.  The CRC
//		is not stripped as part of this process.  However, any bytes
//	following the CRC, up to four, will be stripped from the output.
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
module	rxecrc(i_clk, i_reset, i_ce, i_en, i_v, i_d, o_v, o_d, o_err);
	localparam [31:0]	TAPS = 32'hedb88320;
	localparam	[0:0]	INVERT = 1'b1;
	input	wire		i_clk, i_reset, i_ce, i_en;
	input	wire		i_v;
	input	wire	[7:0]	i_d;
	output	reg		o_v;
	output	reg	[7:0]	o_d;
	output	wire		o_err;

	reg		r_err;
	reg	[2:0]	r_mq; // Partial CRC matches
	reg	[3:0]	r_mp; // Prior CRC matches

	reg	[31:0]	r_crc;
	reg	[23:0]	r_crc_q0;
	reg	[15:0]	r_crc_q1;
	reg	[ 7:0]	r_crc_q2;

	reg	[26:0]	r_buf;

	reg	[31:0]	crc_eqn	[0:7];
	wire	[7:0]	lowoctet;
	wire	[31:0]	shifted_crc;
	reg	[31:0]	eqn;

	// Verilator lint_off UNUSED
	integer	k;
	// Verilator lint_on  UNUSED

`define GENERATE_POLYNOMIALS
`ifdef	GENERATE_POLYNOMIALS
	initial begin
		crc_eqn[7] = TAPS;
		for(k=6; k>=0; k=k-1)
		begin : INITIAL_CRC_EQN
			// k = 6-j;
			if (crc_eqn[k+1][0])
				crc_eqn[k] = { 1'b0, crc_eqn[k+1][31:1] }^ TAPS;
			else
				crc_eqn[k] = { 1'b0, crc_eqn[k+1][31:1] };
		end
	end
`else
	always @(*)
	begin
		crc_eqn[0] = 32'h77073096;
		crc_eqn[1] = 32'hEE0E612C;
		crc_eqn[2] = 32'h076DC419;
		crc_eqn[3] = 32'h0EDB8832;
		crc_eqn[4] = 32'h1DB71064;
		crc_eqn[5] = 32'h3B6E20C8;
		crc_eqn[6] = 32'h76DC4190;
		crc_eqn[7] = TAPS;
	end
`endif

	assign	lowoctet  = r_crc[7:0] ^ i_d;

	assign	shifted_crc = { 8'h0, r_crc[31:8] };

`define	FOR_LOOP
`ifdef FOR_LOOP
	always @(*)
	begin
		eqn = 0;
		for(k=0; k<8; k=k+1)
		if (lowoctet[k])
			eqn = eqn ^ crc_eqn[k];
	end
`else
	reg	[31:0]	preqn	[0:7];

	always @(*)
	begin
		preqn[0] = lowoctet[0] ? crc_eqn[0] : 0;
		preqn[1] = preqn[0] ^ (lowoctet[1] ? crc_eqn[1] : 0);
		preqn[2] = preqn[1] ^ (lowoctet[2] ? crc_eqn[2] : 0);
		preqn[3] = preqn[2] ^ (lowoctet[3] ? crc_eqn[3] : 0);
		preqn[4] = preqn[3] ^ (lowoctet[4] ? crc_eqn[4] : 0);
		preqn[5] = preqn[4] ^ (lowoctet[5] ? crc_eqn[5] : 0);
		preqn[6] = preqn[5] ^ (lowoctet[6] ? crc_eqn[6] : 0);
		preqn[7] = preqn[6] ^ (lowoctet[7] ? crc_eqn[7] : 0);
		eqn = preqn[7];
	end
`endif

	initial	r_crc = (INVERT==0)? 32'h00 : 32'hffffffff;
	always @(posedge i_clk)
	if (i_reset)
		r_crc <= (INVERT==0)? 32'h00 : 32'hffffffff;
	else if (i_ce)
	begin
		if (i_v)
			/// Calculate the CRC
			r_crc <= shifted_crc ^ eqn;
		else if (!o_v)
			r_crc <= (INVERT==0)? 32'h00 : 32'hffffffff;
	end

	initial	o_v = 0;
	initial	o_d = 8'h0;
	initial	r_buf = 0;
	always @(posedge i_clk)
	begin
		if (i_ce)
		begin
			r_buf <= { r_buf[17:0], i_v, i_d };
			if ((!i_v)&&(r_buf[8]))
			begin
				// Trim the packet to the last matching
				// CRC
				if (r_mp[3])
				begin
					r_buf[ 8] <= 1'b0;
					r_buf[17] <= 1'b0;
					r_buf[26] <= 1'b0;
				end else if (r_mp[2])
				begin
					r_buf[ 8] <= 1'b0;
					r_buf[17] <= 1'b0;
				end else if (r_mp[1])
					r_buf[8] <= 1'b0;
				// else if (r_mp[0]) ... keep everything
			end

			o_v <= r_buf[26];
			o_d <= r_buf[25:18];
		end

		if (i_reset)
		begin
			r_buf[ 8] <= 1'b0;
			r_buf[17] <= 1'b0;
			r_buf[26] <= 1'b0;

			o_v <= 0;
		end
	end

	always @(posedge i_clk)
	if (i_ce)
	begin
		r_crc_q0 <= r_crc[31:8];
		r_crc_q1 <= r_crc_q0[23:8];
		r_crc_q2 <= r_crc_q1[15:8];
	end

	initial r_err = 1'b0;
	initial	r_mp  = 0;
	always @(posedge i_clk)
	if (i_reset)
	begin
		r_err <= 1'b0;
		r_mp <= 4'h0;
	end else if (i_ce)
	begin

		if (!i_v && !o_v)
		begin
			r_err <= 1'b0;
			r_mp <= 4'h0;
		end else
		begin

			r_mp <= { r_mp[2:0], 
				(r_mq[2])&&(i_v)&&(i_d == (~r_crc_q2[7:0])) };

			// Now, we have an error if ...
			// On the first empty, none of the prior N matches
			// matched.
			if (!r_err && i_en)
				r_err <= (!i_v &&(r_buf[8])&&(r_mp == 4'h0));
		end
	end

	initial	r_mq = 0;
	always @(posedge i_clk)
	if (i_reset)
		r_mq <= 0;
	else if (i_ce && i_v)
	begin
		r_mq[0] <=            (i_d == ((INVERT)?~r_crc[   7:0]:r_crc[7:0]));
		r_mq[1] <= (r_mq[0])&&(i_d == ((INVERT)?~r_crc_q0[7:0]:r_crc_q0[7:0]));
		r_mq[2] <= (r_mq[1])&&(i_d == ((INVERT)?~r_crc_q1[7:0]:r_crc_q1[7:0]));
	end else if (i_ce)
		r_mq <= 0;

	assign o_err = r_err;


////////////////////////////////////////////////////////////////////////////////
//
//
//
////////////////////////////////////////////////////////////////////////////////
`ifdef	FORMAL
	reg	[4:0]	f_v;
	reg		f_past_valid, f_clear;

	initial	f_past_valid = 0;
	always @(posedge  i_clk)
		f_past_valid <= 1'b1;

	initial	f_v = 0;
	always @(posedge i_clk)
	if (i_reset)
		f_v <= 0;
	else if (i_ce)
		f_v <= { f_v[3:0], i_v };
	////////////////////////////////////////////////////////////////////////
	//
	// Incoming assumptions
	//

	//
	// Reset assumptions
	//
	always @(*)
	if (!f_past_valid)
		assume(i_reset);

	always @(posedge i_clk)
	if (i_reset)
		assume(!i_v);

	//
	// Enable assumptions
	//
	// always @(posedge i_clk)
	// if ((f_past_valid)&&(i_v || o_v))
		// assume($stable(i_en));

	always @(posedge i_clk)
	if ((f_past_valid)&&(!$past(i_reset))&&((o_v)||(i_v)))
		assume($stable(i_en));

	//
	// CE assumptions
	//
	always @(posedge i_clk)
	if (!$past(i_ce))
		assume(i_ce);

	always @(posedge i_clk)
	if ($past(i_v && !i_ce))
	begin
		assume(i_v);
		assume($stable(i_d));
	end

	//
	// Incoming channel cannot become active until the outgoing
	// burst has completed.
	//

	initial	f_clear = 1;
	always @(posedge i_clk)
	if (i_reset || (i_ce && !i_v && !o_v))
		f_clear <= 1;
	else if (i_v)
		f_clear <= 0;

	always @(*)
	if (o_v || r_buf[8] || r_buf[17] || r_buf[26])
		assert(!f_clear);

	always @(posedge i_clk)
	if (f_past_valid && !f_clear)
		assume(!$rose(i_v));

	always @(posedge i_clk)
	if (f_v != 0)
	begin
		if (!f_v[4])
			assume(i_v);
		else if (!f_v[0])
			assume(!i_v);
	end
			
	////////////////////////////////////////////////////////////////////////
	//
	//
	always @(*)
	if (i_v && o_v)
	begin
		assert(r_buf[ 8]);
		assert(r_buf[17]);
		assert(r_buf[26]);
	end

	always @(posedge i_clk)
	if (!f_past_valid || $past(i_reset))
	begin
		// Test initial/reset conditions
		assert(r_crc == (INVERT==0)? 32'h00 : 32'hffffffff);
		assert(o_v   == 1'b0);
	end

	always @(*)
	begin
		assert(!r_buf[ 8] || f_v[0] == r_buf[ 8]);
		assert(!r_buf[17] || f_v[1] == r_buf[17]);
		assert(!r_buf[26] || f_v[2] == r_buf[26]);

		if (f_v != 0)
			assert((f_v == 5'h01)||(f_v == 5'h03)
				||(f_v == 5'h07)||(f_v == 5'h0f)
				||(f_v == 5'h1f)||(f_v == 5'h1e)
				||(f_v == 5'h1c)||(f_v == 5'h18)
				||(f_v == 5'h10));
	end



	reg	[31:0]	f_pre_crc	[7:0];
	reg	[31:0]	f_crc;

	// Need to verify the CRC
	always @(*)
	begin : GEN_PRECRC
// `define	FOR_LOOP2
`ifdef	FOR_LOOP2
		if (i_d[0] ^ r_crc[0])
			f_pre_crc[0] = { 1'b0, r_crc[31:1] } ^ TAPS;
		else
			f_pre_crc[0] = { 1'b0, r_crc[31:1] };

		for(k=1; k<8; k=k+1)
		begin
			if (f_pre_crc[k-1][0]^i_d[k])
				f_pre_crc[k] = { 1'b0, f_pre_crc[k-1][31:1] } ^ TAPS;
			else
				f_pre_crc[k] = { 1'b0, f_pre_crc[k-1][31:1] };
		end
`else
		f_pre_crc[0] = { 1'b0, r_crc[31:1] }
			^ ((r_crc[0] ^ i_d[0]) ? TAPS : 0);
		f_pre_crc[1] = { 1'b0, f_pre_crc[0][31:1] }
			^ ((f_pre_crc[0][0] ^ i_d[1]) ? TAPS : 0);
		f_pre_crc[2] = { 1'b0, f_pre_crc[1][31:1] }
			^ ((f_pre_crc[1][0] ^ i_d[2]) ? TAPS : 0);
		f_pre_crc[3] = { 1'b0, f_pre_crc[2][31:1] }
			^ ((f_pre_crc[2][0] ^ i_d[3]) ? TAPS : 0);
		f_pre_crc[4] = { 1'b0, f_pre_crc[3][31:1] }
			^ ((f_pre_crc[3][0] ^ i_d[4]) ? TAPS : 0);
		f_pre_crc[5] = { 1'b0, f_pre_crc[4][31:1] }
			^ ((f_pre_crc[4][0] ^ i_d[5]) ? TAPS : 0);
		f_pre_crc[6] = { 1'b0, f_pre_crc[5][31:1] }
			^ ((f_pre_crc[5][0] ^ i_d[6]) ? TAPS : 0);
		f_pre_crc[7] = { 1'b0, f_pre_crc[6][31:1] }
			^ ((f_pre_crc[6][0] ^ i_d[7]) ? TAPS : 0);
`endif

		f_crc = f_pre_crc[7];
	end

	always @(posedge i_clk)
	if (f_past_valid && $past(!i_reset && i_ce && i_v))
		assert(r_crc == $past(f_crc));

	always @(posedge i_clk)
	if ($past(i_ce)&&!$past(i_en))
		assert(!o_err);
	else if (!$past(i_en))
		assert(!$rose(o_err));

`ifdef	RXECRC
	////////////////////////////////////////////////////////////////////////
	//
	// Cover Properties
	//
	always @(posedge i_clk)
	if ($past(!i_reset && i_en))
	begin
		cover(f_past_valid && $fell(o_v) && $past(o_err));
		cover(f_past_valid && $fell(o_v) && o_err);
		cover(f_past_valid && $fell(o_v) && $past(!o_err));
		cover(f_past_valid && $fell(o_v) && !o_err);
	end

	////////////////////////////////////////////////////////////////////////	//
	// Known packet properties
	//
	// The following properties test two known packets, which are known to
	// have the right CRCs.  (Or ... at least I suspect so, they were
	// received on my local LAN)  Let's make some assertions that this
	// CRC receiver will
	reg	[68:0]	v1;
	reg	[4:0]	v1e;

	initial	v1 = 0;
	initial	v1e = 0;
	always @(posedge i_clk)
	if (i_reset)
	begin
		v1 <= 0;
		v1e <= 0;
	end else if (!i_v && !o_v)
	begin
		v1 <= 0;
		v1e <= 0;
	end else if (i_ce) begin
		v1 <= { v1[67:0], (v1[67:0] == 0 && !r_buf[8]) };
		if (!i_v)
			v1[63:0] <= 0;

		if (i_d != 8'hff) v1[ 0] <= 1'b0;
		if (i_d != 8'hff) v1[ 1] <= 1'b0;
		if (i_d != 8'hff) v1[ 2] <= 1'b0;
		if (i_d != 8'hff) v1[ 3] <= 1'b0;
		if (i_d != 8'hff) v1[ 4] <= 1'b0;
		if (i_d != 8'hff) v1[ 5] <= 1'b0;
		if (i_d != 8'hc8) v1[ 6] <= 1'b0;
		if (i_d != 8'h3a) v1[ 7] <= 1'b0;
		if (i_d != 8'h35) v1[ 8] <= 1'b0;
		if (i_d != 8'hd2) v1[ 9] <= 1'b0;
		if (i_d != 8'h07) v1[10] <= 1'b0;
		if (i_d != 8'hb1) v1[11] <= 1'b0;
		if (i_d != 8'h08) v1[12] <= 1'b0;
		if (i_d != 8'h00) v1[13] <= 1'b0;
		if (i_d != 8'h45) v1[14] <= 1'b0;
		if (i_d != 8'h00) v1[15] <= 1'b0;
		if (i_d != 8'h00) v1[16] <= 1'b0;
		if (i_d != 8'h24) v1[17] <= 1'b0;
		if (i_d != 8'h33) v1[18] <= 1'b0;
		if (i_d != 8'h76) v1[19] <= 1'b0;
		if (i_d != 8'h40) v1[20] <= 1'b0;
		if (i_d != 8'h00) v1[21] <= 1'b0;
		if (i_d != 8'h40) v1[22] <= 1'b0;
		if (i_d != 8'h11) v1[23] <= 1'b0;
		if (i_d != 8'h67) v1[24] <= 1'b0;
		if (i_d != 8'h02) v1[25] <= 1'b0;
		if (i_d != 8'hc0) v1[26] <= 1'b0;
		if (i_d != 8'ha8) v1[27] <= 1'b0;
		if (i_d != 8'h0f) v1[28] <= 1'b0;
		if (i_d != 8'h01) v1[29] <= 1'b0;
		if (i_d != 8'hc0) v1[30] <= 1'b0;
		if (i_d != 8'ha8) v1[31] <= 1'b0;
		if (i_d != 8'h0f) v1[32] <= 1'b0;
		if (i_d != 8'hff) v1[33] <= 1'b0;
		if (i_d != 8'h05) v1[34] <= 1'b0;
		if (i_d != 8'hfe) v1[35] <= 1'b0;
		if (i_d != 8'h05) v1[36] <= 1'b0;
		if (i_d != 8'hfe) v1[37] <= 1'b0;
		if (i_d != 8'h00) v1[38] <= 1'b0;
		if (i_d != 8'h10) v1[39] <= 1'b0;
		if (i_d != 8'hb5) v1[40] <= 1'b0;
		if (i_d != 8'h0b) v1[41] <= 1'b0;
		if (i_d != 8'h54) v1[42] <= 1'b0;
		if (i_d != 8'h43) v1[43] <= 1'b0;
		if (i_d != 8'h46) v1[44] <= 1'b0;
		if (i_d != 8'h32) v1[45] <= 1'b0;
		if (i_d != 8'h04) v1[46] <= 1'b0;
		if (i_d != 8'h00) v1[59:47] <= 1'b0;
		if (i_d != 8'h76) v1[60] <= 1'b0;
		if (i_d != 8'h49) v1[61] <= 1'b0;
		if (i_d != 8'h97) v1[62] <= 1'b0;
		if (i_d != 8'hda) v1[63] <= 1'b0;

		//
		// We need some assertions about the local state
		// in order to make certain induction passes for
		// any reasonable lengths
		if (v1[10])	assert(r_crc == 32'h3fcb4f66);
		if (v1[20])	assert(r_crc == 32'h6e2ed2ba);
		if (v1[30])	assert(r_crc == 32'h11e3b9bc);
		if (v1[40])	assert(r_crc == 32'hddb6c7e3);
		if (v1[50])	assert(r_crc == 32'h315b0bf0);
		if (v1[60])	assert(r_crc == 32'h2d27873b);

		//
		//
		if (i_v)
			v1[64] <= 1'b0;

		v1e[4:0] <= { v1e[3:0], 1'b0 };
		if ((v1[60])&&(i_v)&&(i_d != 8'h76))
			v1e[0] <= 1'b1;
		if ((v1[61])&&(i_v)&&(i_d != 8'h49))
			v1e[1] <= 1'b1;
		if ((v1[62])&&(i_v)&&(i_d != 8'h97))
			v1e[2] <= 1'b1;
		if ((v1[63])&&(i_v)&&(i_d != 8'hda))
			v1e[3] <= 1'b1;
		if (i_v)
			v1e[4] <= 1'b0;
		if (v1e[4])
			assert(o_err);

		if (v1[63])
			assert(o_v && o_d == 8'h76);
		if (v1[64])
			assert(o_v && o_d == 8'h49);
		if (v1[65])
			assert(o_v && o_d == 8'h97);
		if (v1[66])
			assert(o_v && o_d == 8'hda);
		if (v1[67])
			assert(!o_v);

		if (|v1[68:1])
			assert(!o_err);

		if (v1 != 0)
		for(k=0; k<67; k=k+1)
		if (v1[k])
			assert(v1 ^ (68'd1<<k) == 0);
	end

	//
	//
	//
	reg	[69:0]	v2;
	reg	[4:0]	v2e;

	initial	v2  = 0;
	initial	v2e = 0;
	always @(posedge i_clk)
	if (i_reset)
	begin
		v2  <= 0;
	end else if (!i_v && !o_v)
		v2 <= 0;
	else if (i_ce) begin
		v2 <= { v2[68:0], (v2[67:0]==0 && !r_buf[8]) };
		if (!i_v)
			v2[64:0] <= 0;
		if (!i_v && !o_v)
			v2 <= 0;
		if (i_d != 8'hff) v2[ 0] <= 1'b0;
		if (i_d != 8'hff) v2[ 1] <= 1'b0;
		if (i_d != 8'hff) v2[ 2] <= 1'b0;
		if (i_d != 8'hff) v2[ 3] <= 1'b0;
		if (i_d != 8'hff) v2[ 4] <= 1'b0;
		if (i_d != 8'hff) v2[ 5] <= 1'b0;
		if (i_d != 8'hc8) v2[ 6] <= 1'b0;
		if (i_d != 8'h3a) v2[ 7] <= 1'b0;
		if (i_d != 8'h35) v2[ 8] <= 1'b0;
		if (i_d != 8'hd2) v2[ 9] <= 1'b0;
		if (i_d != 8'h07) v2[10] <= 1'b0;
		if (i_d != 8'hb1) v2[11] <= 1'b0;
		if (i_d != 8'h08) v2[12] <= 1'b0;
		if (i_d != 8'h00) v2[13] <= 1'b0;
		if (i_d != 8'h45) v2[14] <= 1'b0;
		if (i_d != 8'h00) v2[15] <= 1'b0;
		if (i_d != 8'h00) v2[16] <= 1'b0;
		if (i_d != 8'h24) v2[17] <= 1'b0;
		if (i_d != 8'h0b) v2[18] <= 1'b0;
		if (i_d != 8'hca) v2[19] <= 1'b0;
		if (i_d != 8'h40) v2[20] <= 1'b0;
		if (i_d != 8'h00) v2[21] <= 1'b0;
		if (i_d != 8'h40) v2[22] <= 1'b0;
		if (i_d != 8'h11) v2[23] <= 1'b0;
		if (v2[23])
			assert(o_v && o_d == 8'h40);
		if (i_d != 8'h8e) v2[24] <= 1'b0;
		if (i_d != 8'hae) v2[25] <= 1'b0;
		if (i_d != 8'hc0) v2[26] <= 1'b0;
		if (i_d != 8'ha8) v2[27] <= 1'b0;
		if (i_d != 8'h0f) v2[28] <= 1'b0;
		if (i_d != 8'h01) v2[29] <= 1'b0;
		if (i_d != 8'hc0) v2[30] <= 1'b0;
		if (i_d != 8'ha8) v2[31] <= 1'b0;
		if (i_d != 8'h0f) v2[32] <= 1'b0;
		if (i_d != 8'hff) v2[33] <= 1'b0;
		if (v2[33])
			assert(o_v && o_d == 8'hc0);

		if (i_d != 8'h82) v2[34] <= 1'b0;
		if (i_d != 8'h66) v2[35] <= 1'b0;
		if (i_d != 8'h05) v2[36] <= 1'b0;
		if (i_d != 8'hfe) v2[37] <= 1'b0;
		if (i_d != 8'h00) v2[38] <= 1'b0;
		if (i_d != 8'h10) v2[39] <= 1'b0;
		if (i_d != 8'h38) v2[40] <= 1'b0;
		if (i_d != 8'ha3) v2[41] <= 1'b0;
		if (i_d != 8'h54) v2[42] <= 1'b0;
		if (i_d != 8'h43) v2[43] <= 1'b0;
		if (i_d != 8'h46) v2[44] <= 1'b0;
		if (i_d != 8'h32) v2[45] <= 1'b0;
		if (i_d != 8'h04) v2[46] <= 1'b0;
		//
		if (i_d != 8'h00) v2[59:47] <= 1'b0;
		//
		if (i_d != 8'ha7) v2[60] <= 1'b0;
		if (i_d != 8'h2e) v2[61] <= 1'b0;
		if (i_d != 8'h5e) v2[62] <= 1'b0;
		if (i_d != 8'hd4) v2[63] <= 1'b0;
		if (i_v)
			v2[64] <= 1'b0;

		if (v2[63])
			assert(o_v && o_d == 8'ha7);
		if (v2[64])
			assert(o_v && o_d == 8'h2e);
		if (v2[65])
			assert(o_v && o_d == 8'h5e);
		if (v2[66])
			assert(o_v && o_d == 8'hd4);
		if (v2[67])
			assert(!o_v);

		if (v2[10])	assert(r_crc == 32'h3fcb4f66);
		if (v2[20])	assert(r_crc == 32'h0c268726);
		if (v2[30])	assert(r_crc == 32'hc59ba1ca);
		if (v2[40])	assert(r_crc == 32'h3e4dc0e9);
		if (v2[50])	assert(r_crc == 32'h68de0843);
		if (v2[60])	assert(r_crc == 32'h2d294e5c);


		if (|v2[66:1])
			assert(!o_err);
		for(k=0; k<65; k=k+1)
		if (v2[k])
			assert(v2 ^ (66'd1<<k) == 0);
	end

	initial	v2e = 0;
	always @(posedge i_clk)
	if (i_reset)
		v2e <= 0;
	else if (i_ce)
	begin
		v2e[4:0] <= { v2e[3:0], 1'b0 };
		if ((v2[59])&&(i_d != 8'ha7))
			v2e[0] <= 1'b1;
		if ((v2[60])&&(i_d != 8'h2e))
			v2e[1] <= 1'b1;
		if ((v2[61])&&(i_d != 8'h5e))
			v2e[2] <= 1'b1;
		if ((v2[62])&&(i_d != 8'hd4))
			v2e[3] <= 1'b1;
		if (!i_v)
			v2e[4:0] <= 0;
		if (v2e[4])
			assert(o_err);

	end

	always @(*)
	begin
		if (|v2e)
			assert(v2==0);
	end

	always @(*)
	begin
		assert(v1[17:0] == v2[17:0]);
		if (|v1[64:18])
			assert(v2 == 0);
		if (|v2[64:18])
			assert(v1 == 0);
	end

	always @(*)
		cover(v1[68]);
	always @(*)
		cover(v2[69]);

// Tests
//	The other MAC is ff:ff:ff:ff:ff:ff
// 
	// RX[ 0]: 0xc83a35d2
	// RX[ 1]: 0x07b10800
	// RX[ 2]: 0x45000024
	// RX[ 3]: 0x33764000
	// RX[ 4]: 0x40116702
	// RX[ 5]: 0xc0a80f01
	// RX[ 6]: 0xc0a80fff
	// RX[ 7]: 0x05fe05fe
	// RX[ 8]: 0x0010b50b
	// RX[ 9]: 0x54434632
	// RX[10]: 0x04000000
	// RX[11]: 0x00000000
	// RX[12]: 0x00000000
	// RX[13]: 0x00007649
	// RX[14]: 0x97da0000
// Final Rx Status = 0e08403b
`endif

	always @(*)
	begin
		assert(crc_eqn[0] == 32'h77073096);
		assert(crc_eqn[1] == 32'hEE0E612C);
		assert(crc_eqn[2] == 32'h076DC419);
		assert(crc_eqn[3] == 32'h0EDB8832);
		assert(crc_eqn[4] == 32'h1DB71064);
		assert(crc_eqn[5] == 32'h3B6E20C8);
		assert(crc_eqn[6] == 32'h76DC4190);
		assert(crc_eqn[7] == TAPS);
	end
`endif	// FORMAL
endmodule
