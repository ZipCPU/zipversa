////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	wbddrsdram.v
//
// Project:	ZipVersa, Versa Brd implementation using ZipCPU infrastructure
//
// Purpose:	To control a DDR3-1333 (9-9-9) memory from a wishbone bus.
//		In our particular implementation, there will be two command
//	clocks (2.5 ns) per FPGA clock (i_clk) at 5 ns, and 64-bits transferred
//	per FPGA clock.  However, since the memory is focused around 128-bit
//	word transfers, attempts to transfer other than adjacent 64-bit words
//	will (of necessity) suffer stalls.  Please see the documentation for
//	more details of how this controller works.
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
`default_nettype none
//
module	wbddrsdram(i_clk, i_reset,
		// Wishbone inputs
		i_wb_cyc, i_wb_stb, i_wb_we, i_wb_addr, i_wb_data,
			i_wb_sel,
		// Wishbone outputs
		o_wb_ack, o_wb_stall, o_wb_data,
		// Memory command wires
		o_ddr_reset_n, o_ddr_cke, // o_ddr_bus_oe,
		o_ddr_cmd_a, o_ddr_cmd_b, o_ddr_cmd_c, o_ddr_cmd_d,
		// And the data wires to go with them ....
		o_ddr_data, i_ddr_data);
	// These parameters are not really meant for adjusting from the
	// top level.  These are more internal variables, recorded here
	// so that things can be automatically adjusted without much
	// problem.
	parameter	CKRP = 0;
	parameter	BUSNOW = 2, BUSREG = BUSNOW-1;
	localparam	AW = 24;
	localparam	CMDW = 27;
	localparam	LANES = 2;
	localparam	DW = LANES * 8 * 8;
	localparam	DDRDW = LANES * 8 * 8; // 8b per lane, 2 side ea of 4cyc
	//
	// Possible commands to the DDR3 memory.  These consist of settings
	// for the bits: o_wb_cs_n, o_wb_ras_n, o_wb_cas_n, and o_wb_we_n,
	// respectively.
	localparam [3:0] DDR_MRSET     = 4'b0000;
	localparam [3:0] DDR_REFRESH   = 4'b0001;
	localparam [3:0] DDR_PRECHARGE = 4'b0010;
	localparam [3:0] DDR_ACTIVATE  = 4'b0011;
	localparam [3:0] DDR_WRITE     = 4'b0100;
	localparam [3:0] DDR_READ      = 4'b0101;
	localparam [3:0] DDR_ZQS       = 4'b0110;
	localparam [3:0] DDR_NOOP      = 4'b0111;
	// localparam [3:0] DDR_DESELECT = 4'b1???;
	//
	// In this controller, 24-bit commands tend to be passed around.  These 
	// 'commands' are bit fields.  Here we specify the bits associated with
	// the bit fields.
	localparam	DDR_RSTDONE  = 24;// End the reset sequence?
	localparam	DDR_RSTTIMER = 23;// Does this reset command take multiple clocks?
	localparam	DDR_RSTBIT   = 22;// Value to place on reset_n
	localparam	DDR_CKEBIT   = 21;// Should this reset command set CKE?
	//
	// Refresh command bit fields
	localparam	DDR_PREREFRESH_STALL = 24;
	localparam	DDR_NEEDREFRESH = 23;
	localparam	DDR_RFTIMER = 22;
	localparam	DDR_RFBEGIN = 21;
	//
	localparam	DDR_CMDLEN   = 21;
	localparam	DDR_CSBIT    = 20;
	localparam	DDR_RASBIT   = 19;
	localparam	DDR_CASBIT   = 18;
	localparam	DDR_WEBIT    = 17;
	localparam	DDR_NOPTIMER = 16;	// Steal this from BA bits
	localparam	DDR_BABITS   = 3;	// BABITS are really from 18:16, they are 3 bits
	localparam	DDR_ADDR_BITS = 14;
	//
	localparam	LGNROWS = 14,
			LGNBANKS= 3;
	localparam	LGFIFOLN = 3;
	localparam	FIFOLEN	 = 8;

	//
	// The commands (above) include (in this order):
	//	o_ddr_cs_n, o_ddr_ras_n, o_ddr_cas_n, o_ddr_we_n,
	//	o_ddr_dqs, o_ddr_dm, o_ddr_odt
	input	wire	i_clk,	// *MUST* be at 200 MHz for this to work
			i_reset;
	// Wishbone inputs
	input	wire		i_wb_cyc, i_wb_stb, i_wb_we;
	// The bus address needs to identify a single 128-bit word of interest
	input	wire	[AW-1:0]	i_wb_addr;
	input	wire	[DW-1:0]	i_wb_data;
	input	wire	[DW/8-1:0]	i_wb_sel;
	// Wishbone responses/outputs
	output	reg			o_wb_ack, o_wb_stall;
	output	reg	[DW-1:0]	o_wb_data;
	// DDR memory command wires
	output	reg		o_ddr_reset_n, o_ddr_cke;
	// CMDs are:
	//	 4 bits of CS, RAS, CAS, WE
	//	 3 bits of bank
	//	14 bits of Address
	//	 1 bit  of DQS (strobe active, or not)
	//	 4 bits of mask (one per byte)
	//	 1 bit  of ODT
	//	----
	//	27 bits total
	output	wire	[CMDW-1:0]	o_ddr_cmd_a, o_ddr_cmd_b, 
					o_ddr_cmd_c, o_ddr_cmd_d;
	output	reg	[DDRDW-1:0]	o_ddr_data;
	input	wire	[DDRDW-1:0]	i_ddr_data;

	integer			ik;

	////////
	//
	(* keep *) reg		reset_override, reset_ztimer,
				maintenance_override;

	////////
	//
	reg	[3:0]			reset_address;
	reg	[DDR_CMDLEN-1:0]	reset_cmd, cmd_a, cmd_b, cmd_c, cmd_d,
					refresh_cmd, maintenance_cmd;
	reg	[24:0]		reset_instruction;
	reg	[16:0]		reset_timer;

	wire	[16:0]		w_ckXPR, w_ckRFC_first;
	wire	[13:0]		w_MR0, w_MR1, w_MR2;

	////////
	//
	reg			need_refresh, pre_refresh_stall;
	reg			refresh_ztimer;
	reg	[16:0]		refresh_counter;
	reg	[2:0]		refresh_addr;
	reg	[24:0]		refresh_instruction;

	reg	[2:0]		cmd_pipe;
	reg	[1:0]		nxt_pipe;

	wire	[16:0]	w_ckREFI_left, w_ckRFC_nxt, w_wait_for_idle,
			w_pre_stall_counts;


	// Our chosen timing doesn't require any more resolution than one
	// bus clock for ODT.  (Of course, this really isn't necessary, since
	// we aren't using ODT as per the MRx registers ... but we keep it
	// around in case we change our minds later.)
	reg	[2:0]		drive_dqs;
	reg	[5:0]		dqs_pattern;
	reg	[15:0]		ddr_dm;

	reg			pipe_stall;

	// The pending transaction
	reg	[DW-1:0]	r_data;
	reg			r_pending, r_we;
	reg	[LGNROWS-1:0]	r_row;
	reg	[LGNBANKS:0]	r_bank;
	reg	[9:0]		r_col;
	reg	[DW/8-1:0]	r_sel;


	// The pending transaction, one further into the pipeline.  This is
	// the stage where the read/write command is actually given to the
	// interface if we haven't stalled.
	reg	[DW-1:0]	s_data;
	reg			s_pending, s_we;
	reg	[LGNROWS-1:0]	s_row, s_nxt_row;
	reg	[LGNBANKS-1:0]	s_bank, s_nxt_bank;
	reg	[9:0]		s_col;
	reg	[DW/8-1:0]	s_sel;

	// Can we preload the next bank?
	reg	[LGNROWS-1:0]	r_nxt_row;
	reg	[LGNBANKS-1:0]	r_nxt_bank;

	// wire	w_precharge_all;
	reg	[CKRP:0]	bank_status	[0:7];
	reg	[LGNROWS-1:0]	bank_address	[0:7];

	reg	[(LGFIFOLN-1):0]	bus_fifo_head, bus_fifo_tail;
	reg	[DW-1:0]		bus_fifo_data	[0:(FIFOLEN-1)];
	reg	[DW/8-1:0]			bus_fifo_sel	[0:(FIFOLEN-1)];
	reg				pre_ack;
	wire	w_bus_fifo_read_next_transaction;


	reg	[BUSNOW:0]	bus_active, bus_read, bus_ack;

	////////////////////////////////////////////////////////////////////////
	//
	//
	//	Reset Logic
	//
	//
	////////////////////////////////////////////////////////////////////////
	//
	//
	// Reset logic should be simple, and is given as follows:
	// note that it depends upon a ROM memory, reset_mem, and an address
	// into that memory: reset_address.  Each memory location provides
	// either a "command" to the DDR3 SDRAM, or a timer to wait until
	// the next command.  Further, the timer commands indicate whether
	// or not the command during the timer is to be set to idle, or whether
	// the command is instead left as it was.
	//
	initial	reset_override = 1'b1;
	initial	reset_address  = 4'h0;
	always @(posedge i_clk)
	if (i_reset)
	begin
		reset_override <= 1'b1;
		reset_cmd <= { DDR_NOOP, reset_instruction[16:0]};
	end else if ((reset_ztimer)&&(reset_override))
	begin
		if (reset_instruction[DDR_RSTDONE])
			reset_override <= 1'b0;
		reset_cmd <= reset_instruction[20:0];
	end

	initial	reset_ztimer = 1'b0;	// Is the timer zero?
	initial	reset_timer = 17'h02;
	always @(posedge i_clk)
	if (i_reset)
	begin
		reset_ztimer <= 1'b0;
		reset_timer  <= 17'd2;
	end else if (reset_override)
	begin
		if (!reset_ztimer)
		begin
			reset_ztimer <= (reset_timer == 17'h01);
			reset_timer  <= reset_timer - 17'h01;
		end else if (reset_instruction[DDR_RSTTIMER])
		begin
			reset_ztimer <= (reset_instruction[16:0]==0);
			reset_timer  <= reset_instruction[16:0];
		end
	end else
		reset_ztimer <= 1'b0;

		
	assign	w_MR0 = 14'h0210;
	assign	w_MR1 = 14'h0044;
	assign	w_MR2 = 14'h0040;
	assign	w_ckXPR = 17'd12;// Table 68, p186: 56 nCK / 4 sys clks= 14(-2)
	assign	w_ckRFC_first = 17'd11; // i.e. 52 nCK, or ckREFI
	always @(posedge i_clk)
	// DONE, TIMER, RESET, CKE, 
	if (i_reset)
		reset_instruction <= { 4'h4, DDR_NOOP, 17'd40_000 };
	else if (reset_ztimer) case(reset_address) // RSTDONE, TIMER, CKE, ??
	//
	// 1. Reset asserted (active low) for 200 us. (@80MHz)
	4'h0: reset_instruction <= { 4'h4, DDR_NOOP, 17'd16_000 };
	//
	// 2. Reset de-asserted, wait 500 us before asserting CKE
	4'h1: reset_instruction <= { 4'h6, DDR_NOOP, 17'd40_000 };
	//
	// 3. Assert CKE, wait minimum of Reset CKE Exit time
	4'h2: reset_instruction <= { 4'h7, DDR_NOOP, w_ckXPR };
	//
	// 4. Set MR2.  (4 nCK, no TIMER, but needs a NOOP cycle)
	4'h3: reset_instruction <= { 4'h3, DDR_MRSET, 3'h2, w_MR2 };
	//
	// 5. Set MR1.  (4 nCK, no TIMER, but needs a NOOP cycle)
	4'h4: reset_instruction <= { 4'h3, DDR_MRSET, 3'h1, w_MR1 };
	//
	// 6. Set MR0
	4'h5: reset_instruction <= { 4'h3, DDR_MRSET, 3'h0, w_MR0 };
	//
	// 7. Wait 12 nCK clocks, or 3 sys clocks
	4'h6: reset_instruction <= { 4'h7, DDR_NOOP,  17'd1 };
	//
	// 8. Issue a ZQCL command to start ZQ calibration, A10 is high
	4'h7: reset_instruction <= { 4'h3, DDR_ZQS, 6'h0, 1'b1, 10'h0};
	//
	// 9. Wait for both tDLLK and tZQinit completed, both are
	// 512 cks. Of course, since every one of these commands takes
	// two clocks, we wait for one quarter as many clocks (minus
	// two for our timer logic)
	4'h8: reset_instruction <= { 4'h7, DDR_NOOP, 17'd126 };
	//
	// 10. Precharge all command
	4'h9: reset_instruction <= { 4'h3, DDR_PRECHARGE, 6'h0, 1'b1, 10'h0 };
	//
	// 11. Wait 5 memory clocks (8 memory clocks) for the precharge
	// to complete.  A single NOOP here will have us waiting
	// 8 clocks, so we should be good here.
	4'ha: reset_instruction <= { 4'h3, DDR_NOOP, 17'd0 };
	//
	// 12. A single Auto Refresh commands
	4'hb: reset_instruction <= { 4'h3, DDR_REFRESH, 17'h00 };
	//
	// 13. Wait for the auto refresh to complete
	4'hc: reset_instruction <= { 4'h7, DDR_NOOP, w_ckRFC_first };
	4'hd: reset_instruction <= { 4'h7, DDR_NOOP, 17'd3 };
	default:
	reset_instruction <={4'hb, DDR_NOOP, 17'd00_000 };
	endcase

	initial	reset_address = 4'h0;
	always @(posedge i_clk)
	if (i_reset)
		reset_address <= 4'h0;
	else if (reset_ztimer && reset_override &&
				!reset_instruction[DDR_RSTDONE])
		reset_address <= reset_address + 4'h1;

	////////////////////////////////////////////////////////////////////////
	//
	//
	//	Refresh Logic
	//
	//
	////////////////////////////////////////////////////////////////////////
	//
	//
	//
	// Okay, let's investigate when we need to do a refresh.  Our plan
	// will be to do a single refreshes every tREFI seconds.  We will not
	// push off refreshes, nor pull them in--for simplicity.
	// tREFI = 7.8us, but it is a parameter in the number of clocks
	// 	(2496 nCK).  In our case,
	// 7.8us / 12.5ns = 624 clocks (not nCK!)
	//
	// Note that 160ns are needed between refresh commands (JEDEC, p172),
	// or 52 clocks @320MHz.  After this time, no more refreshes will be
	// needed for (2496-52) clocks (@ 320 MHz), or (624-13) clocks (@80MHz).
	//
	// This logic is very similar to the refresh logic, both use a memory
	// as a script.
	//
	initial	refresh_addr = 3'h0;
	always @(posedge i_clk)
	if (reset_override)
		refresh_addr <= 3'h0;
	else if (refresh_ztimer)
		refresh_addr <= refresh_addr + 3'h1;
	else if (refresh_instruction[DDR_RFBEGIN])
		refresh_addr <= 3'h0;

	initial	refresh_ztimer  = 1'b0;
	initial	refresh_counter = 17'd4;
	always @(posedge i_clk)
	if (reset_override)
	begin
		refresh_ztimer  <= 1'b0;
		refresh_counter <= 17'd4;
	end else if (!refresh_ztimer)
	begin
		refresh_ztimer  <= (refresh_counter == 17'h1);
		refresh_counter <= (refresh_counter - 17'h1);
	end else if (refresh_instruction[DDR_RFTIMER])
	begin
		refresh_ztimer <= (refresh_instruction[16:0] == 0);
		refresh_counter <= refresh_instruction[16:0];
	end

	// We need to wait for the bus to become idle from whatever state
	// it is in.  The difficult time for this measurement is assuming
	// a write was just given.  In that case, we need to wait for the
	// write to complete, and then to wait an additional tWR (write
	// recovery time) or 6 nCK clocks from the end of the write.  This
	// works out to seven idle bus cycles from the time of the write
	// command, or a count of 5 (7-2).
	localparam [16:0]	PRE_STALL_COUNTS = 17'd3;
	localparam [16:0]	WAIT_FOR_IDLE    = 0;
	localparam [16:0]	PRIOR_WAIT       = 13;
	localparam [16:0]	REFRESH_INTERVAL = 624;

	assign	w_ckREFI_left[16:0] = REFRESH_INTERVAL
				- PRIOR_WAIT // Minus what we've already waited
				- WAIT_FOR_IDLE
				-17'd19;
	assign	w_ckRFC_nxt[16:0] = 17'd12-17'd3;

	assign	w_wait_for_idle    = WAIT_FOR_IDLE;
	assign	w_pre_stall_counts = PRE_STALL_COUNTS;

	initial	refresh_instruction <= { 4'h2, DDR_NOOP, 17'd1 };
	always @(posedge i_clk)
	if (reset_override)
		refresh_instruction <= { 4'h2, DDR_NOOP, 17'd1 };
	else if (refresh_ztimer)
		case(refresh_addr)
		// Bit fields are:
		//	NEED-REFRESH, HAVE-TIMER, BEGIN(start-over)
		//	DDR_PREREFRESH_STALL = 24;
		// 	DDR_NEEDREFRESH = 23;
		//	DDR_RFTIMER = 22;
		//	DDR_RFBEGIN = 21;
		//	Command, 20:17
		//	timer value, 16:0
		//
		// First, a number of clocks needing no refresh
		3'h0: refresh_instruction <= { 4'h2, DDR_NOOP, w_ckREFI_left };
		// Then, we take command of the bus and wait for it to be
		// guaranteed idle
		3'h1: refresh_instruction <= { 4'ha, DDR_NOOP, w_pre_stall_counts };
		3'h2: refresh_instruction <= { 4'hc, DDR_NOOP, w_wait_for_idle };
		// Once the bus is idle, all commands complete, and a minimum
		// recovery time given, we can issue a precharge all command
		3'h3: refresh_instruction <= { 4'hc, DDR_PRECHARGE, 17'h0400 };
		// Now we need to wait tRP = 3 clocks (6 nCK)
		3'h4: refresh_instruction <= { 4'hc, DDR_NOOP, 17'h00 };
		3'h5: refresh_instruction <= { 4'hc, DDR_REFRESH, 17'h00 };
		3'h6: refresh_instruction <= { 4'he, DDR_NOOP, w_ckRFC_nxt };
		3'h7: refresh_instruction <= { 4'h2, DDR_NOOP, 17'd12 };
		// default:
			// refresh_instruction <= { 4'h1, DDR_NOOP, 17'h00 };
		endcase

	// Note that we don't need to check if (reset_override) here since
	// refresh_ztimer will always be true if (reset_override)--in other
	// words, it will be true for many, many, clocks--enough for this
	// logic to settle out.
	always @(posedge i_clk)
	if (refresh_ztimer)
		refresh_cmd <= refresh_instruction[20:0];

	always @(posedge i_clk)
	if (refresh_ztimer)
		need_refresh <= refresh_instruction[DDR_NEEDREFRESH];

	always @(posedge i_clk)
	if (refresh_ztimer)
		pre_refresh_stall <= refresh_instruction[DDR_PREREFRESH_STALL];




	////////////////////////////////////////////////////////////////////////
	//
	//
	//	Open Banks
	//
	//
	////////////////////////////////////////////////////////////////////////
	//
	//
	//
	// Let's keep track of any open banks.  There are 8 of them to keep
	// track of.
	//
	// A precharge requires 1 clocks at 80MHz to complete.
	// An activate also requires 1 clocks at 80MHz to complete.
	// By the time we log these, they will be complete.
	// Precharges are not allowed until the maximum of:
	// 	2 clocks (200 MHz) after a read command
	// 	4 clocks after a write command
	//
	//
	initial	begin
		for(ik=0; ik< (1<<LGNBANKS); ik=ik+1)
		begin
			bank_status[ik] = 0;
			bank_address[ik] = 0;
		end
	end

	always @(posedge i_clk)
	begin
		if (cmd_pipe[0])
		begin
			bank_status[s_bank] <= 1'b0;
			if (nxt_pipe[1])
				bank_status[s_nxt_bank] <= 1'b1;
		end else begin
			if (cmd_pipe[1])
				bank_status[s_bank] <= 1'b1;
			else if (nxt_pipe[1])
				bank_status[s_nxt_bank] <= 1'b1;
			if (nxt_pipe[0])
				bank_status[s_nxt_bank] <= 1'b0;
		end

		if (i_reset || maintenance_override)
		begin
			// All banks get precharged on any refresh
			// (or reset) event
			//
			for(ik = 0; ik < (1<<LGNBANKS); ik = ik+1)
				bank_status[ik] <= 0;
		end

	end

	always @(posedge i_clk)
	if (cmd_pipe[1])
		bank_address[s_bank] <= s_row;
	else if (nxt_pipe[1])
		bank_address[s_nxt_bank] <= s_nxt_row;

	////////////////////////////////////////////////////////////////////////
	//
	//
	//	Data BUS information
	//
	//
	////////////////////////////////////////////////////////////////////////
	//
	//
	// Our purpose here is to keep track of when the data bus will be
	// active.  This is separate from the FIFO which will contain the
	// data to be placed on the bus (when so placed), in that this is
	// a group of shift registers--every position has a location in
	// time, and time always moves forward.  The FIFO, on the other
	// hand, only moves forward when data moves onto the bus.
	//
	//
	initial	bus_active = 0;
	initial	bus_ack = 0;
	always @(posedge i_clk)
	begin
		bus_active[BUSNOW:0] <= { bus_active[(BUSNOW-1):0], 1'b0 };
		// Drive the d-bus?
		bus_read[BUSNOW:0]   <= { bus_read[(BUSNOW-1):0], 1'b0 };
		// Will this position on the bus get a wishbone acknowledgement?
		bus_ack[BUSNOW:0]   <= { bus_ack[(BUSNOW-1):0], 1'b0 };

		if (cmd_pipe[2]) // && !i_reset && i_wb_cyc)
		begin
			bus_active[0]<= 1'b1; // Data transfers in one clocks
			bus_ack[0] <= 1'b1;
			bus_ack[0] <= 1'b1;

			bus_read[0] <= !s_we;
		end

		if (i_reset || !i_wb_cyc)
			bus_ack <= 0;
	end

	reg	dir_stall;
	//
	//
	// Can we issue a read command?
	//
	//
	initial	{ r_pending, s_pending, pipe_stall, o_wb_stall } <= 3'b0001;
	initial	nxt_pipe = 0;
	initial	cmd_pipe = 0;
	initial	dir_stall = 0;
	always @(posedge i_clk)
	begin
		r_pending <= (i_wb_stb)&&(!o_wb_stall)
				||(r_pending)&&(pipe_stall);
		dir_stall <= (i_wb_stb && !o_wb_stall && r_pending
				&& r_we != i_wb_we);
		if (!pipe_stall && !dir_stall)
			s_pending <= r_pending;
		if (!pipe_stall && !dir_stall)
		begin
			if (r_pending)
			begin
				pipe_stall <= 1'b1;
				o_wb_stall <= i_wb_stb;
				/*
				// Won't happen.  pipe_stall = |cmd_pipe[1:0]
				if (cmd_pipe[1] && s_bank == r_bank
						&& s_row == r_row)
					cmd_pipe <= 3'b100;
				else
				*/
				if (nxt_pipe[1] && s_nxt_bank == r_bank
						&& s_nxt_row == r_row)
				begin
					cmd_pipe <= 3'b100;
					pipe_stall <= 1'b0;
					o_wb_stall <= 1'b0;
				end else if (!bank_status[r_bank][0])
					cmd_pipe <= 3'b010;
				else if (bank_address[r_bank] != r_row)
				begin
					cmd_pipe <= 3'b001; // Read in two clocks

					// The "nxt_pipe" just handled
					//   deactivating this row.
					if (nxt_pipe[0] && s_nxt_bank == r_bank)
						cmd_pipe <= 3'b010;
				end else begin
					cmd_pipe <= 3'b100; // Read now
					pipe_stall <= 1'b0;
					o_wb_stall <= 1'b0;
				end

				if (!bank_status[r_nxt_bank][0])
					nxt_pipe <= 2'b10;
				else if (bank_address[r_nxt_bank] != r_row)
					nxt_pipe <= 2'b01; // Read in two clocks
				else
					nxt_pipe <= 2'b00; // Next is ready
				if (nxt_pipe[1])
					nxt_pipe[1] <= 1'b0;
			end else begin
				cmd_pipe <= 3'b000;
				nxt_pipe <= { nxt_pipe[0], 1'b0 };
				pipe_stall <= 1'b0;
				o_wb_stall <= 1'b0;
			end
		end else begin // if (pipe_stall)
			pipe_stall <= (s_pending)&&(cmd_pipe[0]);
			if (!r_pending)
				o_wb_stall <= i_wb_stb;
			else
				o_wb_stall <= (s_pending)&&(cmd_pipe[0]);
			cmd_pipe <= { cmd_pipe[1:0], 1'b0 };

			if (cmd_pipe & nxt_pipe)
				nxt_pipe <= nxt_pipe;
			else
				nxt_pipe <= nxt_pipe << 1;
		end

		if (pre_refresh_stall)
			o_wb_stall <= 1'b1;

		if (!o_wb_stall)
		begin
			r_we   <= i_wb_we;
			r_data <= i_wb_data;
			r_row  <= i_wb_addr[23:10]; // 14 bits row address
			r_bank <= i_wb_addr[9:7];
			r_col  <= { i_wb_addr[6:0], 3'b000 }; // 10 bits Caddr
			r_sel  <= i_wb_sel;

// i_wb_addr[0] is the  8-bit      byte selector of  16-bits (ignored)
// i_wb_addr[1] is the 16-bit half-word selector of  32-bits (ignored)
// i_wb_addr[2] is the 32-bit      word selector of  64-bits (ignored)
// i_wb_addr[3] is the 64-bit long word selector of 128-bits

			// pre-emptive work
			{ r_nxt_row, r_nxt_bank }  <= i_wb_addr[23:7] + 1;
		end

		if (!pipe_stall)
		begin
			// Moving one down the pipeline
			s_we   <= r_we;
			s_data <= r_data;
			s_row  <= r_row;
			s_bank <= r_bank;
			s_col  <= r_col;
			s_sel  <= (r_we) ? (~r_sel):16'h00;

			if (r_pending)
			begin
				// pre-emptive work
				s_nxt_row  <= r_nxt_row;
				s_nxt_bank <= r_nxt_bank;
			end
		end

		if (i_reset || !i_wb_cyc)
		begin
			r_pending  <= 1'b0;
			s_pending  <= 1'b0;
			cmd_pipe   <= 0;
			nxt_pipe   <= 0;
			pipe_stall <= 0;
		end

		if (i_reset || reset_override)
			o_wb_stall <= 1'b1;
	end

	//
	//
	// Okay, let's look at the last assignment in our chain.  It should
	// look something like:
	initial	o_ddr_reset_n = 1'b0;
	always @(posedge i_clk)
	if (i_reset)
		o_ddr_reset_n <= 1'b0;
	else if (reset_ztimer)
		o_ddr_reset_n <= reset_instruction[DDR_RSTBIT];

	initial	o_ddr_cke = 1'b0;
	always @(posedge i_clk)
	if (i_reset)
		o_ddr_cke <= 1'b0;
	else if (reset_ztimer)
		o_ddr_cke <= reset_instruction[DDR_CKEBIT];

	initial	maintenance_override = 1'b1;
	always @(posedge i_clk)
	if (i_reset)
		maintenance_override <= 1'b1;
	else
		maintenance_override <= (reset_override)||(need_refresh);

	initial	maintenance_cmd = { DDR_NOOP, 17'h00 };
	always @(posedge i_clk)
	if (i_reset)
		maintenance_cmd <= { DDR_NOOP, 17'h00 };
	else
		maintenance_cmd <= (reset_override) ? reset_cmd:refresh_cmd;


	initial	cmd_a = 0;
	initial	cmd_b = 0;
	initial	cmd_c = 0;
	initial	cmd_d = 0;
	always @(posedge i_clk)
	begin
		// We run our commands by timeslots, A, B, C, and D in that
		// order.

		// Timeslot A always contains any maintenance commands we
		//	might have.
		// Timeslot B always contains any precharge command, excluding
		//	the maintenance precharge-all command.
		// Timeslot C always contains any activate command
		// Timeslot D always contains any read/write command
		//
		// We can always set these commands to whatever, to reduce the
		// used logic, as long as the top bit (CS_N) is used to select
		// whether or not the command is active.  If CS_N is 0 the
		// command will be applied by the chip, if 1 the command turns
		// into a deselect command that the chip will ignore.
		//
		cmd_a <= maintenance_cmd;

		cmd_b <= { DDR_PRECHARGE, s_nxt_bank, s_nxt_row[LGNROWS-1:11],
						1'b0, s_nxt_row[9:0] };
		cmd_b[DDR_CSBIT] <= 1'b1; // Deactivate, unless ...
		if (cmd_pipe[0])
			cmd_b <= { DDR_PRECHARGE, s_bank, s_row[LGNROWS-1:11],
					1'b0, s_row[9:0] };
		cmd_b[DDR_CSBIT] <= (!cmd_pipe[0])&&(!nxt_pipe[0]);


		//
		// 3rd position: Activate a row, either the next one,
		// or the one we currently need and are already waiting on
		//
		cmd_c <= { DDR_ACTIVATE, s_nxt_bank, s_nxt_row[LGNROWS-1:0] };
		cmd_c[DDR_CSBIT] <= 1'b1; // Disable command, unless ...

		if (cmd_pipe[1])
			cmd_c <= { DDR_ACTIVATE, s_bank, s_row[LGNROWS-1:0] };
		else if (nxt_pipe[1])
			cmd_c[DDR_CSBIT] <= 1'b0;

		//
		// 4th position: Actually issue any read/write commands
		//
		cmd_d[DDR_CSBIT:DDR_WEBIT]<= (s_we)? DDR_WRITE:DDR_READ;
		cmd_d[DDR_WEBIT-1:0] <= { s_bank, 3'h0, 1'b0, s_col };
		cmd_d[DDR_CSBIT] <= !cmd_pipe[2];


		// Now, if the maintenance mode must override whatever we are
		// doing, we only need to apply this more complicated logic
		// to the CS_N bit, or bit[20], since this will activate or
		// deactivate the rest of the command--making the rest
		// either relevant (CS_N=0) or irrelevant (CS_N=1) as we need.
		if (!i_wb_cyc)
			cmd_d[DDR_CSBIT] <= 1'b1;

		if (maintenance_override)
		begin
			cmd_a[DDR_CSBIT] <= 1'b0;
			// cmd_b[DDR_CSBIT] <= 1'b1;
			// cmd_c[DDR_CSBIT] <= 1'b1;
			// cmd_d[DDR_CSBIT] <= 1'b1;
		end else
			cmd_a[DDR_CSBIT] <= 1'b1; // Disable maintenance timeslot

		if (i_reset)
		begin
			cmd_a[DDR_CSBIT] <= 1'b1;
			cmd_b[DDR_CSBIT] <= 1'b1;
			cmd_c[DDR_CSBIT] <= 1'b1;
			cmd_d[DDR_CSBIT] <= 1'b1;
		end
	end

	// The bus R/W FIFO
	assign	w_bus_fifo_read_next_transaction = (bus_ack[BUSREG]);
	always @(posedge i_clk)
	begin
		pre_ack <= 1'b0;
		if (reset_override)
		begin
			bus_fifo_head <= {(LGFIFOLN){1'b0}};
			bus_fifo_tail <= {(LGFIFOLN){1'b0}};
		end else begin
			if ((s_pending)&&(!pipe_stall))
				bus_fifo_head <= bus_fifo_head + 1'b1;

			if (w_bus_fifo_read_next_transaction)
			begin
				bus_fifo_tail <= bus_fifo_tail + 1'b1;
				pre_ack <= 1'b1;
			end
		end
		bus_fifo_data[bus_fifo_head] <= s_data;
		bus_fifo_sel[bus_fifo_head]  <= s_sel;

		if (i_reset || !i_wb_cyc)
			pre_ack <= 0;
	end


	always @(posedge i_clk)
		o_ddr_data  <= bus_fifo_data[bus_fifo_tail];

	always @(posedge i_clk)
		ddr_dm   <= (bus_ack[BUSREG])? bus_fifo_sel[bus_fifo_tail]
			: (!bus_read[BUSREG] ? 16'hffff: 16'h0000);

	initial	drive_dqs    = 0;
	always @(posedge i_clk)
	begin
		drive_dqs[1] <= (bus_active[(BUSREG)])
			&&(!bus_read[(BUSREG)]);
		drive_dqs[0] <= (bus_active[BUSREG:(BUSREG-1)] != 2'b00)
			&&(bus_read[BUSREG:(BUSREG-1)] == 2'b00);
		//
		drive_dqs[2] <= (bus_active[(BUSREG)])&&(!bus_read[(BUSREG)])
				// Add a postamble ... if we drove DQS in the
				// last clock, then drive it now
				||drive_dqs[1];

		dqs_pattern[5:4] <= 2'b11;
		dqs_pattern[3:2] <= 2'b10;
		dqs_pattern[1:0] <= 2'b00;

		if (bus_active[BUSREG]&& !bus_read[BUSREG])
		begin
			dqs_pattern[5:4] <= 2'b10;
			dqs_pattern[1:0] <= 2'b10;
		end
	end

	// First command
	assign	o_ddr_cmd_a = {cmd_a,drive_dqs[2],ddr_dm[4*LANES-1:3*LANES],
					dqs_pattern[5:4] };
	// Second command (of four)
	assign	o_ddr_cmd_b = {cmd_b,drive_dqs[1],ddr_dm[3*LANES-1:2*LANES],
					dqs_pattern[3:2] };
	// Third command (of four)
	assign	o_ddr_cmd_c = {cmd_c,drive_dqs[1],ddr_dm[2*LANES-1:LANES],
					dqs_pattern[3:2] };
	// Fourth command (of four)--occupies the last timeslot
	assign	o_ddr_cmd_d = {cmd_d,drive_dqs[0],ddr_dm[LANES-1: 0],
					drive_dqs[1:0] };

	initial	o_wb_ack = 0;
	always @(posedge i_clk)
	if (i_reset)
		o_wb_ack <= 0;
	else
		o_wb_ack <= i_wb_cyc && pre_ack;

	always @(posedge i_clk)
		o_wb_data <= i_ddr_data;

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
/////
/////	Formal methods section
/////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
`ifdef	FORMAL
	reg	f_past_valid;

	initial	f_past_valid = 0;
	always @(posedge i_clk)
		f_past_valid <= 1;

	////////////////////////////////////////////////////////////////////////
	//
	// Bus interface(s)
	//
	localparam	F_LGDEPTH = 4;
	wire	[F_LGDEPTH-1:0]	f_nreqs, f_nacks, f_outstanding;

	localparam	F_STB = 2+AW+DW+DW/8-1;
	localparam	F_PKTCOL  = DW+DW/8;
	localparam	F_PKTBANK = F_PKTCOL + 10 - 3;
	localparam	F_PKTROW  = F_PKTBANK + LGNBANKS;
	reg	[F_STB:0]	f_rwb_packet, f_swb_packet, f_cwb_packet;
	wire	[F_STB:0]	f_iwb_packet;
	wire	[LGNROWS-1:0]	rwb_row,  swb_row,  cwb_row;
	wire	[LGNBANKS-1:0]	rwb_bank, swb_bank, cwb_bank;
	wire	[9:0]		rwb_col,  swb_col,  cwb_col;
	wire	[LGNROWS+LGNBANKS-1:0]	rwb_next, swb_next;
	(* anyconst *)	reg	[LGNBANKS-1:0]	f_const_bank;


	fwb_slave #(.AW(AW), .DW(DW),
		.F_OPT_DISCONTINUOUS(1),
		.F_OPT_RMW_BUS_OPTION(1),
		.F_OPT_MINCLOCK_DELAY(0),
		.F_LGDEPTH(F_LGDEPTH))
	fwb(i_clk, i_reset,
		i_wb_cyc, i_wb_stb, i_wb_we, i_wb_addr, i_wb_data, i_wb_sel,
			o_wb_ack, o_wb_stall, o_wb_data, 1'b0,
		f_nreqs, f_nacks, f_outstanding);

	////////////////////////////////////////////////////////////////////////
	//
	//
	//	Reset Logic
	//
	//
	////////////////////////////////////////////////////////////////////////
	//
	//
	//
	always @(*)
	if (reset_override)
		assert(reset_address <= 4'hd);
	else
		assert(reset_address == 4'he);

	always @(*)
	if (reset_timer != 0)
		assert(!reset_ztimer);
	else if (reset_override)
		assert(reset_ztimer);

	////////////////////////////////////////////////////////////////////////
	//
	//
	//	Refresh Logic
	//
	//
	////////////////////////////////////////////////////////////////////////
	//
	//
	//
	reg		f_valid_refresh_insn, f_valid_last_refresh_insn;
	reg	[2:0]	f_refresh_addr, f_last_refresh_addr;
	reg	[24:0]	f_last_refresh_insn;

	always @(*)
	begin
		f_valid_refresh_insn = 0;
		f_refresh_addr       = 0;

		if (refresh_instruction == { 4'h2, DDR_NOOP, 17'd1 })
			{ f_valid_refresh_insn, f_refresh_addr } = { 1'b1, 3'h0 };
		if (refresh_instruction == { 4'h2, DDR_NOOP, w_ckREFI_left })
			{ f_valid_refresh_insn, f_refresh_addr } = { 1'b1, 3'h0 };
		if (refresh_instruction == { 4'ha, DDR_NOOP, w_pre_stall_counts })
			{ f_valid_refresh_insn, f_refresh_addr } = { 1'b1, 3'h1 };
		if (refresh_instruction == { 4'hc, DDR_NOOP, w_wait_for_idle })
			{ f_valid_refresh_insn, f_refresh_addr } = { 1'b1, 3'h2 };
		if (refresh_instruction == { 4'hc, DDR_PRECHARGE, 17'h0400 })
			{ f_valid_refresh_insn, f_refresh_addr } = { 1'b1, 3'h3 };
		if (refresh_instruction == { 4'hc, DDR_NOOP, 17'h00 })
			{ f_valid_refresh_insn, f_refresh_addr } = { 1'b1, 3'h4 };
		if (refresh_instruction == { 4'hc, DDR_REFRESH, 17'h00 })
			{ f_valid_refresh_insn, f_refresh_addr } = { 1'b1, 3'h5 };
		if (refresh_instruction == { 4'he, DDR_NOOP, w_ckRFC_nxt })
			{ f_valid_refresh_insn, f_refresh_addr } = { 1'b1, 3'h6 };
		if (refresh_instruction == { 4'h2, DDR_NOOP, 17'd12 })
			{ f_valid_refresh_insn, f_refresh_addr } = { 1'b1, 3'h7 };

		assert(f_valid_refresh_insn);
	end

	always @(*)
	if (f_refresh_addr != 0)
		assert(refresh_addr == f_refresh_addr + 1);
	else
		assert(f_refresh_addr == 3'h0 || f_refresh_addr == 3'h7);

	always @(*)
	if (f_refresh_addr != 0 || refresh_addr != 0)
		assert(f_refresh_addr == f_last_refresh_addr);

	always @(*)
	if (refresh_addr > 3'h1)
		assert(pre_refresh_stall);

	always @(*)
	if (refresh_addr >= 3'h2)
		assert(need_refresh);

	initial	f_last_refresh_insn <= { 4'h2, DDR_NOOP, 17'd1 };
	always @(posedge i_clk)
	if (reset_override)
		f_last_refresh_insn <= { 4'h2, DDR_NOOP, 17'd1 };
	else if (refresh_ztimer)
		f_last_refresh_insn <= refresh_instruction;

	always @(*)
	begin
		f_valid_last_refresh_insn = 0;
		f_last_refresh_addr       = 0;

		if (f_last_refresh_insn == { 4'h2, DDR_NOOP, 17'd1 })
			{ f_valid_last_refresh_insn, f_last_refresh_addr } = { 1'b1, 3'h0 };
		if (f_last_refresh_insn == { 4'h2, DDR_NOOP, w_ckREFI_left })
			{ f_valid_last_refresh_insn, f_last_refresh_addr } = { 1'b1, 3'h0 };
		if (f_last_refresh_insn == { 4'ha, DDR_NOOP, w_pre_stall_counts })
			{ f_valid_last_refresh_insn, f_last_refresh_addr } = { 1'b1, 3'h1 };
		if (f_last_refresh_insn == { 4'hc, DDR_NOOP, w_wait_for_idle })
			{ f_valid_last_refresh_insn, f_last_refresh_addr } = { 1'b1, 3'h2 };
		if (f_last_refresh_insn == { 4'hc, DDR_PRECHARGE, 17'h0400 })
			{ f_valid_last_refresh_insn, f_last_refresh_addr } = { 1'b1, 3'h3 };
		if (f_last_refresh_insn == { 4'hc, DDR_NOOP, 17'h00 })
			{ f_valid_last_refresh_insn, f_last_refresh_addr } = { 1'b1, 3'h4 };
		if (f_last_refresh_insn == { 4'hc, DDR_REFRESH, 17'h00 })
			{ f_valid_last_refresh_insn, f_last_refresh_addr } = { 1'b1, 3'h5 };
		if (f_last_refresh_insn == { 4'he, DDR_NOOP, w_ckRFC_nxt })
			{ f_valid_last_refresh_insn, f_last_refresh_addr } = { 1'b1, 3'h6 };
		if (f_last_refresh_insn == { 4'h2, DDR_NOOP, 17'd12 })
			{ f_valid_last_refresh_insn, f_last_refresh_addr } = { 1'b1, 3'h7 };

		assert(f_valid_last_refresh_insn);
	end

	always @(*)
	if (!reset_override)
	begin
		assert(need_refresh == f_last_refresh_insn[DDR_NEEDREFRESH]);
		assert(pre_refresh_stall == f_last_refresh_insn[DDR_PREREFRESH_STALL]);
		if (f_last_refresh_insn[DDR_RFTIMER])
			assert(refresh_counter <= f_last_refresh_insn[16:0]);
		else
			assert(refresh_counter == 0 && refresh_ztimer);

		assert(refresh_cmd == f_last_refresh_insn[20:0]); 
	end

	////////////////////////////////////////////////////////////////////////
	//
	//
	assign	f_iwb_packet = { i_wb_stb, i_wb_we, i_wb_addr, i_wb_data, i_wb_sel };


	always @(*)
	if (i_reset)
		assume(o_wb_stall && f_outstanding == 0);

	else if (i_wb_cyc)
		assert(f_outstanding == (r_pending ? 1:0)+ (s_pending ? 1:0)
			+ (bus_ack[0] ? 1:0) + (bus_ack[1] ? 1:0)
			+ (bus_ack[2] ? 1:0)
			+ (o_wb_ack   ? 1:0));

	always @(*)
	if (reset_override)
		assert(f_outstanding == 0 && o_wb_stall);

	initial	f_rwb_packet = 0;
	always @(posedge i_clk)
	if (i_reset || !i_wb_cyc)
		f_rwb_packet <= 0;
	else if (!o_wb_stall)
		f_rwb_packet <= f_iwb_packet;
	else if (!pipe_stall)
		f_rwb_packet <= 0;

	initial	f_swb_packet = 0;
	always @(posedge i_clk)
	if (i_reset || !i_wb_cyc)
		f_swb_packet <= 0;
	else if (!pipe_stall)
		f_swb_packet <= f_rwb_packet;

	initial	f_cwb_packet = 0;
	always @(posedge i_clk)
	if (i_reset || !i_wb_cyc)
		f_cwb_packet <= 0;
	else if (!pipe_stall)
		f_cwb_packet <= f_swb_packet;
	else
		f_cwb_packet <= 0;

	//
	// Make sure the packet contents are what they should be
	//

	assign	rwb_row  =  f_rwb_packet[F_STB-2:F_PKTROW];
	assign	rwb_bank =  f_rwb_packet[F_PKTROW-1 :F_PKTBANK];
	assign	rwb_col  =  { f_rwb_packet[F_PKTBANK-1:F_PKTCOL], 3'h0 };
	assign	rwb_next =  { rwb_row, rwb_bank }+1;
	always @(*)
	if (f_rwb_packet[F_STB])
	begin
		assert(r_pending);
		assert(r_we   == f_rwb_packet[F_STB-1]);
		assert(r_row  == rwb_row);
		assert(r_bank == rwb_bank);
		assert(r_col  == rwb_col);
		assert(r_data == f_rwb_packet[DW+DW/8-1:DW/8]);
		assert(r_sel  == f_rwb_packet[DW/8-1:0]);

		assert({ r_nxt_row, r_nxt_bank } == rwb_next);
	end else
		assert(!r_pending);

	assign	swb_row  =  f_swb_packet[F_STB-2:F_PKTROW];
	assign	swb_bank =  f_swb_packet[F_PKTROW-1 :F_PKTBANK];
	assign	swb_col  =  { f_swb_packet[F_PKTBANK-1:F_PKTCOL], 3'h0 };
	assign	swb_next =  { swb_row, swb_bank }+1;
	always @(*)
	if (f_swb_packet[F_STB])
	begin
		assert(s_pending);
		assert(f_swb_packet[F_STB-1] == s_we);
		assert(s_row  == swb_row);
		assert(s_bank == swb_bank);
		assert(s_col  == swb_col);
		assert(f_swb_packet[DW+DW/8-1:DW/8] == { s_data});
		if (f_swb_packet[F_STB-1])
			assert(f_swb_packet[15:0] == ~s_sel);
		else
			assert(s_sel == 0);
		assert(cmd_pipe != 0);

		assert({ s_nxt_row, s_nxt_bank } == swb_next);
	end else
		assert(!s_pending);

	assign	cwb_row  = f_cwb_packet[F_STB-2:F_PKTROW];
	assign	cwb_bank = f_cwb_packet[F_PKTROW-1 :F_PKTBANK];
	assign	cwb_col  = { f_cwb_packet[F_PKTBANK-1:F_PKTCOL], 3'h0 };
	always @(*)
	if (f_cwb_packet[F_STB])
	begin
		if (f_cwb_packet[F_STB-1])
			// A write command
			assert(cmd_d[DDR_CSBIT:DDR_WEBIT] == DDR_WRITE);
		else
			// A read command
			assert(cmd_d[DDR_CSBIT:DDR_WEBIT] == DDR_READ);

		assert(!cmd_d[DDR_CSBIT]);
		assert(bank_status[cwb_bank]);
		assert(bank_address[cwb_bank] == cwb_row);

		assert(cmd_d[DDR_WEBIT-1:0] ==
				{cwb_bank, 3'h0, 1'b0, cwb_col });

		assert((cmd_b[DDR_CSBIT:DDR_WEBIT] != DDR_PRECHARGE)
			|| (cmd_b[DDR_WEBIT-1:DDR_WEBIT-LGNBANKS] != cwb_bank));
	end else if (f_past_valid)
		assert(cmd_d[DDR_CSBIT]);

	always @(*)
	if (!r_pending && !s_pending)
	begin
		assert(cmd_pipe == 0);
		// assert(nxt_pipe == 0);
	end

	always @(posedge i_clk)
	if (f_past_valid && !$past(i_reset))
	begin
		if ($past(f_cwb_packet[F_STB:F_STB-1] == 2'b11))
			// Following a write
			assert(drive_dqs[0]);
		else if ($past(f_cwb_packet[F_STB:F_STB-1] == 2'b10))
			// Following a read
			assert(drive_dqs[1:0] == 2'b00);
	end

	////////////////////////////////////////////////////////////////////////
	//
	//
	always @(posedge i_clk)
	if (f_past_valid && $past(bank_status[f_const_bank] != 0))
	begin
		// Can't re-activate an active bank
		assert((cmd_b[DDR_CSBIT:DDR_WEBIT] != DDR_ACTIVATE)
			||(cmd_b[DDR_WEBIT-1:DDR_WEBIT-LGNBANKS] != f_const_bank));
		assert((cmd_c[DDR_CSBIT:DDR_WEBIT] != DDR_ACTIVATE)
			||(cmd_c[DDR_WEBIT-1:DDR_WEBIT-LGNBANKS] != f_const_bank));
		assert((cmd_d[DDR_CSBIT:DDR_WEBIT] != DDR_ACTIVATE)
			||(cmd_d[DDR_WEBIT-1:DDR_WEBIT-LGNBANKS] != f_const_bank));
	end

	always @(posedge i_clk)
	// if (f_past_valid && !(&bank_status[f_const_bank]))
	if (f_past_valid && $past(!bank_status[f_const_bank]))
	begin
		// Can't de-activate an inactive bank
		assert((cmd_b[DDR_CSBIT:DDR_WEBIT] != DDR_PRECHARGE)
		      ||(cmd_b[DDR_WEBIT-1:DDR_WEBIT-LGNBANKS] != f_const_bank));
		assert((cmd_c[DDR_CSBIT:DDR_WEBIT] != DDR_PRECHARGE)
		      ||(cmd_c[DDR_WEBIT-1:DDR_WEBIT-LGNBANKS] != f_const_bank));
		assert((cmd_d[DDR_CSBIT:DDR_WEBIT] != DDR_PRECHARGE)
		      ||(cmd_d[DDR_WEBIT-1:DDR_WEBIT-LGNBANKS] != f_const_bank));

		// Can't read or write from a inactive bank
		assert(((cmd_d[DDR_CSBIT:DDR_WEBIT] != DDR_WRITE)
			&&(cmd_d[DDR_CSBIT:DDR_WEBIT] != DDR_READ))
		      ||(cmd_d[DDR_WEBIT-1:DDR_WEBIT-LGNBANKS] != f_const_bank));
	end

	////////////////////////////////////////////////////////////////////////
	//
	//
	always @(*)
	if (pipe_stall && r_pending)
		assert(o_wb_stall);

	always @(*)
		assert(pipe_stall == (|cmd_pipe[1:0]));

	
	always @(*)
		assert(refresh_ztimer == (refresh_counter == 0));

	always @(*)
	casez(cmd_pipe)
	3'b000: begin end
	3'b001: begin end
	3'b010: begin end
	3'b100: begin end
	default: assert(0);
	endcase

	always @(*)
	casez({ drive_dqs, dqs_pattern })
	// These are the good patterns
	// In their proper progression
	{ 3'b001, 6'b????00 }: begin end
	{ 3'b111, 6'b101010 }: begin end
	{ 3'b100, 6'b11???? }: begin end
	// It is possible to have an empty
	// cycle between write cycles, then
	// you'd have a drive_dqs of 101
	{ 3'b101, 6'b11??00 }: begin end
	// Don't care, 'cause nothing's driven
	{ 3'b000, 6'b?????? }: begin end
	// Everything else is disallowed
	default: assert(0);
	endcase

	always @(posedge i_clk)
	if (f_past_valid && $past(drive_dqs == 3'b001))
		assert(drive_dqs == 3'b111);

	always @(posedge i_clk)
	if (f_past_valid && $past(drive_dqs == 3'b111))
		assert(drive_dqs[2]);

	////////////////////////////////////////////////////////////////////////
	//
	//
	always @(*)
	if (r_pending && s_pending)
		assume(r_we == s_we);

	always @(*)
		assume(!need_refresh);

`endif
endmodule
