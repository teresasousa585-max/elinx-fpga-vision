// =============================================================================
// 文件名称：RGB_to_YCbCr.v
// 主要模块：RGB_to_YCbCr
// 功能说明：将 RGB 像素转换为 YCbCr 颜色空间。
// 维护说明：修改接口或时序时，请同步更新本文件注释和上层例化。
// =============================================================================

`timescale 1 ns / 1 ps

module RGB_to_YCbCr (
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

  always @(posedge i_clk) begin
    if (i_rst) begin
      {mult_r_77, mult_g_150, mult_b_29} <= 0;
    end else begin
      mult_r_77  <= r * 8'd77;
      mult_g_150 <= g * 8'd150;
      mult_b_29  <= b * 8'd29;
    end
  end

  always @(posedge i_clk) begin
    if (i_rst) begin
      {mult_r_43, mult_g_85, mult_b_128} <= 0;
    end else begin
      mult_r_43  <= r * 8'd43;
      mult_g_85  <= g * 8'd85;
      mult_b_128 <= b * 8'd128;
    end
  end

  always @(posedge i_clk) begin
    if (i_rst) begin
      {mult_r_128, mult_g_107, mult_b_21} <= 0;
    end else begin
      mult_r_128 <= r * 8'd128;
      mult_g_107 <= g * 8'd107;
      mult_b_21  <= b * 8'd21;
    end
  end

  always @(posedge i_clk) begin
    if (i_rst) begin
      sync_d1 <= 0;
    end else begin
      sync_d1 <= {i_hs, i_vs, i_data_en};
    end
  end

  reg [15:0] add_y, add_cb, add_cr;
  reg [2:0] sync_d2;

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
  reg [23:0] oycbcr;
  reg ohs, ovs, odata_en;

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

  assign o_hs = ohs;
  assign o_vs = ovs;
  assign o_data_en = odata_en;
  assign o_ycbcr = oycbcr;

endmodule
