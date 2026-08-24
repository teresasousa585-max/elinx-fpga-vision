// =============================================================================
// 文件名称：gray_morphology.v
// 主要模块：gray_morphology
// 功能说明：对灰度图像执行腐蚀或膨胀操作。
// 维护说明：修改接口或时序时，请同步更新本文件注释和上层例化。
// =============================================================================

`timescale 1ns / 1ps

module gray_morphology #(
    parameter H_DISP = 1024
) (
    input wire clk,
    input wire rst,

    // Configuration
    input wire mode,  // 1: Dilation (Max), 0: Erosion (Min)

    // Input Video Stream (8-bit Grayscale)
    input wire       vs_in,
    input wire       hs_in,
    input wire       de_in,
    input wire [7:0] data_in,

    // Output Video Stream
    output reg       vs_out,
    output reg       hs_out,
    output reg       de_out,
    output reg [7:0] data_out
);

  // ---------------------------------------------------------
  // 1. Line Buffers for 5x5 Window (Synchronous BRAM Inference)
  // ---------------------------------------------------------
  // Use proper synchronous BRAM inference to prevent LE explosion
  (* ramstyle = "block" *) reg [7:0] line0[0:2047];
  (* ramstyle = "block" *) reg [7:0] line1[0:2047];
  (* ramstyle = "block" *) reg [7:0] line2[0:2047];
  (* ramstyle = "block" *) reg [7:0] line3[0:2047];

  reg [11:0] wr_ptr;

  reg [7:0] row0_data;
  reg [7:0] row1_data;
  reg [7:0] row2_data;
  reg [7:0] row3_data;
  reg [7:0] row4_data;

  reg hs_d1, vs_d1, de_d1;

  always @(posedge clk) begin
    if (rst) begin
      wr_ptr <= 0;
      hs_d1  <= 0;
      vs_d1  <= 0;
      de_d1  <= 0;
    end else begin
      // Delay sync signals to match the 1-cycle BRAM read latency
      hs_d1 <= hs_in;
      vs_d1 <= vs_in;
      de_d1 <= de_in;

      // Align current pixel with the 1-cycle delayed BRAM output
      row4_data <= data_in;

      if (vs_in) begin
        wr_ptr <= 0;
      end else if (de_in) begin
        // Synchronous BRAM read
        row0_data <= line0[wr_ptr];
        row1_data <= line1[wr_ptr];
        row2_data <= line2[wr_ptr];
        row3_data <= line3[wr_ptr];

        // Write into BRAM (shifting lines forward)
        line0[wr_ptr] <= line1[wr_ptr];
        line1[wr_ptr] <= line2[wr_ptr];
        line2[wr_ptr] <= line3[wr_ptr];
        line3[wr_ptr] <= data_in;

        wr_ptr <= (wr_ptr == H_DISP - 1) ? 12'd0 : wr_ptr + 1'b1;
      end else if (!de_in && wr_ptr != 0) begin
        wr_ptr <= 0;
      end
    end
  end

  // ---------------------------------------------------------
  // 2. 5x5 Window Registers (Shift Registers)
  // ---------------------------------------------------------
  reg [7:0] p11, p12, p13, p14, p15;
  reg [7:0] p21, p22, p23, p24, p25;
  reg [7:0] p31, p32, p33, p34, p35;
  reg [7:0] p41, p42, p43, p44, p45;
  reg [7:0] p51, p52, p53, p54, p55;

  reg hs_d2, vs_d2, de_d2;

  always @(posedge clk) begin
    if (rst) begin
      {p11, p12, p13, p14, p15} <= 0;
      {p21, p22, p23, p24, p25} <= 0;
      {p31, p32, p33, p34, p35} <= 0;
      {p41, p42, p43, p44, p45} <= 0;
      {p51, p52, p53, p54, p55} <= 0;
      hs_d2 <= 0;
      vs_d2 <= 0;
      de_d2 <= 0;
    end else begin
      // Passing through the delayed sync signals
      hs_d2 <= hs_d1;
      vs_d2 <= vs_d1;
      de_d2 <= de_d1;

      if (de_d1) begin  // use de_d1 because row_data is valid after 1 cycle delay
        p15 <= row0_data;
        p14 <= p15;
        p13 <= p14;
        p12 <= p13;
        p11 <= p12;
        p25 <= row1_data;
        p24 <= p25;
        p23 <= p24;
        p22 <= p23;
        p21 <= p22;
        p35 <= row2_data;
        p34 <= p35;
        p33 <= p34;
        p32 <= p33;
        p31 <= p32;
        p45 <= row3_data;
        p44 <= p45;
        p43 <= p44;
        p42 <= p43;
        p41 <= p42;
        p55 <= row4_data;
        p54 <= p55;
        p53 <= p54;
        p52 <= p53;
        p51 <= p52;
      end
    end
  end

  // ---------------------------------------------------------
  // 3. Compare Pipeline Stage 1: Find Max/Min in rows
  // ---------------------------------------------------------
  reg [7:0] max_row1, max_row2, max_row3, max_row4, max_row5;
  reg [7:0] min_row1, min_row2, min_row3, min_row4, min_row5;
  reg hs_d3, vs_d3, de_d3;

  function [7:0] max5;
    input [7:0] a, b, c, d, e;
    reg [7:0] t1, t2, t3;
    begin
      t1   = (a > b) ? a : b;
      t2   = (c > d) ? c : d;
      t3   = (t1 > t2) ? t1 : t2;
      max5 = (t3 > e) ? t3 : e;
    end
  endfunction

  function [7:0] min5;
    input [7:0] a, b, c, d, e;
    reg [7:0] t1, t2, t3;
    begin
      t1   = (a < b) ? a : b;
      t2   = (c < d) ? c : d;
      t3   = (t1 < t2) ? t1 : t2;
      min5 = (t3 < e) ? t3 : e;
    end
  endfunction

  always @(posedge clk) begin
    if (rst) begin
      {max_row1, max_row2, max_row3, max_row4, max_row5} <= 0;
      {min_row1, min_row2, min_row3, min_row4, min_row5} <= 0;
      hs_d3 <= 0;
      vs_d3 <= 0;
      de_d3 <= 0;
    end else begin
      hs_d3 <= hs_d2;
      vs_d3 <= vs_d2;
      de_d3 <= de_d2;

      // Row maximums (valid when p* is valid, driven by de_d2)
      max_row1 <= max5(p11, p12, p13, p14, p15);
      max_row2 <= max5(p21, p22, p23, p24, p25);
      max_row3 <= max5(p31, p32, p33, p34, p35);
      max_row4 <= max5(p41, p42, p43, p44, p45);
      max_row5 <= max5(p51, p52, p53, p54, p55);

      // Row minimums
      min_row1 <= min5(p11, p12, p13, p14, p15);
      min_row2 <= min5(p21, p22, p23, p24, p25);
      min_row3 <= min5(p31, p32, p33, p34, p35);
      min_row4 <= min5(p41, p42, p43, p44, p45);
      min_row5 <= min5(p51, p52, p53, p54, p55);
    end
  end

  // ---------------------------------------------------------
  // 4. Compare Pipeline Stage 2: Final Result Selection
  // ---------------------------------------------------------
  always @(posedge clk) begin
    if (rst) begin
      hs_out   <= 0;
      vs_out   <= 0;
      de_out   <= 0;
      data_out <= 0;
    end else begin
      hs_out <= hs_d3;
      vs_out <= vs_d3;
      de_out <= de_d3;

      if (de_d3) begin
        if (mode) begin
          // Dilation = max of all
          data_out <= max5(max_row1, max_row2, max_row3, max_row4, max_row5);
        end else begin
          // Erosion = min of all
          data_out <= min5(min_row1, min_row2, min_row3, min_row4, min_row5);
        end
      end else begin
        data_out <= 0;
      end
    end
  end

endmodule
