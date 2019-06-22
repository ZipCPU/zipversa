module	composecrc(i_clk, i_reset, i_ce, i_v, i_d, o_v, o_d, o_err);
	input	wire	i_clk, i_reset, i_ce;
	//
	input	wire		i_v;
	input	wire	[7:0]	i_d;
	//
	output	wire		o_v;
	output	wire	[7:0]	o_d;
	output	wire		o_err;
	//

	wire		txv;
	wire	[7:0]	txd;
	addecrc
	tx(i_clk, i_reset, i_ce, 1'b1, i_v, i_d, txv, txd);

	rxecrc
	rx(i_clk, i_reset, i_ce, 1'b1, txv, txd, o_v, o_d, o_err);

	////////////////////////////////////////////////////////////////////////
	//
	// The formal Contract
	//
	// If the transmitter is fed directly into the receiver,
	//	then there shall be no errors
	//
	always @(*)
		assert(!o_err);

	////////////////////////////////////////////////////////////////////////
	//
	// Induction properties
	//
	// These are necessary to prove the above contract, making certain that
	// the two cores remain in sync
	//
	reg	[31:0]	tx_crc, tx_crc0, tx_crc1, tx_crc2, tx_crc3;
	reg	[31:0]	rx_crc;

	always @(*)
		tx_crc = tx.r_crc;

	always @(*)
		rx_crc = rx.r_crc;

	always @(posedge i_clk)
	if (i_ce && i_v)
		tx_crc0 <= tx_crc;

	always @(posedge i_clk)
	if (i_ce)
	begin
		tx_crc1 <= tx_crc0;
		tx_crc2 <= tx_crc1;
		tx_crc3 <= tx_crc2;
	end

	always @(*)
	if (i_v && txv)
		assert(tx_crc0 == rx_crc);

	////////////////////////////////////////////////////////////////////////
	//
	// Our one assumption ... necessary to keep things moving
	//
	always @(posedge i_clk)
	if (!$past(i_ce) || !$past(i_ce,2))
		assume(i_ce);


	////////////////////////////////////////////////////////////////////////
	//
	// Cover properties
	//
	// Prove that it is possible to complete a packet, any packet
	//
	always @(posedge i_clk)
	if (!$past(i_reset))
		cover($fell(o_v));

endmodule
