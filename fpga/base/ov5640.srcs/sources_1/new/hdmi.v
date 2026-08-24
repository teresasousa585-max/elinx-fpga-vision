// =============================================================================
// 项目名称：2026 年全国大学生集成电路创新创业大赛国奖项目
// 作者：Ethereal
// 工程分区：基础图像处理工程（base）
// 文件名称：hdmi.v
// 主要模块：hdmi
// 功能分类：显示接口
// 功能说明：生成显示扫描时序，从帧缓存读取像素并形成 RGB888、HS、VS、DE 基准视频流。
// 输入概述：外设时钟、同步/像素数据或待显示视频流。
// 输出概述：初始化控制、规范化视频流或板级显示接口信号。
// 时序约束：外设接口遵循对应器件时序；进入算法通路前须保持 HS/VS/DE 与像素对齐。
// 关联文件：sdram_top.v、video_algo_manager.v、top.v
// 维护要求：修改端口、位宽、流水线延迟或模式编码时，必须同步更新上层例化与项目文档。
// =============================================================================
`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// [Ethereal注释] 正文导读：生成显示扫描时序，从帧缓存读取像素并形成 RGB888、HS、VS、DE 基准视频流。
// [Ethereal注释] 阅读顺序：先确认参数和端口，再沿内部信号、时序过程及子模块例化追踪数据流。
// [Ethereal注释] 修改约束：像素数据、有效信号和 HS/VS 必须保持同拍；跨时钟数据必须使用 FIFO 或握手。
// -----------------------------------------------------------------------------
// [Ethereal注释] 模块 hdmi：以下接口构成综合边界，上层通过端口连接数据流、控制流和状态信号。
module hdmi (
    // [Ethereal注释] 接口信号：input 接收上游数据/控制，output 返回处理结果/状态，inout 连接双向器件总线。
    input wire        i_pclk,  // 像素时钟,50MHz
    input wire        i_rst,
    input wire [23:0] i_rgb,   // 接收来自SDRAM 的像素数据

    output wire o_frame_vsync,  // 帧同步清空信号

    output wire        o_hs,
    output wire        o_vs,
    output wire        o_de,
    output reg  [23:0] o_rgb_out, // 送给屏幕的对齐数据

    // 将内部坐标给 top.v 以供画中画定位
    output wire [10:0] o_h_cnt,
    output wire [ 9:0] o_v_cnt,
    output wire        o_pre_de  //输出基础有效区，供Top产生读请求
);

  // [Ethereal注释] 参数配置：综合期确定位宽、容量、频率或算法强度，修改后需重新验证资源和时序。
  localparam H_ACTIVE = 11'd1024, H_FP = 11'd160, H_SYNC = 11'd20, H_BP = 11'd140, H_TOTAL = 11'd1344;
  localparam V_ACTIVE = 10'd600, V_FP = 10'd12, V_SYNC = 10'd3, V_BP = 10'd20, V_TOTAL = 10'd635;

  // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  reg [10:0] h_cnt;
  reg [ 9:0] v_cnt;
  // [Ethereal注释] 时序过程 1：由 i_pclk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
  always @(posedge i_pclk) begin
    if (i_rst) begin
      h_cnt <= 11'd0;
      v_cnt <= 10'd0;
    end else begin
      if (h_cnt == H_TOTAL - 1) begin
        h_cnt <= 11'd0;
        if (v_cnt == V_TOTAL - 1) v_cnt <= 10'd0;
        else v_cnt <= v_cnt + 1'b1;
      end else h_cnt <= h_cnt + 1'b1;
    end
  end

  // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  wire pre_hs = ((h_cnt >= H_ACTIVE + H_FP) && (h_cnt < H_ACTIVE + H_FP + H_SYNC));
  wire pre_vs = ((v_cnt >= V_ACTIVE + V_FP) && (v_cnt < V_ACTIVE + V_FP + V_SYNC));
  wire pre_de = (h_cnt < H_ACTIVE) && (v_cnt < V_ACTIVE);

  // 新增：输出基础显示区间
  // [Ethereal注释] 组合连线组 1：从 o_pre_de 开始的连续赋值随右值立即更新，不增加寄存器延迟。
  assign o_pre_de = pre_de;

  // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  reg vs_d1, vs_d2;
  // [Ethereal注释] 时序过程 2：由 i_pclk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
  always @(posedge i_pclk) begin
    if (i_rst) begin
      vs_d1 <= 1'b0;
      vs_d2 <= 1'b0;
    end else begin
      vs_d1 <= pre_vs;
      vs_d2 <= vs_d1;
    end
  end
  // [Ethereal注释] 组合连线组 1：从 o_frame_vsync 开始的连续赋值随右值立即更新，不增加寄存器延迟。
  assign o_frame_vsync = vs_d1 && !vs_d2;

  //  4 级移位寄存器，拖延屏幕同步信号
  // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  reg [3:0] hs_pipe, vs_pipe, de_pipe;
  // [Ethereal注释] 时序过程 3：由 i_pclk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
  always @(posedge i_pclk) begin
    if (i_rst) begin
      hs_pipe   <= 4'd0;
      vs_pipe   <= 4'd0;
      de_pipe   <= 4'd0;
      o_rgb_out <= 24'd0;
    end else begin
      hs_pipe   <= {hs_pipe[2:0], pre_hs};
      vs_pipe   <= {vs_pipe[2:0], pre_vs};
      de_pipe   <= {de_pipe[2:0], pre_de};

      // 只有在延迟了 4 拍的数据有效门开启时，才吃入 i_rgb
      o_rgb_out <= de_pipe[2] ? i_rgb : 24'h000000;
    end
  end

  // 将延迟对齐后的同步信号发给物理引脚
  // [Ethereal注释] 组合连线组 1：从 o_hs 开始的连续赋值随右值立即更新，不增加寄存器延迟。
  assign o_hs = hs_pipe[3];
  assign o_vs = vs_pipe[3];
  assign o_de = de_pipe[3];


  assign o_h_cnt = h_cnt;
  assign o_v_cnt = v_cnt;

endmodule


