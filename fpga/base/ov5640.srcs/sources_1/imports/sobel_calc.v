// =============================================================================
// 项目名称：2026 年全国大学生集成电路创新创业大赛国奖项目
// 作者：Ethereal
// 工程分区：基础图像处理工程（base）
// 文件名称：sobel_calc.v
// 主要模块：sobel_calc
// 功能分类：边缘检测算法
// 功能说明：计算 Sobel 水平与垂直梯度，依据阈值生成二值边缘图。
// 输入概述：像素数据及 HS/VS/DE 视频同步信号；控制参数由模式或模块参数给出。
// 输出概述：处理后的像素流，以及与流水线延迟严格匹配的 HS/VS/DE 信号。
// 时序约束：像素数据在视频像素时钟上升沿处理；复位极性以模块端口定义为准。
// 关联文件：sobel_line_buffer.v、video_algo_manager.v
// 维护要求：修改端口、位宽、流水线延迟或模式编码时，必须同步更新上层例化与项目文档。
// =============================================================================
`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// 正文导读：计算 Sobel 水平与垂直梯度，依据阈值生成二值边缘图。
// 阅读顺序：先确认参数和端口，再沿内部信号、时序过程及子模块例化追踪数据流。
// 修改约束：像素数据、有效信号和 HS/VS 必须保持同拍；跨时钟数据必须使用 FIFO 或握手。
// -----------------------------------------------------------------------------
// 模块 sobel_calc：以下接口构成综合边界，上层通过端口连接数据流、控制流和状态信号。
module sobel_calc (
    // 接口信号：input 接收上游数据/控制，output 返回处理结果/状态，inout 连接双向器件总线。
    input wire clk,
    input wire rst,

    // 输入同步信号 (来自 Line Buffer)
    input wire i_hs,
    input wire i_vs,
    input wire i_de,

    // 输入 3x3 灰度窗口
    input wire [7:0] p11,
    p12,
    p13,
    // 接口信号：input 接收上游数据/控制，output 返回处理结果/状态，inout 连接双向器件总线。
    input wire [7:0] p21,
    p22,
    p23,
    // 接口信号：input 接收上游数据/控制，output 返回处理结果/状态，inout 连接双向器件总线。
    input wire [7:0] p31,
    p32,
    p33,

    // 串口动态调节的阈值
    // 接口信号：input 接收上游数据/控制，output 返回处理结果/状态，inout 连接双向器件总线。
    input wire [7:0] i_threshold,

    // 输出同步信号与二值化数据
    output reg        o_hs,
    output reg        o_vs,
    output reg        o_de,
    output reg [23:0] o_rgb_binary
);

  // 同步信号流水线，深度 3 (匹配数据处理延迟)
  // 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  reg [2:0] hs_pipe, vs_pipe, de_pipe;

  // --- 第一级流水线：并行计算水平与垂直梯度 ---
  // 范围：8位加减后最大 10位有符号数
  reg signed [10:0] gx, gy;

  // 时序过程 1：由 clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
  always @(posedge clk) begin
    if (rst) begin
      gx <= 11'd0;
      gy <= 11'd0;
      {hs_pipe[0], vs_pipe[0], de_pipe[0]} <= 3'b0;
    end else begin
      // gx = (p13 + 2*p23 + p33) - (p11 + 2*p21 + p31)
      gx <= ($signed(
          {1'b0, p13}
      ) + $signed(
          {1'b0, p23}
      ) + $signed(
          {1'b0, p23}
      ) + $signed(
          {1'b0, p33}
      )) - ($signed(
          {1'b0, p11}
      ) + $signed(
          {1'b0, p21}
      ) + $signed(
          {1'b0, p21}
      ) + $signed(
          {1'b0, p31}
      ));

      // gy = (p11 + 2*p12 + p13) - (p31 + 2*p32 + p33)
      gy <= ($signed(
          {1'b0, p11}
      ) + $signed(
          {1'b0, p12}
      ) + $signed(
          {1'b0, p12}
      ) + $signed(
          {1'b0, p13}
      )) - ($signed(
          {1'b0, p31}
      ) + $signed(
          {1'b0, p32}
      ) + $signed(
          {1'b0, p32}
      ) + $signed(
          {1'b0, p33}
      ));

      hs_pipe[0] <= i_hs;
      vs_pipe[0] <= i_vs;
      de_pipe[0] <= i_de;
    end
  end

  // --- 第二级流水线：计算绝对值并累加 (或计算平方和) ---
  // 为了极致性能，这里使用 |gx| + |gy| 替代平方根，效果对边缘检测已足够
  // 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  reg [10:0] gx_abs, gy_abs;
  reg [11:0] g_sum;

  // 时序过程 2：由 clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
  always @(posedge clk) begin
    if (rst) begin
      gx_abs <= 11'd0;
      gy_abs <= 11'd0;
      g_sum <= 12'd0;
      {hs_pipe[1], vs_pipe[1], de_pipe[1]} <= 3'b0;
    end else begin
      gx_abs <= (gx[10]) ? (~gx + 1'b1) : gx;
      gy_abs <= (gy[10]) ? (~gy + 1'b1) : gy;
      g_sum <= gx_abs + gy_abs;

      hs_pipe[1] <= hs_pipe[0];
      vs_pipe[1] <= vs_pipe[0];
      de_pipe[1] <= de_pipe[0];
    end
  end

  // --- 第三级流水线：阈值比较与最终输出 ---
  // 时序过程 3：由 clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
  always @(posedge clk) begin
    if (rst) begin
      o_rgb_binary <= 24'd0;
      {o_hs, o_vs, o_de} <= 3'b0;
      {hs_pipe[2], vs_pipe[2], de_pipe[2]} <= 3'b0;
    end else begin
      if (g_sum > i_threshold) o_rgb_binary <= 24'hFFFFFF;  // 白色边缘
      else o_rgb_binary <= 24'h000000;  // 黑色背景

      // 最终对齐输出
      o_hs <= hs_pipe[1];  // 此处基于流水线级数选择对应的 tap
      o_vs <= vs_pipe[1];
      o_de <= de_pipe[1];

      // 继续传递流水线信号（如需更多后处理）
      hs_pipe[2] <= hs_pipe[1];
      vs_pipe[2] <= vs_pipe[1];
      de_pipe[2] <= de_pipe[1];
    end
  end

endmodule
