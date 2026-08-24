// ============================================================
// FileName: D:/jichuang_project/elinx_2/meiyan_ip/ov5640(1)/ov5640/ov5640.srcs/sources_1/ip/lpmmult_13_13_signed/lpmmult_13_13_signed.v
// Megafunction Name(s):
// 			lpm_mult
// #DSP
// ============================================================
module  lpmmult_13_13_signed (
	clock,
	dataa,
	datab,
	result);

	input	clock;
	input	[12:0]  dataa;
	input	[12:0]  datab;
	output	[25:0]  result;

	wire	[25:0]	sub_wire0;
	wire	[25:0]	result = sub_wire0;

	lpm_mult	lpm_mult_component (
				.aclr (1'b0),
				.clken (1'b1),
				.clock (clock),
				.dataa (dataa),
				.datab (datab),
				.result (sub_wire0),
				.sum (1'b0));

	defparam
		lpm_mult_component.lpm_hint = "MAXIMIZE_SPEED=5",
		lpm_mult_component.lpm_pipeline = 2,
		lpm_mult_component.lpm_representation = "SIGNED",
		lpm_mult_component.lpm_type = "LPM_MULT",
		lpm_mult_component.lpm_widtha = 13,
		lpm_mult_component.lpm_widthb = 13,
		lpm_mult_component.lpm_widthp = 26,
		lpm_mult_component.lpm_widths = 1;
endmodule
