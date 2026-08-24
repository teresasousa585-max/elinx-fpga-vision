// =============================================================================
// 文件名称：cdc_handshake.v
// 主要模块：cdc_handshake
// 功能说明：在异步时钟域之间可靠传递控制信息。
// 维护说明：修改接口或时序时，请同步更新本文件注释和上层例化。
// =============================================================================

`timescale 1ns / 1ps

// 多比特安全跨时钟域：基于四相握手协议 (Req & Ack)
module cdc_handshake #(
    parameter DATA_WIDTH = 12
) (
    input wire rst,

    // 发送端 (系统时钟域 100MHz)
    input wire tx_clk,
    input wire tx_req_in,  // 收到UART新指令时拉高一个脉冲
    input wire [DATA_WIDTH-1:0] tx_data_in,  // 要发送的模式数据
    output reg tx_busy,  // 为1表示正在跨域传输，暂不可接收新数据

    // 接收端 (HDMI时钟域 50MHz 或 摄像头时钟域 50MHz)
    input  wire                  rx_clk,
    output reg                   rx_valid,    // 输出一个脉冲，表示收到了新数据
    output reg  [DATA_WIDTH-1:0] rx_data_out  // 安全到达的模式数据
);

  // TX Domain (发送端状态机与信号)
  reg tx_req;
  reg [DATA_WIDTH-1:0] tx_data_reg;

  // 接收端 Ack 信号在 TX 域的同步打拍
  reg rx_ack_meta, rx_ack_sync;
  always @(posedge tx_clk) begin
    rx_ack_meta <= rx_ack;
    rx_ack_sync <= rx_ack_meta;
  end

  // TX 状态机：发起 Req，等待 Ack，撤销 Req，等待 Ack 撤销
  always @(posedge tx_clk or posedge rst) begin
    if (rst) begin
      tx_req      <= 1'b0;
      tx_busy     <= 1'b0;
      tx_data_reg <= {DATA_WIDTH{1'b0}};
    end else begin
      if (!tx_busy && tx_req_in) begin
        // 发起传输：锁存数据，拉高请求
        tx_data_reg <= tx_data_in;
        tx_req      <= 1'b1;
        tx_busy     <= 1'b1;
      end else if (tx_busy && tx_req && rx_ack_sync) begin
        // 收到接收端确认，撤销请求
        tx_req <= 1'b0;
      end else if (tx_busy && !tx_req && !rx_ack_sync) begin
        // 接收端也撤销了确认，一次完整握手结束，释放总线
        tx_busy <= 1'b0;
      end
    end
  end

  // RX Domain (接收端逻辑)
  // 发送端 Req 信号在 RX 域的同步打拍
  reg tx_req_meta, tx_req_sync;
  reg tx_req_sync_d1;
  always @(posedge rx_clk) begin
    tx_req_meta    <= tx_req;
    tx_req_sync    <= tx_req_meta;
    tx_req_sync_d1 <= tx_req_sync;
  end

  reg rx_ack;

  always @(posedge rx_clk or posedge rst) begin
    if (rst) begin
      rx_ack      <= 1'b0;
      rx_valid    <= 1'b0;
      rx_data_out <= {DATA_WIDTH{1'b0}};
    end else begin
      // 抓取 req 的上升沿
      if (tx_req_sync && !tx_req_sync_d1) begin
        // 此时多比特数据必定已经稳定，放心采！
        rx_data_out <= tx_data_reg;
        rx_valid    <= 1'b1;  // 输出一拍有效脉冲
        rx_ack      <= 1'b1;  // 告诉 TX：我收到了
      end else begin
        rx_valid <= 1'b0;
        // 当 TX 撤销了 req，RX 也跟着撤销 ack
        if (!tx_req_sync) begin
          rx_ack <= 1'b0;
        end
      end
    end
  end

endmodule
