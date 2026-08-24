// =============================================================================
// 文件名称：rgb2ycbcr.v
// 主要模块：rgb2ycbcr
// 功能说明：将 RGB 像素转换为 YCbCr 颜色空间。
// 维护说明：修改接口或时序时，请同步更新本文件注释和上层例化。
// =============================================================================

`timescale 1ns / 1ps

module rgb2ycbcr (
    input wire clk,
    input wire rst,  // �ߵ�ƽͬ����λ

    // �������� (ԭʼʱ��������)
    input wire        i_hs,
    input wire        i_vs,
    input wire        i_de,
    input wire [23:0] i_rgb,

    // ������� (����� 3 �ĺ�ʱ��������)
    output reg        o_hs,
    output reg        o_vs,
    output reg        o_de,
    output reg [23:0] o_ycbcr,   // {Y, Cb, Cr}
    output reg [23:0] o_raw_rgb  // �ӳٶ�����ԭͼ (�� VGA)
);

  // �������� RGB
  wire [7:0] r8 = i_rgb[23:16];
  wire [7:0] g8 = i_rgb[15:8];
  wire [7:0] b8 = i_rgb[7:0];

  //  �� 1 ����ˮ�ߣ��˷����� 
  reg [15:0] mult_r_y, mult_g_y, mult_b_y;
  reg [15:0] mult_r_cb, mult_g_cb, mult_b_cb;
  reg [15:0] mult_r_cr, mult_g_cr, mult_b_cr;

  // ͬ���źŴ��� (�ӳ��� 1)
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
      // ʱ����ԭͼ�������
      hs_d1 <= i_hs;
      vs_d1 <= i_vs;
      de_d1 <= i_de;
      raw_rgb_d1 <= i_rgb;

      // Y ͨ���˷�
      mult_r_y <= r8 * 8'd76;
      mult_g_y <= g8 * 8'd150;
      mult_b_y <= b8 * 8'd29;
      // Cb ͨ���˷�
      mult_r_cb <= r8 * 8'd43;
      mult_g_cb <= g8 * 8'd85;
      mult_b_cb <= b8 * 8'd128;
      // Cr ͨ���˷�
      mult_r_cr <= r8 * 8'd128;
      mult_g_cr <= g8 * 8'd107;
      mult_b_cr <= b8 * 8'd21;
    end
  end

  //  �� 2 ����ˮ�ߣ��Ӽ������� (��ֹ�������ǰ����ƫ���� 32768)
  reg [15:0] add_y, add_cb, add_cr;

  // ͬ���źŴ��� (�ӳ��� 2)
  reg hs_d2, vs_d2, de_d2;
  reg [23:0] raw_rgb_d2;

  always @(posedge clk) begin
    if (rst) begin
      {hs_d2, vs_d2, de_d2, raw_rgb_d2} <= 0;
      add_y <= 0;
      add_cb <= 0;
      add_cr <= 0;
    end else begin
      // ʱ����ԭͼ�������
      hs_d2 <= hs_d1;
      vs_d2 <= vs_d1;
      de_d2 <= de_d1;
      raw_rgb_d2 <= raw_rgb_d1;

      add_y <= mult_r_y + mult_g_y + mult_b_y;
      add_cb <= mult_b_cb - mult_r_cb - mult_g_cb + 16'd32768;
      add_cr <= mult_r_cr - mult_g_cr - mult_b_cr + 16'd32768;
    end
  end

  //  �� 3 ����ˮ�ߣ���λ���޷���ͬ�����

  always @(posedge clk) begin
    if (rst) begin
      {o_hs, o_vs, o_de, o_raw_rgb, o_ycbcr} <= 0;
    end else begin
      // ���һ��ʱ����ԭͼ͸��
      o_hs <= hs_d2;
      o_vs <= vs_d2;
      o_de <= de_d2;
      o_raw_rgb <= raw_rgb_d2;

      // ���� 8 λ (ֱ��ȡ�� 8 λ����)�������л����޷�����
      o_ycbcr[23:16] <= (add_y[15:8] > 255) ? 8'd255 : add_y[15:8];  // Y
      o_ycbcr[15:8] <= (add_cb[15:8] > 255) ? 8'd255 : add_cb[15:8];  // Cb
      o_ycbcr[7:0] <= (add_cr[15:8] > 255) ? 8'd255 : add_cr[15:8];  // Cr
    end
  end

endmodule
