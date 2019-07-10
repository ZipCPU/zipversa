module wb_picorv32 #(
	parameter [ 0:0] ENABLE_COUNTERS = 1,
	parameter [ 0:0] ENABLE_COUNTERS64 = 1,
	parameter [ 0:0] ENABLE_REGS_16_31 = 1,
	parameter [ 0:0] ENABLE_REGS_DUALPORT = 1,
	parameter [ 0:0] TWO_STAGE_SHIFT = 1,
	parameter [ 0:0] BARREL_SHIFTER = 0,
	parameter [ 0:0] TWO_CYCLE_COMPARE = 0,
	parameter [ 0:0] TWO_CYCLE_ALU = 0,
	parameter [ 0:0] COMPRESSED_ISA = 1,
	parameter [ 0:0] CATCH_MISALIGN = 1,
	parameter [ 0:0] CATCH_ILLINSN = 1,
	parameter [ 0:0] ENABLE_PCPI = 0,
	parameter [ 0:0] ENABLE_MUL = 0,
	parameter [ 0:0] ENABLE_FAST_MUL = 0,
	parameter [ 0:0] ENABLE_DIV = 0,
	parameter [ 0:0] ENABLE_IRQ = 1,
	parameter [ 0:0] ENABLE_IRQ_QREGS = 1,
	parameter [ 0:0] ENABLE_IRQ_TIMER = 1,
	parameter [ 0:0] ENABLE_TRACE = 0,
	parameter [ 0:0] REGS_INIT_ZERO = 0,
	parameter [31:0] MASKED_IRQ = 32'h 0000_0000,
	parameter [31:0] LATCHED_IRQ = 32'h ffff_ffff,
	parameter [31:0] PROGADDR_RESET = 32'h 0000_0000,
	parameter [31:0] PROGADDR_IRQ = 32'h 0000_0010,
	parameter [31:0] STACKADDR = 32'h ffff_ffff
) (
	output wire	trap,

	// Wishbone interfaces
	input wire i_clk,
	input wire i_reset,

	output	reg		o_wb_cyc,
	output	reg		o_wb_stb,
	output	reg		o_wb_we,
	output	reg	[31:0]	o_wb_addr,
	output	reg	[31:0]	o_wb_data,
	output	reg	[3:0]	o_wb_sel,
	input	wire		i_wb_stall,
	input	wire		i_wb_ack,
	input	wire	[31:0]	i_wb_data,
	input	wire		i_wb_err,
	// IRQ interface
	input	wire	[31:0] irq
);

	// Pico Co-Processor Interface (PCPI)
	wire       	pcpi_valid;
	wire	[31:0]	pcpi_insn;
	wire	[31:0]	pcpi_rs1;
	wire	[31:0]	pcpi_rs2;
	reg		pcpi_wr;
	reg	[31:0]	pcpi_rd;
	reg		pcpi_wait;
	reg		pcpi_ready;

/*
	// Trace Interface
	output        trace_valid,
	output [35:0] trace_data,

	output mem_instr
*/
	wire		mem_instr;
	wire		mem_valid;
	wire	[31:0]	mem_addr;
	wire	[31:0]	mem_wdata;
	wire	[ 3:0]	mem_wstrb;
	reg		mem_ready;
	reg	[31:0]	mem_rdata;

	// Interrupt interfaces
	wire	[31:0]	eoi;
	reg	[31:0]	r_irq, pico_irq;

	// verilator lint_off PINMISSING
	picorv32 #(
		.ENABLE_COUNTERS     (ENABLE_COUNTERS     ),
		.ENABLE_COUNTERS64   (ENABLE_COUNTERS64   ),
		.ENABLE_REGS_16_31   (ENABLE_REGS_16_31   ),
		.ENABLE_REGS_DUALPORT(ENABLE_REGS_DUALPORT),
		.TWO_STAGE_SHIFT     (TWO_STAGE_SHIFT     ),
		.BARREL_SHIFTER      (BARREL_SHIFTER      ),
		.TWO_CYCLE_COMPARE   (TWO_CYCLE_COMPARE   ),
		.TWO_CYCLE_ALU       (TWO_CYCLE_ALU       ),
		.COMPRESSED_ISA      (COMPRESSED_ISA      ),
		.CATCH_MISALIGN      (CATCH_MISALIGN      ),
		.CATCH_ILLINSN       (CATCH_ILLINSN       ),
		.ENABLE_PCPI         (ENABLE_PCPI         ),
		.ENABLE_MUL          (ENABLE_MUL          ),
		.ENABLE_FAST_MUL     (ENABLE_FAST_MUL     ),
		.ENABLE_DIV          (ENABLE_DIV          ),
		.ENABLE_IRQ          (ENABLE_IRQ          ),
		.ENABLE_IRQ_QREGS    (ENABLE_IRQ_QREGS    ),
		.ENABLE_IRQ_TIMER    (ENABLE_IRQ_TIMER    ),
		.ENABLE_TRACE        (ENABLE_TRACE        ),
		.REGS_INIT_ZERO      (REGS_INIT_ZERO      ),
		.MASKED_IRQ          (MASKED_IRQ          ),
		.LATCHED_IRQ         (LATCHED_IRQ         ),
		.PROGADDR_RESET      (PROGADDR_RESET      ),
		.PROGADDR_IRQ        (PROGADDR_IRQ        ),
		.STACKADDR           (STACKADDR           )
	) picorv32_core (
		.clk      (i_clk     ),
		.resetn   (!i_reset),
		.trap     (trap  ),

		.mem_valid(mem_valid),
		.mem_addr (mem_addr ),
		.mem_wdata(mem_wdata),
		.mem_wstrb(mem_wstrb),
		.mem_instr(mem_instr),	// This is an instruction request
		.mem_ready(mem_ready),
		.mem_rdata(mem_rdata),

		.pcpi_valid(pcpi_valid),
		.pcpi_insn (pcpi_insn ),
		.pcpi_rs1  (pcpi_rs1  ),
		.pcpi_rs2  (pcpi_rs2  ),
		.pcpi_wr   (pcpi_wr   ),
		.pcpi_rd   (pcpi_rd   ),
		.pcpi_wait (pcpi_wait ),
		.pcpi_ready(pcpi_ready),

		.irq(r_irq),
		.eoi(eoi)
	);
	// verilator lint_on PINMISSING

	reg	last_valid;
	always @(posedge i_clk)
	if (i_reset)
		last_valid <= 0;
	else if (mem_valid)
		last_valid <= 1;

	always @(posedge i_clk)
	if (i_reset)
	begin
		o_wb_cyc <= 0;
		o_wb_stb <= 0;
	end else if (o_wb_cyc)
	begin
		if (!i_wb_stall)
			o_wb_stb <= 0;

		if (i_wb_ack || i_wb_err)
			o_wb_cyc <= 0;
	end else if (mem_valid && !last_valid)
	begin
		o_wb_cyc <= 1;
		o_wb_stb <= 1;
	end

	always @(posedge i_clk)
	if (!o_wb_cyc)
	begin
		o_wb_addr <= mem_addr;
		o_wb_sel  <= mem_wstrb;
		o_wb_data <= mem_wdata;
		o_wb_we   <= |mem_wstrb;
	end

	always @(*)
		mem_ready = i_wb_ack;
	always @(*)
		mem_rdata = i_wb_data;

	//
	// Disable the PCPI interface
	always @(*)
	begin
		pcpi_wr    = 0;
		pcpi_rd    = 32'bx;
		pcpi_wait  = 0;
		pcpi_ready = 0;
	end

	always @(*)
	begin
		pico_irq = irq;
		pico_irq[2] = i_wb_err;
	end

	initial	r_irq = 0;
	always @(posedge i_clk)
	if (i_reset)
		r_irq <= 0;
	else
		r_irq <= (r_irq & eoi) | pico_irq;

	// Verilator lint_off UNUSED
	wire	unused;
	assign	unused = &{ 1'b0, mem_instr, pcpi_valid, pcpi_insn, pcpi_rs1, pcpi_rs2 };
endmodule
