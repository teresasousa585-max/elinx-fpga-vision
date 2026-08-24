// synopsys translate_off
`timescale 1 ps / 1 ps
// synopsys translate_on
module fifo_async_16b (
	aclr,
	rdclk,
	wrclk,
	data,
	rdreq,
	wrreq,
	rdempty,
	rdusedw,
	wrusedw,
	q
	);

	input    aclr;
	input    rdclk;
	input    wrclk;
	input    [15:0]    data;
	input    rdreq;
	input    wrreq;
	output    [15:0]    q;
	output    rdempty;
	output    [10:0]    rdusedw;
	output    [10:0]    wrusedw;

	dcfifo    dcfifo (
		.rdclk (rdclk),
		.wrreq (wrreq),
		.aclr (aclr),
		.data (data),
		.rdreq (rdreq),
		.wrclk (wrclk),
		.wrempty (),
		.wrfull (),
		.q (q),
		.rdempty (rdempty),
		.rdfull (),
		.wrusedw (wrusedw),
		.rdusedw (rdusedw)
	);

	defparam
		dcfifo.add_ram_output_register = "ON",
		dcfifo.clocks_are_synchronized = "FALSE",
		dcfifo.intended_device_family = "Stratix",
		dcfifo.lpm_hint = "RAM_BLOCK_TYPE=M4K",
		dcfifo.lpm_numwords = 2048,
		dcfifo.lpm_showahead = "OFF",
		dcfifo.lpm_type = "dcfifo",
		dcfifo.lpm_width = 16,
		dcfifo.lpm_widthu = 11,
		dcfifo.overflow_checking = "ON",
		dcfifo.underflow_checking = "ON",
		dcfifo.use_eab = "ON";
endmodule