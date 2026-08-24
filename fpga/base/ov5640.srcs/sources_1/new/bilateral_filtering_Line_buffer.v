// =============================================================================
// 文件名称：bilateral_filtering_Line_buffer.v
// 主要模块：bilateral_filtering_Line_buffer
// 功能说明：缓存双边滤波所需的邻域像素行。
// 维护说明：修改接口或时序时，请同步更新本文件注释和上层例化。
// =============================================================================

`timescale 1ns / 1ps

module bilateral_filtering_Line_buffer #(
    parameter H_TOTAL = 11'd1344
) (
    input wire i_clk,
    input wire i_rst,
    input wire i_hs,
    input wire i_vs,
    input wire i_data_en,
    input wire [23:0] i_rgb_data,

    output wire [23:0] o_p11,
    o_p12,
    o_p13,
    output wire [23:0] o_p21,
    o_p22,
    o_p23,
    output wire [23:0] o_p31,
    o_p32,
    o_p33,
    output wire o_hs,
    output wire o_vs,
    output wire o_data_en
);
  // 1. 全局计数器 
  reg [10:0] s_cnt;
  reg [10:0] s_cnt_r1, s_cnt_r2;  // 寄存复制，缓解地址线扇出压力

  always @(posedge i_clk) begin
    if (i_rst) begin
      s_cnt <= 0;
    end else begin
      s_cnt <= (s_cnt == H_TOTAL - 1) ? 0 : s_cnt + 1;
    end
  end

  always @(posedge i_clk) begin
    s_cnt_r1 <= s_cnt;
    s_cnt_r2 <= s_cnt;
  end
  // 2. 数据与同步信号终极打包 (32位)
  // {5位空闲, HS, VS, DE, 24位RGB}
  wire [31:0] pack_in = {5'd0, i_hs, i_vs, i_data_en, i_rgb_data};
  wire [31:0] q1_32, q2_32;

  // LB2: 存中间行 (延迟 1 行)
  m4k_sync u_lb2 (
      .clock    (i_clk),
      .wren     (1'b1),
      .wraddress(s_cnt_r2),
      .rdaddress(s_cnt_r2),
      .data     (pack_in),
      .q        (q2_32)
  );

  // LB1: 存最老行 (延迟 2 行)
  m4k_sync u_lb1 (
      .clock    (i_clk),
      .wren     (1'b1),
      .wraddress(s_cnt_r1),
      .rdaddress(s_cnt_r1),
      .data     (q2_32),     // 直接把上一行的 32位下传
      .q        (q1_32)
  );

  reg [31:0] pack_in_d1;
  always @(posedge i_clk) begin
    pack_in_d1 <= pack_in;
  end

  // 解包出三行的 RGB 数据
  wire [23:0] row1_rgb = q1_32[23:0];  // 最老行 (上)
  wire [23:0] row2_rgb = q2_32[23:0];  // 中间行 (中)
  wire [23:0] row3_rgb = pack_in_d1[23:0];  // 当前行 (下)

  // 提取中间行 (Row 2) 的同步信号作为全局基准
  wire [ 2:0] row2_sync = q2_32[26:24];  // {hs, vs, de}
  // 4. 窗口移位
  reg [23:0] w11, w12, w13, w21, w22, w23, w31, w32, w33;
  reg [2:0] sync_shift[0:2];

  always @(posedge i_clk) begin
    if (i_rst) begin
      {w11, w12, w13, w21, w22, w23, w31, w32, w33} <= 0;
      sync_shift[0] <= 0;
      sync_shift[1] <= 0;
      sync_shift[2] <= 0;
    end else begin
      w13 <= row1_rgb;
      w12 <= w13;
      w11 <= w12;
      w23 <= row2_rgb;
      w22 <= w23;
      w21 <= w22;
      w33 <= row3_rgb;
      w32 <= w33;
      w31 <= w32;

      // 同步信号跟着中间行 (Row 2) 一起无条件移位
      sync_shift[0] <= row2_sync;
      sync_shift[1] <= sync_shift[0];
      sync_shift[2] <= sync_shift[1];
    end
  end
  // 5. 最终输出
  reg [23:0] op11, op12, op13, op21, op22, op23, op31, op32, op33;
  reg ohs, ovs, ode;

  always @(posedge i_clk) begin
    if (i_rst) begin
      {op11, op12, op13, op21, op22, op23, op31, op32, op33} <= 0;
      {ohs, ovs, ode} <= 0;
    end else begin
      if (sync_shift[1][0] == 1'b0) begin
        {op11, op12, op13, op21, op22, op23, op31, op32, op33} <= 0;
      end else begin
        {op11, op12, op13} <= {w11, w12, w13};
        {op21, op22, op23} <= {w21, w22, w23};
        {op31, op32, op33} <= {w31, w32, w33};
      end
      // 输出对应中心像素 w22 的同步信号
      ohs <= sync_shift[1][2];
      ovs <= sync_shift[1][1];
      ode <= sync_shift[1][0];
    end
  end

  assign {o_p11, o_p12, o_p13} = {op11, op12, op13};
  assign {o_p21, o_p22, o_p23} = {op21, op22, op23};
  assign {o_p31, o_p32, o_p33} = {op31, op32, op33};
  assign o_hs = ohs;
  assign o_vs = ovs;
  assign o_data_en = ode;
endmodule



