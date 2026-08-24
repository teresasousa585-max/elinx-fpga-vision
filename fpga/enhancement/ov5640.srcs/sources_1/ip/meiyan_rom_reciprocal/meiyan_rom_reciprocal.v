// =============================================================================
// 项目名称：2026 年全国大学生集成电路创新创业大赛国奖项目
// 项目作者：Ethereal
// 中文注释维护：Ethereal
// 工程分区：图像增强工程（enhancement）
// 文件名称：meiyan_rom_reciprocal.v
// 文件属性：厂商工具生成的 IP 封装；原始版权与许可声明在下方完整保留。
// 中文说明：封装只读存储器 IP，提供算法查找表或定点运算常量。
// 维护要求：重新生成 IP 可能覆盖中文注释；修改参数后须同步检查 QSF 引用和上层端口。
// =============================================================================
//#M4K
// -----------------------------------------------------------------------------
// [Ethereal注释] 正文导读：封装只读存储器 IP，提供算法查找表或定点运算常量。
// [Ethereal注释] 阅读顺序：先确认参数和端口，再沿内部信号、时序过程及子模块例化追踪数据流。
// [Ethereal注释] 修改约束：该文件为厂商 IP 封装；参数、端口或例化修改后必须重新生成并复核上层连接。
// -----------------------------------------------------------------------------
// [Ethereal注释] 模块 meiyan_rom_reciprocal：以下接口构成综合边界，上层通过端口连接数据流、控制流和状态信号。
module meiyan_rom_reciprocal(
address,
clock,
q);

// [Ethereal注释] 接口信号：input 接收上游数据/控制，output 返回处理结果/状态，inout 连接双向器件总线。
input	[11:0]  address;
input	  clock;
output	[17:0]  q;

// [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
wire	[17:0] sub_wire0;
wire	[17:0] q = sub_wire0 [17:0];

// [Ethereal注释] 子模块例化 1（altsyncram）：调用片上 RAM 原语，落实存储深度、端口宽度和读写模式。
altsyncram	altsyncram_component (
                .wren_a (1'b0),
                .aclr0 (1'b0),
                .clock0 (clock),
                .byteena_a (1'b1),
                .address_a (address),
                .data_a ({18{1'b1}}),
                .q_a (sub_wire0),
                .aclr1 (1'b0),
                .address_b (1'b1),
                .addressstall_a (1'b0),
                .addressstall_b (1'b0),
                .byteena_b (1'b1),
                .clock1 (1'b1),
                .clocken0 (1'b1),
                .clocken1 (1'b1),
                .clocken2 (1'b1),
                .clocken3 (1'b1),
                .data_b (1'b1),
                .eccstatus (),
                .q_b (),
                .rden_a (1'b1),
                .rden_b (1'b1),
                .wren_b (1'b0));
// [Ethereal注释] IP 参数区：配置厂商原语的深度、宽度、寄存器级和目标器件属性。
defparam
        altsyncram_component.address_aclr_a = "NONE",
        altsyncram_component.intended_device_family = "Stratix",
        altsyncram_component.lpm_hint = "ENABLE_RUNTIME_MOD=NO",
        altsyncram_component.lpm_type = "altsyncram",
        altsyncram_component.numwords_a = 4096,
        altsyncram_component.operation_mode = "ROM",
        altsyncram_component.outdata_aclr_a = "NONE",
        altsyncram_component.outdata_reg_a = "CLOCK0",
        altsyncram_component.ram_block_type = "M4K",
        altsyncram_component.widthad_a = 12,
        altsyncram_component.width_a =  18,
        altsyncram_component.width_byteena_a = 1,
        altsyncram_component.init_file = "../../../../rom_reciprocal_4096.mif";

endmodule
