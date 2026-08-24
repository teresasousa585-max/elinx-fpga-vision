// =============================================================================
// 文件名称：uart_rx.v
// 主要模块：uart_rx
// 功能说明：按配置波特率接收异步串行数据，并产生字节有效脉冲。
// 维护说明：修改接口或时序时，请同步更新本文件注释和上层例化。
// =============================================================================

`timescale 1ns / 1ps

module uart_rx #(
    parameter CLK_FRE    = 100,      // 主频 100MHz
    parameter BAUD_RATE  = 1000000,  // 目标波特率 1M
    parameter DATA_WIDTH = 8         // 数据位宽
) (
    input                         i_clk_sys,    // 系统时钟
    input                         i_rst,        // 高电平同步复位
    input                         i_uart_rx,    // UART接收引脚
    output reg [DATA_WIDTH-1 : 0] o_uart_data,
    output reg                    o_rx_done
);

  // 100MHz / 1M = 100
  localparam CLK_COUNT = (CLK_FRE * 1000000) / BAUD_RATE;

  // 三级打拍同步，消除跨时钟域亚稳态
  reg [2:0] rx_reg;
  always @(posedge i_clk_sys) begin
    if (i_rst) rx_reg <= 3'b111;
    else rx_reg <= {rx_reg[1:0], i_uart_rx};
  end

  wire rx_falling = (rx_reg[2] & !rx_reg[1]);  // 捕捉起始位下降沿
  wire rx_sync = rx_reg[2];  // 同步后的接收信号

  // 状态机
  localparam S_IDLE = 3'd0;
  localparam S_START = 3'd1;
  localparam S_DATA = 3'd2;
  localparam S_STOP = 3'd3;

  reg [2:0] state;
  reg [15:0] cycle_cnt;
  reg [3:0] bit_cnt;
  reg [DATA_WIDTH-1:0] rx_temp;

  // 多数表决采样寄存器
  reg smp1, smp2, smp3;
  // 表决逻辑：3次采样中至少有2次为1，结果才为1；否则为0
  wire bit_val = (smp1 & smp2) | (smp1 & smp3) | (smp2 & smp3);

  always @(posedge i_clk_sys) begin  // 纯同步设计
    if (i_rst) begin
      state <= S_IDLE;
      o_rx_done <= 1'b0;
      o_uart_data <= 0;
      cycle_cnt <= 0;
      bit_cnt <= 0;
      smp1 <= 1'b1;
      smp2 <= 1'b1;
      smp3 <= 1'b1;
    end else begin
      o_rx_done <= 1'b0;  // 默认拉低，仅在接收完成时拉高一个周期
      case (state)
        S_IDLE: begin
          cycle_cnt <= 0;
          bit_cnt   <= 0;
          if (rx_falling) state <= S_START;
        end

        S_START: begin
          cycle_cnt <= cycle_cnt + 1'b1;
          // 在中心点附近采样3次
          if (cycle_cnt == 45) smp1 <= rx_sync;
          if (cycle_cnt == 50) smp2 <= rx_sync;
          if (cycle_cnt == 55) smp3 <= rx_sync;

          if (cycle_cnt == CLK_COUNT - 1) begin
            cycle_cnt <= 0;
            // 起始位必须稳定为0，否则视为毛刺并放弃
            if (!bit_val) state <= S_DATA;
            else state <= S_IDLE;
          end
        end

        S_DATA: begin
          cycle_cnt <= cycle_cnt + 1'b1;
          // 在数据位的中心点附近采样3次
          if (cycle_cnt == 45) smp1 <= rx_sync;
          if (cycle_cnt == 50) smp2 <= rx_sync;
          if (cycle_cnt == 55) smp3 <= rx_sync;

          if (cycle_cnt == CLK_COUNT - 1) begin
            cycle_cnt <= 0;
            rx_temp[bit_cnt] <= bit_val;  // 记录表决后的最终值
            if (bit_cnt == DATA_WIDTH - 1) begin
              bit_cnt <= 0;
              state   <= S_STOP;
            end else begin
              bit_cnt <= bit_cnt + 1'b1;
            end
          end
        end

        S_STOP: begin
          cycle_cnt <= cycle_cnt + 1'b1;

          // 同样在停止位的中间点附近进行3次采样 (严格模式)
          if (cycle_cnt == 45) smp1 <= rx_sync;
          if (cycle_cnt == 50) smp2 <= rx_sync;
          if (cycle_cnt == 55) smp3 <= rx_sync;

          if (cycle_cnt == CLK_COUNT - 1) begin
            cycle_cnt <= 0;
            if (bit_val == 1'b1) begin
              o_uart_data <= rx_temp;
              o_rx_done   <= 1'b1;  // 停止位正确，输出接收完成脉冲
            end else begin
              o_rx_done <= 1'b0;  // 帧错误丢弃
            end
            state <= S_IDLE;
          end
        end

        default: state <= S_IDLE;
      endcase
    end
  end
endmodule
