// =============================================================================
// 文件名称：YCbCr_to_RGB.v
// 主要模块：YCbCr_to_RGB
// 功能说明：将 YCbCr 像素转换为 RGB 颜色空间。
// 维护说明：修改接口或时序时，请同步更新本文件注释和上层例化。
// =============================================================================

`timescale 1 ns / 1 ps

module YCbCr_to_RGB (
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
  reg signed [9:0] y_s, cb_s, cr_s;
  reg [2:0] sync_d1;

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
  reg signed [19:0] mult_r_cr, mult_g_cb, mult_g_cr, mult_b_cb;
  reg signed [19:0] y_shifted;
  reg [2:0] sync_d2;

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
  reg signed [19:0] sum_r, sum_g, sum_b;
  reg [2:0] sync_d3;

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

  reg [23:0] orgb;
  reg ohs, ovs, ode;

  // ==========================================
  // Stage 4: 移位并极限钳位 (Clamp)
  // ==========================================
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

  assign o_rgb = orgb;
  assign o_hs = ohs;
  assign o_vs = ovs;
  assign o_data_en = ode;

endmodule
