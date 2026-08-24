// =============================================================================
// 项目名称：2026 年全国大学生集成电路创新创业大赛国奖项目
// 项目作者：Ethereal
// 中文注释维护：Ethereal
// 工程分区：基础图像处理工程（base）
// 文件名称：pll_sdram.v
// 文件属性：厂商工具生成的 IP 封装；原始版权与许可声明在下方完整保留。
// 中文说明：封装锁相环 IP，生成指定频率与相位关系的内部时钟。
// 维护要求：重新生成 IP 可能覆盖中文注释；修改参数后须同步检查 QSF 引用和上层端口。
// =============================================================================
//#PLL
//#N_m=1
//#M_m=30
//#locked_window_size=2
//#locked_counter=2
//#IRRAD_mode=YES
//#clk0_ali=3
//#clk1_ali=3
//#clk2_ali=3
//#clk3_ali=3
//#c0_hpc=6
//#c0_lpc=6
//#c1_hpc=6
//#c1_lpc=6
//#c2_hpc=6
//#c2_lpc=6
//#c3_hpc=6
//#c3_lpc=6
//#clk0_pha_shf_byp=false
//#clk1_pha_shf_byp=false
//#clk2_pha_shf_byp=false
//#clk3_pha_shf_byp=false
//#clk4_pha_shf_byp=false
//#C0_pha=10
//#C0_pha_8=0
//#C1_pha=4
//#C1_pha_8=6
//#C2_pha=10
//#C2_pha_8=0
//#C3_pha=10
//#C3_pha_8=0
`timescale 1 ps / 1 ps
// -----------------------------------------------------------------------------
// [Ethereal注释] 正文导读：封装锁相环 IP，生成指定频率与相位关系的内部时钟。
// [Ethereal注释] 阅读顺序：先确认参数和端口，再沿内部信号、时序过程及子模块例化追踪数据流。
// [Ethereal注释] 修改约束：该文件为厂商 IP 封装；参数、端口或例化修改后必须重新生成并复核上层连接。
// -----------------------------------------------------------------------------
// [Ethereal注释] 模块 pll_sdram：以下接口构成综合边界，上层通过端口连接数据流、控制流和状态信号。
module pll_sdram(
	areset,
	inclk0,
	c0,
	c1,
	c2,
	c3,
	locked);

	// [Ethereal注释] 接口信号：input 接收上游数据/控制，output 返回处理结果/状态，inout 连接双向器件总线。
	input	areset;
	input	inclk0;
	output	c0;
	output	c1;
	output	c2;
	output	c3;
	output	locked;
	// [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
	wire[5:0] wireC;
	// [Ethereal注释] 组合连线组 1：从 c0 开始的连续赋值随右值立即更新，不增加寄存器延迟。
	assign c0 = wireC[0];
	assign c1 = wireC[1];
	assign c2 = wireC[2];
	assign c3 = wireC[3];

	// [Ethereal注释] 子模块例化 1（altpll）：调用 PLL 原语，配置内部时钟的频率、相位和占空比。
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
	// [Ethereal注释] IP 参数区：配置厂商原语的深度、宽度、寄存器级和目标器件属性。
	defparam
		altpll_component.clk0_divide_by = 12,
		altpll_component.clk0_duty_cycle = 50,
		altpll_component.clk0_multiply_by = 30,
		altpll_component.clk0_phase_shift = "0",
		altpll_component.clk1_divide_by = 12,
		altpll_component.clk1_duty_cycle = 50,
		altpll_component.clk1_multiply_by = 30,
		altpll_component.clk1_phase_shift = "4500",
		altpll_component.clk2_divide_by = 12,
		altpll_component.clk2_duty_cycle = 50,
		altpll_component.clk2_multiply_by = 30,
		altpll_component.clk2_phase_shift = "0",
		altpll_component.clk3_divide_by = 12,
		altpll_component.clk3_duty_cycle = 50,
		altpll_component.clk3_multiply_by = 30,
		altpll_component.clk3_phase_shift = "0",
		altpll_component.clk5_divide_by = 30,
		altpll_component.clk5_duty_cycle = 50,
		altpll_component.clk5_multiply_by = 30,
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
