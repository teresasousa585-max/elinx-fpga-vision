// =============================================================================
// 项目名称：2026 年全国大学生集成电路创新创业大赛国奖项目
// 工程分区：图像增强工程（enhancement）
// 文件名称：pll_sdram.v
// 主要模块：pll_sdram
// 功能分类：时钟管理
// 功能说明：由参考时钟生成 SDRAM 控制器及相位补偿所需时钟。
// 输入概述：板级参考时钟与复位。
// 输出概述：系统各功能域所需时钟及锁定状态。
// 时序约束：生成时钟的频率和相位必须与 SDRAM、摄像头及显示接口约束一致。
// 关联文件：sdram_top.v、top.v
// 维护要求：修改端口、位宽、流水线延迟或模式编码时，必须同步更新上层例化与项目文档。
// =============================================================================
//#PLL
//#N_m=1
//#M_m=24
//#locked_window_size=2
//#locked_counter=2
//#IRRAD_mode=YES
//#clk0_ali=2
//#clk1_ali=2
//#clk2_ali=6
//#clk3_ali=6
//#c0_hpc=6
//#c0_lpc=6
//#c1_hpc=6
//#c1_lpc=6
//#c2_hpc=15
//#c2_lpc=15
//#c3_hpc=15
//#c3_lpc=15
//#clk0_pha_shf_byp=false
//#clk1_pha_shf_byp=false
//#clk2_pha_shf_byp=false
//#clk3_pha_shf_byp=false
//#clk4_pha_shf_byp=false
//#C0_pha=10
//#C0_pha_8=0
//#C1_pha=3
//#C1_pha_8=0
//#C2_pha=28
//#C2_pha_8=0
//#C3_pha=13
//#C3_pha_8=0
`timescale 1 ps / 1 ps
module pll_sdram(
	areset,
	inclk0,
	c0,
	c1,
	c2,
	c3,
	locked);

	input	areset;
	input	inclk0;
	output	c0;
	output	c1;
	output	c2;
	output	c3;
	output	locked;
	wire[5:0] wireC;
	assign c0 = wireC[0];
	assign c1 = wireC[1];
	assign c2 = wireC[2];
	assign c3 = wireC[3];

	altpll	altpll_component (
				.inclk ({1'h0, inclk0}),
				.pllena (1'b1),
				.pfdena (1'b1),
				.areset (areset),
				.clk (wireC),
				.locked (locked),
				.extclk (),
				.activeclock (),
				.clkbad (),
				.clkena ({6{1'b1}}),
				.clkloss (),
				.clkswitch (1'b0),
				.configupdate (1'b1),
				.enable0 (),
				.enable1 (),
				.extclkena ({4{1'b1}}),
				.fbin (1'b1),
				.fbout (),
				.phasecounterselect ({4{1'b1}}),
				.phasedone (),
				.phasestep (1'b1),
				.phaseupdown (1'b1),
				.scanaclr (1'b0),
				.scanclk (1'b0),
				.scanclkena (1'b1),
				.scandata (1'b0),
				.scandataout (),
				.scandone (),
				.scanread (1'b0),
				.scanwrite (1'b0),
				.sclkout0 (),
				.sclkout1 (),
				.vcooverrange (),
				.vcounderrange ());
	defparam
		altpll_component.clk0_divide_by = 12,
		altpll_component.clk0_duty_cycle = 50,
		altpll_component.clk0_multiply_by = 24,
		altpll_component.clk0_phase_shift = "0",
		altpll_component.clk1_divide_by = 12,
		altpll_component.clk1_duty_cycle = 50,
		altpll_component.clk1_multiply_by = 24,
		altpll_component.clk1_phase_shift = "2500",
		altpll_component.clk2_divide_by = 30,
		altpll_component.clk2_duty_cycle = 50,
		altpll_component.clk2_multiply_by = 24,
		altpll_component.clk2_phase_shift = "0",
		altpll_component.clk3_divide_by = 30,
		altpll_component.clk3_duty_cycle = 50,
		altpll_component.clk3_multiply_by = 24,
		altpll_component.clk3_phase_shift = "12500",
		altpll_component.clk5_divide_by = 24,
		altpll_component.clk5_duty_cycle = 50,
		altpll_component.clk5_multiply_by = 24,
		altpll_component.clk5_phase_shift = "0",
		altpll_component.inclk0_input_frequency = 20000,
		altpll_component.operation_mode = "NO_COMPENSATION",
		altpll_component.port_pllena = "PORT_UNUSED",
		altpll_component.port_pfdena = "PORT_UNUSED",
		altpll_component.port_areset = "PORT_USED",
		altpll_component.port_locked = "PORT_USED",
		altpll_component.invalid_lock_multiplier = 5,
		altpll_component.valid_lock_multiplier = 1,
		altpll_component.port_clk0 = "PORT_USED",
		altpll_component.port_clk1 = "PORT_USED",
		altpll_component.port_clk2 = "PORT_USED",
		altpll_component.port_clk3 = "PORT_USED",
		altpll_component.port_clk4 = "PORT_UNUSED",
		altpll_component.port_clk5 = "PORT_USED",
		altpll_component.port_extclk0 = "PORT_UNUSED",
		altpll_component.intended_device_family = "Stratix",
		altpll_component.lpm_type = "altpll",
		altpll_component.pll_type = "Enhanced",
		altpll_component.port_activeclock = "PORT_UNUSED",
		altpll_component.port_clkbad0 = "PORT_UNUSED",
		altpll_component.port_clkbad1 = "PORT_UNUSED",
		altpll_component.port_clkloss = "PORT_UNUSED",
		altpll_component.port_clkswitch = "PORT_UNUSED",
		altpll_component.port_fbin = "PORT_UNUSED",
		altpll_component.port_inclk0 = "PORT_USED",
		altpll_component.port_inclk1 = "PORT_UNUSED",
		altpll_component.port_phasecounterselect = "PORT_UNUSED",
		altpll_component.port_phasedone = "PORT_UNUSED",
		altpll_component.port_phasestep = "PORT_UNUSED",
		altpll_component.port_phaseupdown = "PORT_UNUSED",
		altpll_component.port_scanaclr = "PORT_UNUSED",
		altpll_component.port_scanclk = "PORT_UNUSED",
		altpll_component.port_scanclkena = "PORT_UNUSED",
		altpll_component.port_scandata = "PORT_UNUSED",
		altpll_component.port_scandataout = "PORT_UNUSED",
		altpll_component.port_scandone = "PORT_UNUSED",
		altpll_component.port_scanread = "PORT_UNUSED",
		altpll_component.port_scanwrite = "PORT_UNUSED",
		altpll_component.port_clkena0 = "PORT_UNUSED",
		altpll_component.port_clkena1 = "PORT_UNUSED",
		altpll_component.port_clkena2 = "PORT_UNUSED",
		altpll_component.port_clkena3 = "PORT_UNUSED",
		altpll_component.port_clkena4 = "PORT_UNUSED",
		altpll_component.port_clkena5 = "PORT_UNUSED",
		altpll_component.port_extclk1 = "PORT_UNUSED",
		altpll_component.port_extclk2 = "PORT_UNUSED",
		altpll_component.port_extclk3 = "PORT_UNUSED";


endmodule
