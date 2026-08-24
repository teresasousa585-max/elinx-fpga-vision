// =============================================================================
// 项目名称：2026 年全国大学生集成电路创新创业大赛国奖项目
// 作者：Ethereal
// 工程分区：基础图像处理工程（base）
// 文件名称：YCbCr_to_RGB.v
// 主要模块：YCbCr_to_RGB
// 功能分类：颜色空间转换
// 功能说明：将处理后的 YCbCr 像素恢复为 RGB888，并对齐原始旁路数据与视频同步信号。
// 输入概述：像素数据及 HS/VS/DE 视频同步信号；控制参数由模式或模块参数给出。
// 输出概述：处理后的像素流，以及与流水线延迟严格匹配的 HS/VS/DE 信号。
// 时序约束：像素数据在视频像素时钟上升沿处理；复位极性以模块端口定义为准。
// 关联文件：RGB_to_YCbCr.v、rgb2ycbcr.v
// 维护要求：修改端口、位宽、流水线延迟或模式编码时，必须同步更新上层例化与项目文档。
// =============================================================================
`timescale 1 ns / 1 ps

// -----------------------------------------------------------------------------
// [Ethereal注释] 正文导读：将处理后的 YCbCr 像素恢复为 RGB888，并对齐原始旁路数据与视频同步信号。
// [Ethereal注释] 阅读顺序：先确认参数和端口，再沿内部信号、时序过程及子模块例化追踪数据流。
// [Ethereal注释] 修改约束：像素数据、有效信号和 HS/VS 必须保持同拍；跨时钟数据必须使用 FIFO 或握手。
// -----------------------------------------------------------------------------
// [Ethereal注释] 模块 YCbCr_to_RGB：以下接口构成综合边界，上层通过端口连接数据流、控制流和状态信号。
module YCbCr_to_RGB (
    // [Ethereal注释] 接口信号：input 接收上游数据/控制，output 返回处理结果/状态，inout 连接双向器件总线。
    input  wire        i_clk,
    input  wire        i_rst,
    input  wire        i_hs,
    input  wire        i_vs,
    input  wire        i_data_en,
    input  wire [23:0] i_ycbcr,
    output wire        o_hs,
    output wire        o_vs,
    output wire        o_data_en,
    output wire [23:0] o_rgb
);

  // ==========================================
  // Stage 1: Cb/Cr 减去 128 偏移量，转为有符号数
  // ==========================================
  // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  reg signed [9:0] y_s, cb_s, cr_s;
  reg [2:0] sync_d1;

  // [Ethereal注释] 时序过程 1：由 i_clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
  always @(posedge i_clk) begin
    if (i_rst) begin
      {y_s, cb_s, cr_s} <= 0;
      sync_d1 <= 0;
    end else begin
      y_s <= {2'b00, i_ycbcr[23:16]};
      cb_s <= {2'b00, i_ycbcr[15:8]} - 10'sd128;
      cr_s <= {2'b00, i_ycbcr[7:0]} - 10'sd128;
      sync_d1 <= {i_hs, i_vs, i_data_en};
    end
  end

  // ==========================================
  // Stage 2: 有符号定点乘法
  // ==========================================
  // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  reg signed [19:0] mult_r_cr, mult_g_cb, mult_g_cr, mult_b_cb;
  reg signed [19:0] y_shifted;
  reg [2:0] sync_d2;

  // [Ethereal注释] 时序过程 2：由 i_clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
  always @(posedge i_clk) begin
    if (i_rst) begin
      {mult_r_cr, mult_g_cb, mult_g_cr, mult_b_cb, y_shifted} <= 0;
      sync_d2 <= 0;
    end else begin
      y_shifted <= y_s * 20'sd256;
      mult_r_cr <= cr_s * 20'sd351;
      mult_g_cb <= cb_s * 20'sd86;
      mult_g_cr <= cr_s * 20'sd179;
      mult_b_cb <= cb_s * 20'sd443;
      sync_d2   <= sync_d1;
    end
  end

  // ==========================================
  // Stage 3: 加法求和
  // ==========================================
  // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  reg signed [19:0] sum_r, sum_g, sum_b;
  reg [2:0] sync_d3;

  // [Ethereal注释] 时序过程 3：由 i_clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
  always @(posedge i_clk) begin
    if (i_rst) begin
      {sum_r, sum_g, sum_b} <= 0;
      sync_d3 <= 0;
    end else begin
      sum_r   <= y_shifted + mult_r_cr;
      sum_g   <= y_shifted - mult_g_cb - mult_g_cr;
      sum_b   <= y_shifted + mult_b_cb;
      sync_d3 <= sync_d2;
    end
  end

  // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  reg [23:0] orgb;
  reg ohs, ovs, ode;

  // ==========================================
  // Stage 4: 移位并极限钳位 (Clamp)
  // ==========================================
  // [Ethereal注释] 时序过程 4：由 i_clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
  always @(posedge i_clk) begin
    if (i_rst) begin
      orgb <= 0;
      {ohs, ovs, ode} <= 0;
    end else begin
      if (sync_d3[0] == 1'b0) begin
        orgb <= 24'd0;
      end else begin
        // 钳位 R
        if (sum_r[19]) orgb[23:16] <= 8'd0;
        else if (sum_r[19:8] > 20'sd255) orgb[23:16] <= 8'd255;
        else orgb[23:16] <= sum_r[15:8];

        // 钳位 G
        if (sum_g[19]) orgb[15:8] <= 8'd0;
        else if (sum_g[19:8] > 20'sd255) orgb[15:8] <= 8'd255;
        else orgb[15:8] <= sum_g[15:8];

        // 钳位 B
        if (sum_b[19]) orgb[7:0] <= 8'd0;
        else if (sum_b[19:8] > 20'sd255) orgb[7:0] <= 8'd255;
        else orgb[7:0] <= sum_b[15:8];
      end
      ohs <= sync_d3[2];
      ovs <= sync_d3[1];
      ode <= sync_d3[0];
    end
  end

  // [Ethereal注释] 组合连线组 1：从 o_rgb 开始的连续赋值随右值立即更新，不增加寄存器延迟。
  assign o_rgb = orgb;
  assign o_hs = ohs;
  assign o_vs = ovs;
  assign o_data_en = ode;

endmodule
