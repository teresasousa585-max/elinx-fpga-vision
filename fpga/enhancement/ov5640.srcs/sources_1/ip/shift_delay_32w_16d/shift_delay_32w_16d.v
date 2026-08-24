// =============================================================================
// 项目名称：2026 年全国大学生集成电路创新创业大赛国奖项目
// 项目作者：Ethereal
// 中文注释维护：Ethereal
// 工程分区：图像增强工程（enhancement）
// 文件名称：shift_delay_32w_16d.v
// 文件属性：厂商工具生成的 IP 封装；原始版权与许可声明在下方完整保留。
// 中文说明：封装移位寄存器 IP，为像素、系数或同步信号提供固定拍数延迟。
// 维护要求：重新生成 IP 可能覆盖中文注释；修改参数后须同步检查 QSF 引用和上层端口。
// =============================================================================
`timescale 1 ps / 1 ps
// -----------------------------------------------------------------------------
// [Ethereal注释] 正文导读：封装移位寄存器 IP，为像素、系数或同步信号提供固定拍数延迟。
// [Ethereal注释] 阅读顺序：先确认参数和端口，再沿内部信号、时序过程及子模块例化追踪数据流。
// [Ethereal注释] 修改约束：该文件为厂商 IP 封装；参数、端口或例化修改后必须重新生成并复核上层连接。
// -----------------------------------------------------------------------------
// [Ethereal注释] 模块 shift_delay_32w_16d：以下接口构成综合边界，上层通过端口连接数据流、控制流和状态信号。
module shift_delay_32w_16d (
	clock,
	shiftin,
	shiftout,
	taps);

	// [Ethereal注释] 接口信号：input 接收上游数据/控制，output 返回处理结果/状态，inout 连接双向器件总线。
	input	  clock;
	input	[31:0]  shiftin;
	output	[31:0]  shiftout;
	output	[31:0]  taps;

	// [Ethereal注释] 子模块例化 1（altshift_taps）：例化 altshift_taps 子模块，完成当前数据通路中的对应处理阶段。
	altshift_taps	ALTSHIFT_TAPS_component (
			.clock 		(clock			),
			.shiftin 	(shiftin		),
			.shiftout 	(shiftout		),
			.taps 		(taps			),
			.aclr 		(1'b0 	  		),
			.clken 		(1'b1			)
			);

// [Ethereal注释] IP 参数区：配置厂商原语的深度、宽度、寄存器级和目标器件属性。
defparam
	ALTSHIFT_TAPS_component.intended_device_family = "Stratix",
	ALTSHIFT_TAPS_component.lpm_hint = "RAM_BLOCK_TYPE=M4K",
	ALTSHIFT_TAPS_component.lpm_type = "altshift_taps",
	ALTSHIFT_TAPS_component.number_of_taps = 1,
	ALTSHIFT_TAPS_component.tap_distance = 16,
	ALTSHIFT_TAPS_component.width = 32;

endmodule

