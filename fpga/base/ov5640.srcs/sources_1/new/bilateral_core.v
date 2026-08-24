// =============================================================================
// 文件名称：bilateral_core.v
// 主要模块：bilateral_core
// 功能说明：计算双边滤波的空间权重与灰度权重。
// 维护说明：修改接口或时序时，请同步更新本文件注释和上层例化。
// =============================================================================

`timescale 1 ns / 1 ps

module bilateral_core (
    input wire i_clk,
    input wire i_rst,

    // 来自 Line_buffer 的 3x3 窗口数据与同步信号
    input wire i_hs,
    input wire i_vs,
    input wire i_data_en,

    input wire [23:0] i_p11,
    i_p12,
    i_p13,
    input wire [23:0] i_p21,
    i_p22,
    i_p23,
    input wire [23:0] i_p31,
    i_p32,
    i_p33,

    output wire        o_hs,
    output wire        o_vs,
    output wire        o_data_en,
    output wire [23:0] o_ycbcr_filtered
);

  // 空间权重常量定义 (放大了 255 倍)
  localparam [7:0] W_SP_CENTER = 8'd128;
  localparam [7:0] W_SP_EDGE = 8'd78;
  localparam [7:0] W_SP_CORNER = 8'd47;

  // 提取 9 个像素的 Y 分量 (高 8 位)
  wire [7:0] y11 = i_p11[23:16];
  wire [7:0] y12 = i_p12[23:16];
  wire [7:0] y13 = i_p13[23:16];
  wire [7:0] y21 = i_p21[23:16];
  wire [7:0] y22 = i_p22[23:16];
  wire [7:0] y23 = i_p23[23:16];
  wire [7:0] y31 = i_p31[23:16];
  wire [7:0] y32 = i_p32[23:16];
  wire [7:0] y33 = i_p33[23:16];

  // 1. 同步信号与 CbCr 打包
  //  [26:0] = {HS[26], VS[25], DE[24], CbCr[23:8], Y[7:0]}
  wire [26:0] packet_in = {i_hs, i_vs, i_data_en, i_p22[15:0], y22};
  reg [26:0] packet_delay[0:10];
  integer i;

  always @(posedge i_clk) begin
    if (i_rst) begin
      for (i = 0; i < 11; i = i + 1) packet_delay[i] <= 27'd0;
    end else begin
      packet_delay[0] <= packet_in;  // T=1
      for (i = 1; i < 11; i = i + 1) packet_delay[i] <= packet_delay[i-1];
    end
  end
  //Stage 1 : 计算亮度差绝对值
  reg [7:0] d11, d12, d13, d21, d23, d31, d32, d33;
  reg [7:0] y11_d1, y12_d1, y13_d1, y21_d1, y22_d1, y23_d1, y31_d1, y32_d1, y33_d1;

  always @(posedge i_clk) begin
    d11 <= (y11 > y22) ? (y11 - y22) : (y22 - y11);
    d12 <= (y12 > y22) ? (y12 - y22) : (y22 - y12);
    d13 <= (y13 > y22) ? (y13 - y22) : (y22 - y13);
    d21 <= (y21 > y22) ? (y21 - y22) : (y22 - y21);
    d23 <= (y23 > y22) ? (y23 - y22) : (y22 - y23);
    d31 <= (y31 > y22) ? (y31 - y22) : (y22 - y31);
    d32 <= (y32 > y22) ? (y32 - y22) : (y22 - y32);
    d33 <= (y33 > y22) ? (y33 - y22) : (y22 - y33);
    {y11_d1, y12_d1, y13_d1, y21_d1, y22_d1, y23_d1, y31_d1, y32_d1, y33_d1} <= {
      y11, y12, y13, y21, y22, y23, y31, y32, y33
    };
  end
  // Stage 2 (T=2 & T=3): ROM 查表获取值域权重
  wire [7:0] wr11_w, wr12_w, wr13_w, wr21_w, wr23_w, wr31_w, wr32_w, wr33_w;
  reg [7:0] wr22_w;  // 中心像素权重恒定为 255，单独寄存即可
  reg [7:0] wr11, wr12, wr13, wr21, wr22, wr23, wr31, wr32, wr33;
  rom_8_256 u_r11 (
      .address(d11),
      .clock(i_clk),
      .q(wr11_w)
  );
  rom_8_256 u_r12 (
      .address(d12),
      .clock(i_clk),
      .q(wr12_w)
  );
  rom_8_256 u_r13 (
      .address(d13),
      .clock(i_clk),
      .q(wr13_w)
  );
  rom_8_256 u_r21 (
      .address(d21),
      .clock(i_clk),
      .q(wr21_w)
  );
  rom_8_256 u_r23 (
      .address(d23),
      .clock(i_clk),
      .q(wr23_w)
  );
  rom_8_256 u_r31 (
      .address(d31),
      .clock(i_clk),
      .q(wr31_w)
  );
  rom_8_256 u_r32 (
      .address(d32),
      .clock(i_clk),
      .q(wr32_w)
  );
  rom_8_256 u_r33 (
      .address(d33),
      .clock(i_clk),
      .q(wr33_w)
  );
  always @(posedge i_clk) begin
    wr22_w <= 8'd255;  // 中心像素权重恒定为 255
  end
  // 手动打 1 拍寄存，确保 ROM 输出稳定对齐后续流水线
  reg [7:0] y11_d2, y12_d2, y13_d2, y21_d2, y22_d2, y23_d2, y31_d2, y32_d2, y33_d2;
  reg [7:0] y11_d3, y12_d3, y13_d3, y21_d3, y22_d3, y23_d3, y31_d3, y32_d3, y33_d3;

  always @(posedge i_clk) begin
    wr11 <= wr11_w;
    wr12 <= wr12_w;
    wr13 <= wr13_w;
    wr21 <= wr21_w;
    wr22 <= wr22_w;
    wr23 <= wr23_w;
    wr31 <= wr31_w;
    wr32 <= wr32_w;
    wr33 <= wr33_w;
    {y11_d2, y12_d2, y13_d2, y21_d2, y22_d2, y23_d2, y31_d2, y32_d2, y33_d2} <= {
      y11_d1, y12_d1, y13_d1, y21_d1, y22_d1, y23_d1, y31_d1, y32_d1, y33_d1
    };
    {y11_d3, y12_d3, y13_d3, y21_d3, y22_d3, y23_d3, y31_d3, y32_d3, y33_d3} <= {
      y11_d2, y12_d2, y13_d2, y21_d2, y22_d2, y23_d2, y31_d2, y32_d2, y33_d2
    };
  end

  // Stage 3 (T=4): 计算混合总权重 W_total
  reg [15:0] wt11, wt12, wt13, wt21, wt22, wt23, wt31, wt32, wt33;
  reg [7:0] y11_d4, y12_d4, y13_d4, y21_d4, y22_d4, y23_d4, y31_d4, y32_d4, y33_d4;

  always @(posedge i_clk) begin
    wt11 <= wr11 * W_SP_CORNER;
    wt12 <= wr12 * W_SP_EDGE;
    wt13 <= wr13 * W_SP_CORNER;
    wt21 <= wr21 * W_SP_EDGE;
    wt22 <= wr22 * W_SP_CENTER;
    wt23 <= wr23 * W_SP_EDGE;
    wt31 <= wr31 * W_SP_CORNER;
    wt32 <= wr32 * W_SP_EDGE;
    wt33 <= wr33 * W_SP_CORNER;

    {y11_d4, y12_d4, y13_d4, y21_d4, y22_d4, y23_d4, y31_d4, y32_d4, y33_d4} <= {
      y11_d3, y12_d3, y13_d3, y21_d3, y22_d3, y23_d3, y31_d3, y32_d3, y33_d3
    };
  end

  // Stage 4 (T=5): 像素加权乘法 ,权重累加
  reg [23:0] pwt11, pwt12, pwt13, pwt21, pwt22, pwt23, pwt31, pwt32, pwt33;
  reg [17:0] w_sum_l1_1, w_sum_l1_2, w_sum_l1_3;

  always @(posedge i_clk) begin
    pwt11 <= y11_d4 * wt11;
    pwt12 <= y12_d4 * wt12;
    pwt13 <= y13_d4 * wt13;
    pwt21 <= y21_d4 * wt21;
    pwt22 <= y22_d4 * wt22;
    pwt23 <= y23_d4 * wt23;
    pwt31 <= y31_d4 * wt31;
    pwt32 <= y32_d4 * wt32;
    pwt33 <= y33_d4 * wt33;

    w_sum_l1_1 <= wt11 + wt12 + wt13;
    w_sum_l1_2 <= wt21 + wt22 + wt23;
    w_sum_l1_3 <= wt31 + wt32 + wt33;
  end

  // Stage 5 & 6 (T=6 & T=7):求和与最终像素值归一化
  reg [25:0] p_sum_l1_1, p_sum_l1_2, p_sum_l1_3;
  reg [18:0] w_sum_l2;

  reg [27:0] p_sum_final;
  reg [19:0] w_sum_final;

  always @(posedge i_clk) begin
    // T=6
    p_sum_l1_1 <= pwt11 + pwt12 + pwt13;
    p_sum_l1_2 <= pwt21 + pwt22 + pwt23;
    p_sum_l1_3 <= pwt31 + pwt32 + pwt33;
    w_sum_l2 <= w_sum_l1_1 + w_sum_l1_2;

    // T=7
    p_sum_final <= p_sum_l1_1 + p_sum_l1_2 + p_sum_l1_3;
    w_sum_final <= w_sum_l2 + w_sum_l1_3;
  end

  // Stage 7 (T=8 & T=9): 倒数 ROM 查表
  wire [11:0] rec_addr = (w_sum_final + 128) >> 8;
  wire [17:0] inv_w_w;
  reg  [17:0] inv_w;
  // T=7 送入地址，T=8 线出结果
  rom_reciprocal u_reciprocal (
      .address(rec_addr),
      .clock(i_clk),
      .q(inv_w_w)
  );

  // 手动打 1 拍
  reg [27:0] p_sum_final_d1, p_sum_final_d2;

  always @(posedge i_clk) begin  // T=9: 获取对齐后的倒数
    inv_w <= inv_w_w;
    p_sum_final_d1 <= p_sum_final;  // T=8: 像素和打拍等 ROM
    p_sum_final_d2 <= p_sum_final_d1;  // T=9: 像素和再次打拍对齐 inv_w
  end
  // Stage 8 & 9 (T=10 & T=11): 归一化乘法与钳位
  reg [45:0] norm_mult;
  reg [ 7:0] y_out;

  always @(posedge i_clk) begin
    norm_mult <= p_sum_final_d2 * inv_w;  // T=10

    // Stage 9: 移位截断 + 溢出钳位 (Clamp)
    // 提取整数部分的高位 [45:40]。
    // 如果高位不为 0，说明乘法结果 >= 256 发生了溢出，强制输出最高亮度 255
    if (norm_mult[45:40] != 6'd0) begin
      y_out <= 8'd255;  // 溢出钳位
    end else begin
      y_out <= norm_mult[39:32];  // 正常范围，安全截取
    end
    // y_out <= packet_delay[9][7:0]; 
  end

  // Stage 10 (T=12): 输出打包与同步信号恢复
  reg [23:0] o_data;
  reg ohs, ovs, ode;

  // 提取中心亮度 (用于测试)
  wire [7:0] original_y = packet_delay[10][7:0];
  wire [7:0] diff_y = (original_y > y_out) ? (original_y - y_out) : (y_out - original_y);

  always @(posedge i_clk) begin
    if (i_rst) begin
      o_data <= 24'd0;
      {ohs, ovs, ode} <= 3'd0;
    end else begin
      if (packet_delay[10][24] == 1'b0) begin
        o_data <= 24'd0;  // 掩码清零，彻底解决绿边
      end else begin
        //  输出滤波后的 Y + 原始 CbCr
        o_data <= {y_out, packet_delay[10][23:8]};

        //  如果想看差分噪点图，注释掉上面一行，解除下面一行的注释
        //o_data <= {(diff_y << 2), 8'd128, 8'd128}; 
        // 现在改成：给 Y 分量强行加上 64 的基础亮度
        //o_data <= {(diff_y << 2) + 8'd64, 8'd128, 8'd128};
      end

      ohs <= packet_delay[10][26];
      ovs <= packet_delay[10][25];
      ode <= packet_delay[10][24];
    end
  end

  assign {o_hs, o_vs, o_data_en} = {ohs, ovs, ode};
  assign o_ycbcr_filtered = o_data;

endmodule
