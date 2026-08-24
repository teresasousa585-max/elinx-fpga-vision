// =============================================================================
// 项目名称：2026 年全国大学生集成电路创新创业大赛国奖项目
// 工程分区：图像增强工程（enhancement）
// 文件名称：rgb2ycbcr.v
// 主要模块：rgb2ycbcr
// 功能分类：颜色空间转换
// 功能说明：以流水线方式完成 RGB 到 YCbCr 的定点转换，同时延迟原始 RGB 旁路以保持时序一致。
// 输入概述：像素数据及 HS/VS/DE 视频同步信号；控制参数由模式或模块参数给出。
// 输出概述：处理后的像素流，以及与流水线延迟严格匹配的 HS/VS/DE 信号。
// 时序约束：像素数据在视频像素时钟上升沿处理；复位极性以模块端口定义为准。
// 关联文件：RGB_to_YCbCr.v、histogram_equalization.v、hdr_tone_mapping_color.v
// 维护要求：修改端口、位宽、流水线延迟或模式编码时，必须同步更新上层例化与项目文档。
// =============================================================================
`timescale 1ns / 1ps

module rgb2ycbcr (
    input wire clk,
    input wire rst,  // 高电平同步复位

    // 上游输入 (原始时序与数据)
    input wire        i_hs,
    input wire        i_vs,
    input wire        i_de,
    input wire [23:0] i_rgb,

    // 下游输出 (对齐的 3 拍后时序与数据)
    output reg        o_hs,
    output reg        o_vs,
    output reg        o_de,
    output reg [23:0] o_ycbcr,   // {Y, Cb, Cr}
    output reg [23:0] o_raw_rgb  // 延迟对齐后的原图 (给 VGA)
);

  // 拆分输入的 RGB
  wire [7:0] r8 = i_rgb[23:16];
  wire [7:0] g8 = i_rgb[15:8];
  wire [7:0] b8 = i_rgb[7:0];

  // 第 1 级流水线：乘法运算
  reg [15:0] mult_r_y, mult_g_y, mult_b_y;
  reg [15:0] mult_r_cb, mult_g_cb, mult_b_cb;
  reg [15:0] mult_r_cr, mult_g_cr, mult_b_cr;

  // 同步信号打拍 (延迟线 1)
  reg hs_d1, vs_d1, de_d1;
  reg [23:0] raw_rgb_d1;

  always @(posedge clk) begin
    if (rst) begin
      {hs_d1, vs_d1, de_d1, raw_rgb_d1} <= 0;
      mult_r_y <= 0;
      mult_g_y <= 0;
      mult_b_y <= 0;
      mult_r_cb <= 0;
      mult_g_cb <= 0;
      mult_b_cb <= 0;
      mult_r_cr <= 0;
      mult_g_cr <= 0;
      mult_b_cr <= 0;
    end else begin
      // 时序与原图伴随打拍
      hs_d1 <= i_hs;
      vs_d1 <= i_vs;
      de_d1 <= i_de;
      raw_rgb_d1 <= i_rgb;

      // Y 通道乘法
      mult_r_y <= r8 * 8'd76;
      mult_g_y <= g8 * 8'd150;
      mult_b_y <= b8 * 8'd29;
      // Cb 通道乘法
      mult_r_cb <= r8 * 8'd43;
      mult_g_cb <= g8 * 8'd85;
      mult_b_cb <= b8 * 8'd128;
      // Cr 通道乘法
      mult_r_cr <= r8 * 8'd128;
      mult_g_cr <= g8 * 8'd107;
      mult_b_cr <= b8 * 8'd21;
    end
  end

  //  第 2 级流水线：加减法运算 (防止溢出，提前加上偏移量 32768)
  reg [15:0] add_y, add_cb, add_cr;

  // 同步信号打拍 (延迟线 2)
  reg hs_d2, vs_d2, de_d2;
  reg [23:0] raw_rgb_d2;

  always @(posedge clk) begin
    if (rst) begin
      {hs_d2, vs_d2, de_d2, raw_rgb_d2} <= 0;
      add_y <= 0;
      add_cb <= 0;
      add_cr <= 0;
    end else begin
      // 时序与原图伴随打拍
      hs_d2 <= hs_d1;
      vs_d2 <= vs_d1;
      de_d2 <= de_d1;
      raw_rgb_d2 <= raw_rgb_d1;

      add_y <= mult_r_y + mult_g_y + mult_b_y;
      add_cb <= mult_b_cb - mult_r_cb - mult_g_cb + 16'd32768;
      add_cr <= mult_r_cr - mult_g_cr - mult_b_cr + 16'd32768;
    end
  end

  //  第 3 级流水线：移位、限幅与同步输出

  always @(posedge clk) begin
    if (rst) begin
      {o_hs, o_vs, o_de, o_raw_rgb, o_ycbcr} <= 0;
    end else begin
      // 最后一级时序与原图透传
      o_hs <= hs_d2;
      o_vs <= vs_d2;
      o_de <= de_d2;
      o_raw_rgb <= raw_rgb_d2;

      // 右移 8 位 (直接取高 8 位即可)，并进行基础限幅保护
      o_ycbcr[23:16] <= (add_y[15:8] > 255) ? 8'd255 : add_y[15:8];  // Y
      o_ycbcr[15:8] <= (add_cb[15:8] > 255) ? 8'd255 : add_cb[15:8];  // Cb
      o_ycbcr[7:0] <= (add_cr[15:8] > 255) ? 8'd255 : add_cr[15:8];  // Cr
    end
  end

endmodule
