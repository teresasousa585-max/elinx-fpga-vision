// =============================================================================
// 项目名称：2026 年全国大学生集成电路创新创业大赛国奖项目
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

module image_process_pipe (
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
  wire guide_hs, guide_vs, guide_de;
  wire [23:0] guide_rgb;
  //引导滤波和美颜磨皮
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
  wire anguang_hs, anguang_vs, anguang_de;
  wire [23:0] anguang_rgb;
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
  always @(posedge clk_hdmi) begin
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
