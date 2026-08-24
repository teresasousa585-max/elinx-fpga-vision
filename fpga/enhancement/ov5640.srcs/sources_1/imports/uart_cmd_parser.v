// =============================================================================
// 项目名称：2026 年全国大学生集成电路创新创业大赛国奖项目
// 工程分区：图像增强工程（enhancement）
// 文件名称：uart_cmd_parser.v
// 主要模块：uart_cmd_parser
// 功能分类：串口通信
// 功能说明：识别 0xAA/0x55 帧界定符，解析主模式与子模式并产生更新脉冲。
// 输入概述：串行数据或模式控制数据，以及对应时钟和复位信号。
// 输出概述：解析/同步后的模式数据、有效脉冲或选定的视频通路。
// 时序约束：控制更新仅在完整帧或握手完成后生效，禁止直接跨时钟域采样多位总线。
// 关联文件：uart_rx.v、cdc_handshake.v、video_algo_manager.v
// 维护要求：修改端口、位宽、流水线延迟或模式编码时，必须同步更新上层例化与项目文档。
// =============================================================================
module uart_cmd_parser (
    input wire       clk,
    input wire       rst,
    input wire       rx_done,
    input wire [7:0] rx_data,

    output reg [3:0] target_main_mode,
    output reg [7:0] target_sub_mode,
    output reg       mode_valid
);
  reg [7:0] buf0, buf1, buf2;

  always @(posedge clk) begin
    if (rst) begin
      buf0 <= 8'd0;
      buf1 <= 8'd0;
      buf2 <= 8'd0;
      target_main_mode <= 4'd0;
      mode_valid <= 1'b0;
      target_sub_mode <= 8'd0;
    end else begin
      mode_valid <= 1'b0;
      if (rx_done) begin
        // 移位缓存：接收顺序为 AA -> Main -> Sub -> 55
        buf2 <= buf1;
        buf1 <= buf0;
        buf0 <= rx_data;

        // 当 rx_data 收到 0x55 时，buf2应为 0xAA
        // 此时 buf1 为 Main Mode, buf0 为 Sub Mode
        if (buf2 == 8'hAA && rx_data == 8'h55) begin
          target_main_mode <= buf1[3:0];
          target_sub_mode  <= buf0;
          mode_valid       <= 1'b1;
        end
      end
    end
  end
endmodule
