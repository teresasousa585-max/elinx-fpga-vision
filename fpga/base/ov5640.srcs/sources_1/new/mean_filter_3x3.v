// =============================================================================
// 项目名称：2026 年全国大学生集成电路创新创业大赛国奖项目
// 工程分区：基础图像处理工程（base）
// 文件名称：mean_filter_3x3.v
// 主要模块：mean_filter_3x3
// 功能分类：空间滤波算法
// 功能说明：对 RGB 3×3 邻域执行均值滤波，用于图像放大后的平滑和锯齿抑制。
// 输入概述：像素数据及 HS/VS/DE 视频同步信号；控制参数由模式或模块参数给出。
// 输出概述：处理后的像素流，以及与流水线延迟严格匹配的 HS/VS/DE 信号。
// 时序约束：像素数据在视频像素时钟上升沿处理；复位极性以模块端口定义为准。
// 关联文件：video_algo_manager.v、line_buffer IP
// 维护要求：修改端口、位宽、流水线延迟或模式编码时，必须同步更新上层例化与项目文档。
// =============================================================================
`timescale 1ns / 1ps

module mean_filter_3x3 (
    input wire i_clk,
    input wire i_rst,
    input wire i_hs,
    input wire i_vs,
    input wire i_de,
    input wire [23:0] i_rgb,

    output reg o_hs,
    output reg o_vs,
    output reg o_de,
    output reg [23:0] o_rgb
);

  wire [23:0] p11, p12, p13, p21, p22, p23, p31, p32, p33;
  wire m_hs, m_vs, m_de;

  // 复用 3x3 缓存模块 ( m_hs 已经和 p22 中心对齐)
  bilateral_filtering_Line_buffer #(
      .H_TOTAL(11'd1344)
  ) u_buf (
      .i_clk(i_clk),
      .i_rst(i_rst),
      .i_hs(i_hs),
      .i_vs(i_vs),
      .i_data_en(i_de),
      .i_rgb_data(i_rgb),
      .o_p11(p11),
      .o_p12(p12),
      .o_p13(p13),
      .o_p21(p21),
      .o_p22(p22),
      .o_p23(p23),
      .o_p31(p31),
      .o_p32(p32),
      .o_p33(p33),
      .o_hs(m_hs),
      .o_vs(m_vs),
      .o_data_en(m_de)
  );

  // Pipeline Stage 1: 加法树求和
  reg [11:0] sum_r, sum_g, sum_b;
  reg hs_d1, vs_d1, de_d1;

  always @(posedge i_clk) begin
    sum_r <= (p11[23:16] + p12[23:16] + p13[23:16]) + 
                 (p21[23:16] + p22[23:16] + p23[23:16]) + 
                 (p31[23:16] + p32[23:16] + p33[23:16]);

    sum_g <= (p11[15:8]  + p12[15:8]  + p13[15:8])  + 
                 (p21[15:8]  + p22[15:8]  + p23[15:8])  + 
                 (p31[15:8]  + p32[15:8]  + p33[15:8]);

    sum_b <= (p11[7:0]   + p12[7:0]   + p13[7:0])   + 
                 (p21[7:0]   + p22[7:0]   + p23[7:0])   + 
                 (p31[7:0]   + p32[7:0]   + p33[7:0]);

    hs_d1 <= m_hs;
    vs_d1 <= m_vs;
    de_d1 <= m_de;
  end


  // Pipeline Stage 2: 乘法器运算
  reg [19:0] mult_r, mult_g, mult_b;
  reg hs_d2, vs_d2, de_d2;

  always @(posedge i_clk) begin
    // 强制 20 位运算
    mult_r <= sum_r * 20'd114;
    mult_g <= sum_g * 20'd114;
    mult_b <= sum_b * 20'd114;

    hs_d2  <= hs_d1;
    vs_d2  <= vs_d1;
    de_d2  <= de_d1;
  end


  // Pipeline Stage 3: 移位截取与最终输出
  always @(posedge i_clk) begin
    if (de_d2) begin
      // 截取高 8 位相当于 >> 10
      o_rgb <= {mult_r[17:10], mult_g[17:10], mult_b[17:10]};
    end else begin
      o_rgb <= 24'd0;  // 消隐区严格填黑
    end

    o_hs <= hs_d2;
    o_vs <= vs_d2;
    o_de <= de_d2;
  end

endmodule
