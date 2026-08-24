// =============================================================================
// 项目名称：2026 年全国大学生集成电路创新创业大赛国奖项目
// 作者：Ethereal
// 工程分区：基础图像处理工程（base）
// 文件名称：bilateral_filtering_Line_buffer.v
// 主要模块：bilateral_filtering_Line_buffer
// 功能分类：双边滤波算法
// 功能说明：使用行存储构造连续 3×3 像素窗口，并将窗口数据与 HS/VS/DE 信号对齐。
// 输入概述：像素数据及 HS/VS/DE 视频同步信号；控制参数由模式或模块参数给出。
// 输出概述：处理后的像素流，以及与流水线延迟严格匹配的 HS/VS/DE 信号。
// 时序约束：像素数据在视频像素时钟上升沿处理；复位极性以模块端口定义为准。
// 关联文件：bilateral_core.v、bilateral_filtering_proc_to_hdmi.v
// 维护要求：修改端口、位宽、流水线延迟或模式编码时，必须同步更新上层例化与项目文档。
// =============================================================================
`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// [Ethereal注释] 正文导读：使用行存储构造连续 3×3 像素窗口，并将窗口数据与 HS/VS/DE 信号对齐。
// [Ethereal注释] 阅读顺序：先确认参数和端口，再沿内部信号、时序过程及子模块例化追踪数据流。
// [Ethereal注释] 修改约束：读写地址、突发长度、FIFO 清空和跨时钟握手必须保持一致，避免帧错位或数据溢出。
// -----------------------------------------------------------------------------
// [Ethereal注释] 模块 bilateral_filtering_Line_buffer：以下接口构成综合边界，上层通过端口连接数据流、控制流和状态信号。
module bilateral_filtering_Line_buffer #(
    // [Ethereal注释] 参数配置：综合期确定位宽、容量、频率或算法强度，修改后需重新验证资源和时序。
    parameter H_TOTAL = 11'd1344
) (
    // [Ethereal注释] 接口信号：input 接收上游数据/控制，output 返回处理结果/状态，inout 连接双向器件总线。
    input wire i_clk,
    input wire i_rst,
    input wire i_hs,
    input wire i_vs,
    input wire i_data_en,
    input wire [23:0] i_rgb_data,

    output wire [23:0] o_p11,
    o_p12,
    o_p13,
    // [Ethereal注释] 接口信号：input 接收上游数据/控制，output 返回处理结果/状态，inout 连接双向器件总线。
    output wire [23:0] o_p21,
    o_p22,
    o_p23,
    // [Ethereal注释] 接口信号：input 接收上游数据/控制，output 返回处理结果/状态，inout 连接双向器件总线。
    output wire [23:0] o_p31,
    o_p32,
    o_p33,
    // [Ethereal注释] 接口信号：input 接收上游数据/控制，output 返回处理结果/状态，inout 连接双向器件总线。
    output wire o_hs,
    output wire o_vs,
    output wire o_data_en
);
  // 1. 全局计数器 
  // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  reg [10:0] s_cnt;
  reg [10:0] s_cnt_r1, s_cnt_r2;  // 寄存复制，缓解地址线扇出压力

  // [Ethereal注释] 时序过程 1：由 i_clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
  always @(posedge i_clk) begin
    if (i_rst) begin
      s_cnt <= 0;
    end else begin
      s_cnt <= (s_cnt == H_TOTAL - 1) ? 0 : s_cnt + 1;
    end
  end

  // [Ethereal注释] 时序过程 2：由 i_clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
  always @(posedge i_clk) begin
    s_cnt_r1 <= s_cnt;
    s_cnt_r2 <= s_cnt;
  end
  // 2. 数据与同步信号统一打包 (32位)
  // {5位空闲, HS, VS, DE, 24位RGB}
  // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  wire [31:0] pack_in = {5'd0, i_hs, i_vs, i_data_en, i_rgb_data};
  wire [31:0] q1_32, q2_32;

  // LB2: 存中间行 (延迟 1 行)
  // [Ethereal注释] 子模块例化 1（m4k_sync）：封装片上存储器 IP，为行缓存、帧内缓存或直方图统计提供存储资源。
  m4k_sync u_lb2 (
      .clock    (i_clk),
      .wren     (1'b1),
      .wraddress(s_cnt_r2),
      .rdaddress(s_cnt_r2),
      .data     (pack_in),
      .q        (q2_32)
  );

  // LB1: 存最老行 (延迟 2 行)
  // [Ethereal注释] 子模块例化 2（m4k_sync）：封装片上存储器 IP，为行缓存、帧内缓存或直方图统计提供存储资源。
  m4k_sync u_lb1 (
      .clock    (i_clk),
      .wren     (1'b1),
      .wraddress(s_cnt_r1),
      .rdaddress(s_cnt_r1),
      .data     (q2_32),     // 直接把上一行的 32位下传
      .q        (q1_32)
  );

  // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  reg [31:0] pack_in_d1;
  // [Ethereal注释] 时序过程 3：由 i_clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
  always @(posedge i_clk) begin
    pack_in_d1 <= pack_in;
  end

  // 解包出三行的 RGB 数据
  // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  wire [23:0] row1_rgb = q1_32[23:0];  // 最老行 (上)
  wire [23:0] row2_rgb = q2_32[23:0];  // 中间行 (中)
  wire [23:0] row3_rgb = pack_in_d1[23:0];  // 当前行 (下)

  // 提取中间行 (Row 2) 的同步信号作为全局基准
  wire [ 2:0] row2_sync = q2_32[26:24];  // {hs, vs, de}
  // 4. 窗口移位
  reg [23:0] w11, w12, w13, w21, w22, w23, w31, w32, w33;
  reg [2:0] sync_shift[0:2];

  // [Ethereal注释] 时序过程 4：由 i_clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
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
  // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  reg [23:0] op11, op12, op13, op21, op22, op23, op31, op32, op33;
  reg ohs, ovs, ode;

  // [Ethereal注释] 时序过程 5：由 i_clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
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

  // [Ethereal注释] 组合连线组 1：从 {o_p11, o_p12, o_p13} 开始的连续赋值随右值立即更新，不增加寄存器延迟。
  assign {o_p11, o_p12, o_p13} = {op11, op12, op13};
  assign {o_p21, o_p22, o_p23} = {op21, op22, op23};
  assign {o_p31, o_p32, o_p33} = {op31, op32, op33};
  assign o_hs = ohs;
  assign o_vs = ovs;
  assign o_data_en = ode;
endmodule



