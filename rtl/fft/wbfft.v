`default_nettype none
//
module wbfft(i_clk, i_reset, i_wb_cyc, i_wb_stb, i_wb_we, i_wb_addr, i_wb_data,
		o_wb_stall, o_wb_ack, o_wb_data, o_int, o_CKPCE);
	localparam	[1:0]	INPUT = 2'b00,
				PROCESSING = 2'b01,
				IDLE = 2'b10;
`ifndef	FORMAL
	localparam		LGFFT = 10, CKPCE = 3;
`else
	parameter		LGFFT = 10, CKPCE = 3;
`endif
	input	wire			i_clk, i_reset;
	input	wire			i_wb_cyc, i_wb_stb, i_wb_we;
	input	wire	[LGFFT:0]	i_wb_addr;
	input	wire	[31:0]		i_wb_data;
	output	reg			o_wb_stall;
	output	reg			o_wb_ack;
	output	reg	[31:0]		o_wb_data;
	output	reg			o_int;
	output	wire	[3:0]		o_CKPCE = CKPCE;

	reg			ctrl_write, data_write;
	reg			syncd, fft_reset, fft_ce_delay, fft_ce;
	reg	[1:0]		fsm_state;
	integer			N;
	reg	[LGFFT-1:0]	wr_addr, br_addr, samples_in;
	reg	[31:0]		fft_input;
	wire	[31:0]		fft_output;
	wire			fft_sync;
	reg	[31:0]	mem	[0:(1<<LGFFT)-1];

	always @(*)
		ctrl_write = (i_wb_stb)&&(i_wb_we)&&(!i_wb_addr[LGFFT]) && !o_wb_stall;
	always @(*)
		data_write = (i_wb_stb)&&(i_wb_we)&&(i_wb_addr[LGFFT]) && !o_wb_stall && (fsm_state == INPUT);

	initial	fft_reset = 1;
	always @(posedge i_clk)
	if (i_reset)
		fft_reset <= 1'b1;
	else if (ctrl_write)
		fft_reset <= 1'b1;
	else
		fft_reset <= 1'b0;

	generate if (CKPCE <= 1)
	begin : NO_STALLING

		always @(*)
			o_wb_stall = 0;
		always @(*)
			fft_ce_delay = 0;

	end else begin : STALL_FOR_FFT
		reg	[$clog2(CKPCE)-1:0]	stall_count;
		reg	[$clog2(CKPCE)-1:0]	fft_ce_count;

		initial	o_wb_stall  = 0;
		initial	stall_count = 0;
		always @(posedge i_clk)
		if (i_reset || fft_reset)
		begin
			o_wb_stall  <= 0;
			stall_count <= 0;
		end else if (o_wb_stall)
		begin
			o_wb_stall <= (stall_count > 1);
			stall_count <= stall_count - 1;
		end else if (data_write)
		begin
			o_wb_stall <= 1;
			stall_count <= CKPCE-1;
		end

`ifdef	FORMAL
		always @(*)
		begin
			assert(o_wb_stall == (stall_count > 0));
			assert(stall_count < CKPCE);
		end
`endif

		if (CKPCE > 2)
		begin
			initial	fft_ce_count = 0;
			always @(posedge i_clk)
			if (i_reset || fft_reset)
				fft_ce_count <= 0;
			else if (fft_ce_count > 0)
				fft_ce_count <= fft_ce_count - 1;
			else if (fft_ce)
				fft_ce_count <= CKPCE-2;
	
			always @(*)
				fft_ce_delay = (fft_ce_count > 0);
		end else begin
			always @(*)
				fft_ce_delay = 0;
		end
	end endgenerate

	initial	fsm_state = INPUT;
	always @(posedge i_clk)
	if (i_reset || fft_reset)
		fsm_state <= INPUT;
	else case(fsm_state)
	INPUT: begin
		if (data_write && (&samples_in))
			fsm_state <= PROCESSING;
		end
	PROCESSING: begin
		if (fft_ce && (&wr_addr))
			fsm_state <= IDLE;
		end
	default:
		fsm_state <= IDLE;
	endcase

	initial	samples_in = 0;
	always @(posedge i_clk)
	if (i_reset || fft_reset)
		samples_in <= 0;
	else if (data_write)
		samples_in <= samples_in + 1;

	initial	fft_ce = 0;
	always @(posedge i_clk)
	if (i_reset || fft_reset)
		fft_ce <= 0;
	else if (fsm_state == INPUT)
		fft_ce <= data_write;
	else if (fsm_state == PROCESSING)
	begin
		if (CKPCE == 1)
			fft_ce <= 1;
		else if (CKPCE == 2)
			fft_ce <= !fft_ce;
		else
			fft_ce <= !fft_ce && !fft_ce_delay;
	end else
		fft_ce <= 0;

	always @(posedge i_clk)
	if (data_write)
		fft_input <= i_wb_data;

`ifdef	FORMAL
	(* anyseq *) reg	arbitrary_sync;
	(* anyseq *) reg [31:0]	arbitrary_value;

	assign	fft_sync   = arbitrary_sync;
	assign	fft_output = arbitrary_value;

	always @(*)
	if (fft_reset)
		assume(fft_sync == 0);
	else if (fsm_state != PROCESSING)
		assume(fft_sync == 0);
`else
	fftmain fft(i_clk, fft_reset, fft_ce, fft_input, fft_output, fft_sync);
`endif


	initial	syncd = 0;
	always @(posedge i_clk)
	if (fft_reset)
		syncd <= 0;
	else if (fft_sync)
		syncd <= 1'b1;

	initial	wr_addr = 0;
	always @(posedge i_clk)
	if (fft_reset || i_reset)
		wr_addr <= 0;
	else if (fft_ce)
	begin
		if (!fft_sync && !syncd)
			wr_addr <= 0;
		else
			wr_addr <= wr_addr + 1;
	end

	always @(*)
	for(N=0; N<LGFFT; N=N+1)
		br_addr[N] = wr_addr[LGFFT-1-N];

	always @(posedge i_clk)
	if (fft_ce && fsm_state == PROCESSING)
		mem[br_addr] <= fft_output;

	always @(posedge i_clk)
		o_wb_data <= mem[i_wb_addr[LGFFT-1:0]];

	initial	o_wb_ack = 0;
	always @(posedge i_clk)
	if (i_reset)
		o_wb_ack <= 0;
	else if (i_wb_stb && !o_wb_stall)
		o_wb_ack <= 1'b1;
	else
		o_wb_ack <= 1'b0;

	initial	o_int = 0;
	always @(posedge i_clk)
	if (i_reset || fft_reset)
		o_int <= 0;
	else if (fft_ce && (&wr_addr))
		o_int <= 1;

	// verilator lint_off UNUSED
	wire	unused;
	assign	unused = i_wb_cyc;
	// verilator lint_on UNUSED
`ifdef	FORMAL
	localparam	F_LGDEPTH = 3;
	reg	[2:0]	f_wb_nreqs, f_wb_nacks, f_wb_outstanding;

	reg	f_past_valid;
	initial	f_past_valid = 0;
	always @(posedge i_clk)
		f_past_valid <= 1;

	always @(*)
	if (!f_past_valid)
		assume(i_reset);

	fwb_slave #(.AW(LGFFT+1), .DW(32), .F_MAX_STALL(CKPCE+2),
		.F_MAX_ACK_DELAY(1), .F_LGDEPTH(F_LGDEPTH))
		fwb(i_clk, i_reset, i_wb_cyc, i_wb_stb, i_wb_we, i_wb_addr,
			i_wb_data, 4'hf, o_wb_ack, o_wb_stall, o_wb_data, 1'b0,
			f_wb_nreqs, f_wb_nacks, f_wb_outstanding);

	always @(*)
		assert(f_wb_outstanding <= 1);
	always @(*)
		assert(((i_wb_cyc && o_wb_ack)? 1:0) == (f_wb_outstanding == 1));

	generate if (CKPCE <= 1)
	begin : F_ADJACENT_FFTCE_POSS
		// Adjacent fft_ce's possible
	end else if (CKPCE == 2)
	begin : F_SINGLE_IDLE
		//
		// Only ever other fft_ce possible
		//
		// One beat of rest required after every fft_ce
		always @(posedge i_clk)
		if (f_past_valid && !$past(i_reset | fft_reset)
				&& $past(fft_ce))
			assert(!fft_ce);

	end else if (CKPCE == 3)
	begin : F_TWO_IDLES

		always @(posedge i_clk)
		if (f_past_valid && !$past(i_reset | fft_reset)
				&& $past(fft_ce))
			assert(!fft_ce);

		always @(posedge i_clk)
		if (f_past_valid && $past(f_past_valid)
				&& !$past(i_reset | fft_reset)
				&& !$past(i_reset | fft_reset, 2)
				&& $past(fft_ce,2))
			assert(!fft_ce);

	end endgenerate

	always @(*)
		cover(o_int);

	always @(*)
		assert(fsm_state != 2'b11);

	always @(*)
	if (fsm_state != INPUT)
		assert(samples_in == 0);

	always @(posedge i_clk)
		cover(fsm_state == IDLE);

	always @(posedge i_clk)
		cover(f_past_valid && $fell(o_int));

`endif
endmodule
