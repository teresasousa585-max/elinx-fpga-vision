// ============================================================
// FileName: D:/jichuang_project/ov5640(1)/ov5640/ov5640.srcs/sources_1/ip/lpmmult_28_18/lpmmult_28_18.v
// Megafunction Name(s):
// 			lpm_mult
// #DSP
// ============================================================
module  lpmmult_28_18 (
	clock,
	dataa,
	datab,
	result);

	input	clock;
	input	[27:0]  dataa;
	input	[17:0]  datab;
	output	[45:0]  result;

	wire	[45:0]	sub_wire0;
	wire	[45:0]	result = sub_wire0;

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
		lpm_mult_component.lpm_pipeline = 1,
		lpm_mult_component.lpm_representation = "UNSIGNED",
		lpm_mult_component.lpm_type = "LPM_MULT",
		lpm_mult_component.lpm_widtha = 28,
		lpm_mult_component.lpm_widthb = 18,
		lpm_mult_component.lpm_widthp = 46,
		lpm_mult_component.lpm_widths = 1;
endmodule
