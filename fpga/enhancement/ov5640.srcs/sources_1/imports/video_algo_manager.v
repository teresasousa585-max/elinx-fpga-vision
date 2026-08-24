// =============================================================================
// 项目名称：2026 年全国大学生集成电路创新创业大赛国奖项目
// 作者：Ethereal
// 工程分区：图像增强工程（enhancement）
// 文件名称：video_algo_manager.v
// 主要模块：image_process_pipe
// 功能分类：算法调度
// 功能说明：实例化引导滤波/磨皮和暗光增强支路，根据主模式 10、11 选择最终输出视频流。
// 输入概述：像素数据及 HS/VS/DE 视频同步信号；控制参数由模式或模块参数给出。
// 输出概述：处理后的像素流，以及与流水线延迟严格匹配的 HS/VS/DE 信号。
// 时序约束：像素数据在视频像素时钟上升沿处理；复位极性以模块端口定义为准。
// 关联文件：guided_to_hdmi.v、anguang_tohdmi.v、uart_cmd_parser.v、top.v
// 维护要求：修改端口、位宽、流水线延迟或模式编码时，必须同步更新上层例化与项目文档。
// =============================================================================
`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// 正文导读：实例化引导滤波/磨皮和暗光增强支路，根据主模式 10、11 选择最终输出视频流。
// 阅读顺序：先确认参数和端口，再沿内部信号、时序过程及子模块例化追踪数据流。
// 修改约束：像素数据、有效信号和 HS/VS 必须保持同拍；跨时钟数据必须使用 FIFO 或握手。
// -----------------------------------------------------------------------------
// 模块 image_process_pipe：以下接口构成综合边界，上层通过端口连接数据流、控制流和状态信号。
module image_process_pipe (
    // 接口信号：input 接收上游数据/控制，output 返回处理结果/状态，inout 连接双向器件总线。
    input wire clk_hdmi,
    input wire sys_rst,

    // 上位机下发的模式指令
    input wire [3:0] al_main_hdmi,
    input wire [7:0] al_sub_hdmi,

    // 来自 hdmi.v 的基准图像流与同步时序
    input wire        raw_hs,
    input wire        raw_vs,
    input wire        raw_de,
    input wire [23:0] raw_rgb,

    // 最终输出到显示器物理引脚的图像与时序
    output reg        final_hs,
    output reg        final_vs,
    output reg        final_de,
    output reg [23:0] final_rgb
);
  //引导滤波
  // 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  wire guide_hs, guide_vs, guide_de;
  wire [23:0] guide_rgb;
  //引导滤波和美颜磨皮
  // 子模块例化 1（guided_to_hdmi）：集成灰度引导、局部统计、系数滤波和图像重建；子模式选择通用引导滤波或磨皮处理。
  guided_to_hdmi u_guided_filtering (
      .i_clk     (clk_hdmi),
      .i_rst     (sys_rst),
      .i_mode    (al_sub_hdmi == 1),  // 0: 全局纯引导滤波,  1: 美颜磨皮
      .i_hs      (raw_hs),
      .i_vs      (raw_vs),
      .i_de      (raw_de),
      .i_rgb_data(raw_rgb),           // 从 HDMI 输入的 RGB888 数据

      .o_hs(guide_hs),
	  .o_vs(guide_vs),
      .o_de(guide_de),
      .o_rgb_data(guide_rgb)
  );
	//暗光处理
  // 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  wire anguang_hs, anguang_vs, anguang_de;
  wire [23:0] anguang_rgb;
  // 子模块例化 2（anguang_tohdmi）：组织暗光照度估计、增强应用和视频时序对齐，输出 RGB888 增强画面。
  anguang_tohdmi u_anguang_proc (
      .i_clk     (clk_hdmi),
      .i_rst     (sys_rst),
      .i_hs      (raw_hs),
      .i_vs      (raw_vs),
      .i_de      (raw_de),
      .i_rgb_data(raw_rgb),           // 从 HDMI 输入的 RGB888 数据
	  
      .o_hs(anguang_hs),
	  .o_vs(anguang_vs),
      .o_de(anguang_de),
      .o_rgb_data(anguang_rgb)
  );
  // 输出通道路由 (MUX)：保证各模式下时序绝对安全对齐
  // 时序过程 1：由 clk_hdmi posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
  always @(posedge clk_hdmi) begin
    // 分支选择 1：依据 al_main_hdmi 选择状态或算法路径；default 覆盖非法或空闲条件。
    case (al_main_hdmi)
      4'd10: begin
        final_hs  <= guide_hs;
        final_vs  <= guide_vs;
        final_de  <= guide_de;
        final_rgb <= guide_de ? guide_rgb : 24'd0;
      end
	  4'd11: begin
        final_hs  <= anguang_hs;
        final_vs  <= anguang_vs;
        final_de  <= anguang_de;
        final_rgb <= anguang_de ? anguang_rgb : 24'd0;
      end
      default: begin
        final_hs  <= guide_hs;
        final_vs  <= guide_vs;
        final_de  <= guide_de;
        final_rgb <= 24'd0;
      end
    endcase
  end

endmodule
