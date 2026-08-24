// =============================================================================
// 项目名称：2026 年全国大学生集成电路创新创业大赛国奖项目
// 工程分区：基础图像处理工程（base）
// 文件名称：sobel_line_buffer.v
// 主要模块：sobel_line_buffer
// 功能分类：边缘检测算法
// 功能说明：缓存三行灰度像素并输出 3×3 邻域，同时对齐窗口有效信号与行场同步。
// 输入概述：像素数据及 HS/VS/DE 视频同步信号；控制参数由模式或模块参数给出。
// 输出概述：处理后的像素流，以及与流水线延迟严格匹配的 HS/VS/DE 信号。
// 时序约束：像素数据在视频像素时钟上升沿处理；复位极性以模块端口定义为准。
// 关联文件：sobel_calc.v、video_algo_manager.v
// 维护要求：修改端口、位宽、流水线延迟或模式编码时，必须同步更新上层例化与项目文档。
// =============================================================================
`timescale 1ns / 1ps

module sobel_line_buffer #(
    parameter H_TOTAL = 11'd1344
) (
    input wire i_clk,
    input wire i_rst,

    // 输入：同步信号与 8位灰度数据
    input wire i_hs,
    input wire i_vs,
    input wire i_data_en,
    input wire [7:0] i_gray_data,

    // 输出：3x3 灰度窗口
    output wire [7:0] o_p11,
    o_p12,
    o_p13,
    output wire [7:0] o_p21,
    o_p22,
    o_p23,
    output wire [7:0] o_p31,
    o_p32,
    o_p33,

    // 输出：对齐到中心像素(p22)的同步信号
    output wire o_hs,
    output wire o_vs,
    output wire o_data_en
);

  // 1. 全局行计数器 
  reg [10:0] s_cnt;
  reg [10:0] s_cnt_r1, s_cnt_r2;  // 寄存复制，缓解地址线扇出压力

  always @(posedge i_clk) begin
    if (i_rst) begin
      s_cnt <= 0;
    end else begin
      s_cnt <= (s_cnt == H_TOTAL - 1) ? 11'd0 : s_cnt + 1'b1;
    end
  end

  always @(posedge i_clk) begin
    s_cnt_r1 <= s_cnt;
    s_cnt_r2 <= s_cnt;
  end

  // 2. 数据与同步信号打包 (16位)
  // {5位空闲, HS, VS, DE, 8位Gray}
  wire [15:0] pack_in = {5'd0, i_hs, i_vs, i_data_en, i_gray_data};
  wire [15:0] q1_16, q2_16;

  // LB2: 存中间行 (延迟 1 行)
  // 请在中科亿海微的 IP 软件中生成一个 位宽=16, 深度=2048 的单端口/简单双端口 RAM
  m4k_sobel_sync u_lb2 (
      .clock    (i_clk),
      .wren     (1'b1),
      .wraddress(s_cnt_r2),
      .rdaddress(s_cnt_r2),
      .data     (pack_in),
      .q        (q2_16)
  );

  // LB1: 存最老行 (延迟 2 行)
  m4k_sobel_sync u_lb1 (
      .clock    (i_clk),
      .wren     (1'b1),
      .wraddress(s_cnt_r1),
      .rdaddress(s_cnt_r1),
      .data     (q2_16),     // 直接把上一行的 16位下传
      .q        (q1_16)
  );

  reg [15:0] pack_in_d1;
  always @(posedge i_clk) begin
    pack_in_d1 <= pack_in;
  end

  // 3. 解包出三行的 8位数据与同步信号
  wire [7:0] row1_gray = q1_16[7:0];  // 最老行 (上)
  wire [7:0] row2_gray = q2_16[7:0];  // 中间行 (中)
  wire [7:0] row3_gray = pack_in_d1[7:0];  // 当前行 (下)

  // 提取中间行 (Row 2) 的同步信号作为全局基准，对应位 {hs, vs, de}
  wire [2:0] row2_sync = q2_16[10:8];

  // 4. 3x3 窗口移位寄存器
  reg [7:0] w11, w12, w13, w21, w22, w23, w31, w32, w33;
  reg [2:0] sync_shift[0:2];

  always @(posedge i_clk) begin
    if (i_rst) begin
      {w11, w12, w13, w21, w22, w23, w31, w32, w33} <= 0;
      sync_shift[0] <= 0;
      sync_shift[1] <= 0;
      sync_shift[2] <= 0;
    end else begin
      // 像素打拍移位
      w13 <= row1_gray;
      w12 <= w13;
      w11 <= w12;
      w23 <= row2_gray;
      w22 <= w23;
      w21 <= w22;
      w33 <= row3_gray;
      w32 <= w33;
      w31 <= w32;

      // 同步信号跟着中间行 (Row 2) 一起无条件移位
      sync_shift[0] <= row2_sync;
      sync_shift[1] <= sync_shift[0];
      sync_shift[2] <= sync_shift[1];
    end
  end

  // 5. 最终对齐输出
  reg [7:0] op11, op12, op13, op21, op22, op23, op31, op32, op33;
  reg ohs, ovs, ode;

  always @(posedge i_clk) begin
    if (i_rst) begin
      {op11, op12, op13, op21, op22, op23, op31, op32, op33} <= 0;
      {ohs, ovs, ode} <= 0;
    end else begin
      // 利用移位后的 DE 信号 (sync_shift[1][0]) 做有效性清零，防止边缘拖尾
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
