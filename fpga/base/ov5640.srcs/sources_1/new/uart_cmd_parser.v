// =============================================================================
// 文件名称：uart_cmd_parser.v
// 主要模块：uart_cmd_parser
// 功能说明：解析上位机发送的四字节串口控制帧，输出主模式与子模式。
// 维护说明：修改接口或时序时，请同步更新本文件注释和上层例化。
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
