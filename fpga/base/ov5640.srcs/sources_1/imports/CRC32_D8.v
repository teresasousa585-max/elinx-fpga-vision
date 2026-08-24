// =============================================================================
// 项目名称：2026 年全国大学生集成电路创新创业大赛国奖项目
// 作者：Ethereal
// 工程分区：基础图像处理工程（base）
// 文件名称：CRC32_D8.v
// 主要模块：CRC32_D8
// 功能分类：以太网图传
// 功能说明：按字节更新以太网 CRC32，生成帧校验序列。
// 输入概述：视频/协议载荷、发送触发、PHY 管理数据及系统时钟。
// 输出概述：以太网发送数据、CRC、MDIO 控制或 PHY 初始化状态。
// 时序约束：发送状态机与 PHY 接口时钟同步；帧边界和 CRC 覆盖范围不得随意修改。
// 关联文件：UDP_Send.v
// 维护要求：修改端口、位宽、流水线延迟或模式编码时，必须同步更新上层例化与项目文档。
// =============================================================================
`timescale 1 ps / 1 ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 07-04-2025 21:12:55
// Design Name:
// Module Name: CRC32_D8
// Project Name:
// Target Devices:
// Tool Versions:
// Description:
//
// Dependencies:
//
// Revision:
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////


// -----------------------------------------------------------------------------
// 正文导读：按字节更新以太网 CRC32，生成帧校验序列。
// 阅读顺序：先确认参数和端口，再沿内部信号、时序过程及子模块例化追踪数据流。
// 修改约束：协议字段、有效脉冲和跨时钟控制必须成组更新，并与上位机及外设时序保持一致。
// -----------------------------------------------------------------------------
// 模块 CRC32_D8：以下接口构成综合边界，上层通过端口连接数据流、控制流和状态信号。
module CRC32_D8 (
    Clk,
    Reset,
    Data_in,
    Enable,
    Crc,
    CrcNext,
    Crc_eth
);

  // 参数配置：综合期确定位宽、容量、频率或算法强度，修改后需重新验证资源和时序。
  parameter Tp = 1;

  // 接口信号：input 接收上游数据/控制，output 返回处理结果/状态，inout 连接双向器件总线。
  input Clk;
  input Reset;
  input [7:0] Data_in;
  input Enable;

  output reg [31:0] Crc;

  output [31:0] Crc_eth;

  output [31:0] CrcNext;

  // 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  wire [7:0] Data;

  // 组合连线组 1：从 Data 开始的连续赋值随右值立即更新，不增加寄存器延迟。
  assign Data = {
    Data_in[0], Data_in[1], Data_in[2], Data_in[3], Data_in[4], Data_in[5], Data_in[6], Data_in[7]
  };

  // 组合连线组 1：从 CrcNext[0] 开始的连续赋值随右值立即更新，不增加寄存器延迟。
  assign CrcNext[0] = Crc[24] ^ Crc[30] ^ Data[0] ^ Data[6];
  assign CrcNext[1] = Crc[24] ^ Crc[25] ^ Crc[30] ^ Crc[31] ^ Data[0] ^ Data[1] ^ Data[6] ^ Data[7];
  assign CrcNext[2] = Crc[24] ^ Crc[25] ^ Crc[26] ^ Crc[30] ^ Crc[31] ^ Data[0] ^ Data[1] ^ Data[2] ^ Data[6] ^ Data[7];
  assign CrcNext[3] = Crc[25] ^ Crc[26] ^ Crc[27] ^ Crc[31] ^ Data[1] ^ Data[2] ^ Data[3] ^ Data[7];
  assign CrcNext[4] = Crc[24] ^ Crc[26] ^ Crc[27] ^ Crc[28] ^ Crc[30] ^ Data[0] ^ Data[2] ^ Data[3] ^ Data[4] ^ Data[6];
  assign CrcNext[5] = Crc[24] ^ Crc[25] ^ Crc[27] ^ Crc[28] ^ Crc[29] ^ Crc[30] ^ Crc[31] ^ Data[0] ^ Data[1] ^ Data[3] ^ Data[4] ^ Data[5] ^ Data[6] ^ Data[7];
  assign CrcNext[6] = Crc[25] ^ Crc[26] ^ Crc[28] ^ Crc[29] ^ Crc[30] ^ Crc[31] ^ Data[1] ^ Data[2] ^ Data[4] ^ Data[5] ^ Data[6] ^ Data[7];
  assign CrcNext[7] = Crc[24] ^ Crc[26] ^ Crc[27] ^ Crc[29] ^ Crc[31] ^ Data[0] ^ Data[2] ^ Data[3] ^ Data[5] ^ Data[7];
  assign CrcNext[8] = Crc[0] ^ Crc[24] ^ Crc[25] ^ Crc[27] ^ Crc[28] ^ Data[0] ^ Data[1] ^ Data[3] ^ Data[4];
  assign CrcNext[9] = Crc[1] ^ Crc[25] ^ Crc[26] ^ Crc[28] ^ Crc[29] ^ Data[1] ^ Data[2] ^ Data[4] ^ Data[5];
  assign CrcNext[10] = Crc[2] ^ Crc[24] ^ Crc[26] ^ Crc[27] ^ Crc[29] ^ Data[0] ^ Data[2] ^ Data[3] ^ Data[5];
  assign CrcNext[11] = Crc[3] ^ Crc[24] ^ Crc[25] ^ Crc[27] ^ Crc[28] ^ Data[0] ^ Data[1] ^ Data[3] ^ Data[4];
  assign CrcNext[12] = Crc[4] ^ Crc[24] ^ Crc[25] ^ Crc[26] ^ Crc[28] ^ Crc[29] ^ Crc[30] ^ Data[0] ^ Data[1] ^ Data[2] ^ Data[4] ^ Data[5] ^ Data[6];
  assign CrcNext[13] = Crc[5] ^ Crc[25] ^ Crc[26] ^ Crc[27] ^ Crc[29] ^ Crc[30] ^ Crc[31] ^ Data[1] ^ Data[2] ^ Data[3] ^ Data[5] ^ Data[6] ^ Data[7];
  assign CrcNext[14] = Crc[6] ^ Crc[26] ^ Crc[27] ^ Crc[28] ^ Crc[30] ^ Crc[31] ^ Data[2] ^ Data[3] ^ Data[4] ^ Data[6] ^ Data[7];
  assign CrcNext[15] =  Crc[7] ^ Crc[27] ^ Crc[28] ^ Crc[29] ^ Crc[31] ^ Data[3] ^ Data[4] ^ Data[5] ^ Data[7];
  assign CrcNext[16] = Crc[8] ^ Crc[24] ^ Crc[28] ^ Crc[29] ^ Data[0] ^ Data[4] ^ Data[5];
  assign CrcNext[17] = Crc[9] ^ Crc[25] ^ Crc[29] ^ Crc[30] ^ Data[1] ^ Data[5] ^ Data[6];
  assign CrcNext[18] = Crc[10] ^ Crc[26] ^ Crc[30] ^ Crc[31] ^ Data[2] ^ Data[6] ^ Data[7];
  assign CrcNext[19] = Crc[11] ^ Crc[27] ^ Crc[31] ^ Data[3] ^ Data[7];
  assign CrcNext[20] = Crc[12] ^ Crc[28] ^ Data[4];
  assign CrcNext[21] = Crc[13] ^ Crc[29] ^ Data[5];
  assign CrcNext[22] = Crc[14] ^ Crc[24] ^ Data[0];
  assign CrcNext[23] = Crc[15] ^ Crc[24] ^ Crc[25] ^ Crc[30] ^ Data[0] ^ Data[1] ^ Data[6];
  assign CrcNext[24] = Crc[16] ^ Crc[25] ^ Crc[26] ^ Crc[31] ^ Data[1] ^ Data[2] ^ Data[7];
  assign CrcNext[25] = Crc[17] ^ Crc[26] ^ Crc[27] ^ Data[2] ^ Data[3];
  assign CrcNext[26] = Crc[18] ^ Crc[24] ^ Crc[27] ^ Crc[28] ^ Crc[30] ^ Data[0] ^ Data[3] ^ Data[4] ^ Data[6];
  assign CrcNext[27] = Crc[19] ^ Crc[25] ^ Crc[28] ^ Crc[29] ^ Crc[31] ^ Data[1] ^ Data[4] ^ Data[5] ^ Data[7];
  assign CrcNext[28] = Crc[20] ^ Crc[26] ^ Crc[29] ^ Crc[30] ^ Data[2] ^ Data[5] ^ Data[6];
  assign CrcNext[29] = Crc[21] ^ Crc[27] ^ Crc[30] ^ Crc[31] ^ Data[3] ^ Data[6] ^ Data[7];
  assign CrcNext[30] = Crc[22] ^ Crc[28] ^ Crc[31] ^ Data[4] ^ Data[7];
  assign CrcNext[31] = Crc[23] ^ Crc[29] ^ Data[5];

  // 时序过程 1：由 Clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
  always @(posedge Clk)
    if (!Reset) Crc <= {32{1'b1}};
    else if (Enable) Crc <= #1 CrcNext;

  // 组合连线组 1：从 Crc_eth 开始的连续赋值随右值立即更新，不增加寄存器延迟。
  assign Crc_eth = ~{
						CrcNext[24], CrcNext[25], CrcNext[26], CrcNext[27],CrcNext[28], CrcNext[29], CrcNext[30], CrcNext[31],
						Crc[16], Crc[17], Crc[18], Crc[19],Crc[20], Crc[21], Crc[22], Crc[23],
						Crc[ 8], Crc[ 9], Crc[10], Crc[11],Crc[12], Crc[13], Crc[14], Crc[15],
						Crc[ 0], Crc[ 1], Crc[ 2], Crc[ 3],Crc[ 4], Crc[ 5], Crc[ 6], Crc[ 7]};

endmodule
