// =============================================================================
// 项目名称：2026 年全国大学生集成电路创新创业大赛国奖项目
// 工程分区：图像增强工程（enhancement）
// 文件名称：uart_tx.v
// 主要模块：uart_tx
// 功能分类：串口通信
// 功能说明：将并行字节按 UART 帧格式和设定波特率串行发送。
// 输入概述：串行数据或模式控制数据，以及对应时钟和复位信号。
// 输出概述：解析/同步后的模式数据、有效脉冲或选定的视频通路。
// 时序约束：控制更新仅在完整帧或握手完成后生效，禁止直接跨时钟域采样多位总线。
// 关联文件：top.v
// 维护要求：修改端口、位宽、流水线延迟或模式编码时，必须同步更新上层例化与项目文档。
// =============================================================================
`timescale 1ns / 1ps

module uart_tx #(
    parameter CLK_FRE    = 100,      // 100MHz
    parameter BAUD_RATE  = 1000000,  // 1M
    parameter DATA_WIDTH = 8
) (
    input                       i_clk_sys,
    input                       i_rst,      // 高电平同步复位
    input      [DATA_WIDTH-1:0] i_tx_data,
    input                       i_tx_en,
    output reg                  o_uart_tx,
    output                      o_tx_busy
);

  localparam CLK_COUNT = (CLK_FRE * 1000000) / BAUD_RATE;  // 100

  localparam S_IDLE = 3'd0;
  localparam S_START = 3'd1;
  localparam S_DATA = 3'd2;
  localparam S_STOP = 3'd3;

  reg [2:0] state;
  reg [15:0] cycle_cnt;
  reg [3:0] bit_cnt;
  reg [DATA_WIDTH-1:0] tx_latch;

  // 当不在空闲状态，或者外界刚好给使能时，系统处于忙碌状态
  assign o_tx_busy = (state != S_IDLE) || i_tx_en;

  always @(posedge i_clk_sys) begin  // 纯同步设计
    if (i_rst) begin
      state <= S_IDLE;
      o_uart_tx <= 1'b1;
      cycle_cnt <= 0;
      bit_cnt <= 0;
      tx_latch <= 0;
    end else begin
      case (state)
        S_IDLE: begin
          o_uart_tx <= 1'b1;
          cycle_cnt <= 0;
          bit_cnt   <= 0;
          if (i_tx_en) begin
            tx_latch <= i_tx_data;
            state <= S_START;
          end
        end

        S_START: begin
          o_uart_tx <= 1'b0;  // 起始位拉低
          if (cycle_cnt == CLK_COUNT - 1) begin
            cycle_cnt <= 0;
            state <= S_DATA;
          end else cycle_cnt <= cycle_cnt + 1'b1;
        end

        S_DATA: begin
          o_uart_tx <= tx_latch[bit_cnt];
          if (cycle_cnt == CLK_COUNT - 1) begin
            cycle_cnt <= 0;
            if (bit_cnt == DATA_WIDTH - 1) begin
              bit_cnt <= 0;
              state   <= S_STOP;
            end else bit_cnt <= bit_cnt + 1'b1;
          end else cycle_cnt <= cycle_cnt + 1'b1;
        end

        S_STOP: begin
          o_uart_tx <= 1'b1;  // 停止位拉高
          if (cycle_cnt == CLK_COUNT - 1) begin
            state <= S_IDLE;
          end else cycle_cnt <= cycle_cnt + 1'b1;
        end

        default: state <= S_IDLE;
      endcase
    end
  end
endmodule
