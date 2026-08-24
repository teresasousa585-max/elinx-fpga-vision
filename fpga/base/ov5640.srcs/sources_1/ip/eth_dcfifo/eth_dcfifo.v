// =============================================================================
// 项目名称：2026 年全国大学生集成电路创新创业大赛国奖项目
// 项目作者：Ethereal
// 中文注释维护：Ethereal
// 工程分区：基础图像处理工程（base）
// 文件名称：eth_dcfifo.v
// 文件属性：厂商工具生成的 IP 封装；原始版权与许可声明在下方完整保留。
// 中文说明：封装 FIFO IP，在数据通路中完成缓存、速率匹配或跨时钟域传输。
// 维护要求：重新生成 IP 可能覆盖中文注释；修改参数后须同步检查 QSF 引用和上层端口。
// =============================================================================
// synopsys translate_off
`timescale 1 ps / 1 ps
// synopsys translate_on
// -----------------------------------------------------------------------------
// [Ethereal注释] 正文导读：封装 FIFO IP，在数据通路中完成缓存、速率匹配或跨时钟域传输。
// [Ethereal注释] 阅读顺序：先确认参数和端口，再沿内部信号、时序过程及子模块例化追踪数据流。
// [Ethereal注释] 修改约束：该文件为厂商 IP 封装；参数、端口或例化修改后必须重新生成并复核上层连接。
// -----------------------------------------------------------------------------
// [Ethereal注释] 模块 eth_dcfifo：以下接口构成综合边界，上层通过端口连接数据流、控制流和状态信号。
module eth_dcfifo (
	aclr,
	rdclk,
	wrclk,
	data,
	rdreq,
	wrreq,
	rdusedw,
	wrusedw,
	q
	);

	// [Ethereal注释] 接口信号：input 接收上游数据/控制，output 返回处理结果/状态，inout 连接双向器件总线。
	input    aclr;
	input    rdclk;
	input    wrclk;
	input    [7:0]    data;
	input    rdreq;
	input    wrreq;
	output    [7:0]    q;
	output    [11:0]    rdusedw;
	output    [11:0]    wrusedw;

	// [Ethereal注释] 子模块例化 1（dcfifo）：调用 FIFO 组件，完成数据缓存或跨时钟域传输。
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
		.rdempty (),
		.rdfull (),
		.wrusedw (wrusedw),
		.rdusedw (rdusedw)
	);

	// [Ethereal注释] IP 参数区：配置厂商原语的深度、宽度、寄存器级和目标器件属性。
	defparam
		dcfifo.add_ram_output_register = "ON",
		dcfifo.clocks_are_synchronized = "FALSE",
		dcfifo.intended_device_family = "Stratix",
		dcfifo.lpm_hint = "RAM_BLOCK_TYPE=M4K",
		dcfifo.lpm_numwords = 4096,
		dcfifo.lpm_showahead = "OFF",
		dcfifo.lpm_type = "dcfifo",
		dcfifo.lpm_width = 8,
		dcfifo.lpm_widthu = 12,
		dcfifo.overflow_checking = "ON",
		dcfifo.underflow_checking = "ON",
		dcfifo.use_eab = "ON";
endmodule