`timescale 1 ps / 1 ps
module shift_delay_32w_8d (
	clock,
	shiftin,
	shiftout,
	taps);

	input	  clock;
	input	[31:0]  shiftin;
	output	[31:0]  shiftout;
	output	[31:0]  taps;

	altshift_taps	ALTSHIFT_TAPS_component (
			.clock 		(clock			),
			.shiftin 	(shiftin		),
			.shiftout 	(shiftout		),
			.taps 		(taps			),
			.aclr 		(1'b0 	  		),
			.clken 		(1'b1			)
			);

defparam
	ALTSHIFT_TAPS_component.intended_device_family = "Stratix",
	ALTSHIFT_TAPS_component.lpm_hint = "RAM_BLOCK_TYPE=M4K",
	ALTSHIFT_TAPS_component.lpm_type = "altshift_taps",
	ALTSHIFT_TAPS_component.number_of_taps = 1,
	ALTSHIFT_TAPS_component.tap_distance = 8,
	ALTSHIFT_TAPS_component.width = 32;

endmodule

