// =============================================================================
// 项目名称：2026 年全国大学生集成电路创新创业大赛国奖项目
// 作者：Ethereal
// 工程分区：基础图像处理工程（base）
// 文件名称：RGB_to_YCbCr.v
// 主要模块：RGB_to_YCbCr
// 功能分类：颜色空间转换
// 功能说明：将 RGB888 像素转换为 YCbCr，分离亮度与色度分量，供滤波、增强和分析算法使用。
// 输入概述：像素数据及 HS/VS/DE 视频同步信号；控制参数由模式或模块参数给出。
// 输出概述：处理后的像素流，以及与流水线延迟严格匹配的 HS/VS/DE 信号。
// 时序约束：像素数据在视频像素时钟上升沿处理；复位极性以模块端口定义为准。
// 关联文件：rgb2ycbcr.v、YCbCr_to_RGB.v
// 维护要求：修改端口、位宽、流水线延迟或模式编码时，必须同步更新上层例化与项目文档。
// =============================================================================
`timescale 1 ns / 1 ps

// -----------------------------------------------------------------------------
// 正文导读：将 RGB888 像素转换为 YCbCr，分离亮度与色度分量，供滤波、增强和分析算法使用。
// 阅读顺序：先确认参数和端口，再沿内部信号、时序过程及子模块例化追踪数据流。
// 修改约束：像素数据、有效信号和 HS/VS 必须保持同拍；跨时钟数据必须使用 FIFO 或握手。
// -----------------------------------------------------------------------------
// 模块 RGB_to_YCbCr：以下接口构成综合边界，上层通过端口连接数据流、控制流和状态信号。
module RGB_to_YCbCr (
    // 接口信号：input 接收上游数据/控制，output 返回处理结果/状态，inout 连接双向器件总线。
    input wire    i_clk,
    input wire    i_rst,
    input wire    i_hs,
    input wire    i_vs,
    input wire    i_data_en,
    input wire [23:0] i_rgb,
    output wire   o_hs,
    output wire   o_vs,
    output wire   o_data_en,
    output wire [23:0] o_ycbcr
);

  // 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  wire [7:0] r = i_rgb[23:16];
  wire [7:0] g = i_rgb[15:8];
  wire [7:0] b = i_rgb[7:0];

  // ==========================================
  // Stage 1: 并行乘法
  // ==========================================
  reg [15:0] mult_r_77, mult_g_150, mult_b_29;
  reg [15:0] mult_r_43, mult_g_85, mult_b_128;
  reg [15:0] mult_r_128, mult_g_107, mult_b_21;
  reg [2:0] sync_d1;

  // 时序过程 1：由 i_clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
  always @(posedge i_clk) begin
    if (i_rst) begin
      {mult_r_77, mult_g_150, mult_b_29} <= 0;
    end else begin
      mult_r_77  <= r * 8'd77;
      mult_g_150 <= g * 8'd150;
      mult_b_29  <= b * 8'd29;
    end
  end

  // 时序过程 2：由 i_clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
  always @(posedge i_clk) begin
    if (i_rst) begin
      {mult_r_43, mult_g_85, mult_b_128} <= 0;
    end else begin
      mult_r_43  <= r * 8'd43;
      mult_g_85  <= g * 8'd85;
      mult_b_128 <= b * 8'd128;
    end
  end

  // 时序过程 3：由 i_clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
  always @(posedge i_clk) begin
    if (i_rst) begin
      {mult_r_128, mult_g_107, mult_b_21} <= 0;
    end else begin
      mult_r_128 <= r * 8'd128;
      mult_g_107 <= g * 8'd107;
      mult_b_21  <= b * 8'd21;
    end
  end

  // 时序过程 4：由 i_clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
  always @(posedge i_clk) begin
    if (i_rst) begin
      sync_d1 <= 0;
    end else begin
      sync_d1 <= {i_hs, i_vs, i_data_en};
    end
  end

  // 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  reg [15:0] add_y, add_cb, add_cr;
  reg [2:0] sync_d2;

  // 时序过程 5：由 i_clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
  always @(posedge i_clk) begin
    if (i_rst) begin
      {add_y, add_cb, add_cr} <= 0;
      sync_d2 <= 0;
    end else begin
      add_y   <= mult_r_77 + mult_g_150 + mult_b_29;
      add_cb  <= mult_b_128 + 16'd32768 - mult_r_43 - mult_g_85;
      add_cr  <= mult_r_128 + 16'd32768 - mult_g_107 - mult_b_21;
      sync_d2 <= sync_d1;
    end
  end

  // ==========================================
  // Stage 3: 移位取高 8 位并输出
  // ==========================================
  // 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  reg [23:0] oycbcr;
  reg ohs, ovs, odata_en;

  // 时序过程 6：由 i_clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
  always @(posedge i_clk) begin
    if (i_rst) begin
      oycbcr <= 0;
      {ohs, ovs, odata_en} <= 0;
    end else begin
      oycbcr <= {add_y[15:8], add_cb[15:8], add_cr[15:8]};
      ohs <= sync_d2[2];
      ovs <= sync_d2[1];
      odata_en <= sync_d2[0];
    end
  end

  // 组合连线组 1：从 o_hs 开始的连续赋值随右值立即更新，不增加寄存器延迟。
  assign o_hs = ohs;
  assign o_vs = ovs;
  assign o_data_en = odata_en;
  assign o_ycbcr = oycbcr;

endmodule
