// =============================================================================
// 项目名称：2026 年全国大学生集成电路创新创业大赛国奖项目
// 作者：Ethereal
// 工程分区：基础图像处理工程（base）
// 文件名称：cdc_handshake.v
// 主要模块：cdc_handshake
// 功能分类：跨时钟域控制
// 功能说明：采用请求/应答握手在异步时钟域间可靠传递多位模式控制数据。
// 输入概述：串行数据或模式控制数据，以及对应时钟和复位信号。
// 输出概述：解析/同步后的模式数据、有效脉冲或选定的视频通路。
// 时序约束：控制更新仅在完整帧或握手完成后生效，禁止直接跨时钟域采样多位总线。
// 关联文件：uart_cmd_parser.v、top.v
// 维护要求：修改端口、位宽、流水线延迟或模式编码时，必须同步更新上层例化与项目文档。
// =============================================================================
`timescale 1ns / 1ps

// 多比特安全跨时钟域：基于四相握手协议 (Req & Ack)
// -----------------------------------------------------------------------------
// 正文导读：采用请求/应答握手在异步时钟域间可靠传递多位模式控制数据。
// 阅读顺序：先确认参数和端口，再沿内部信号、时序过程及子模块例化追踪数据流。
// 修改约束：协议字段、有效脉冲和跨时钟控制必须成组更新，并与上位机及外设时序保持一致。
// -----------------------------------------------------------------------------
// 模块 cdc_handshake：以下接口构成综合边界，上层通过端口连接数据流、控制流和状态信号。
module cdc_handshake #(
    // 参数配置：综合期确定位宽、容量、频率或算法强度，修改后需重新验证资源和时序。
    parameter DATA_WIDTH = 12
) (
    // 接口信号：input 接收上游数据/控制，output 返回处理结果/状态，inout 连接双向器件总线。
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
  // 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  reg tx_req;
  reg [DATA_WIDTH-1:0] tx_data_reg;

  // 接收端 Ack 信号在 TX 域的同步打拍
  reg rx_ack_meta, rx_ack_sync;
  // 时序过程 1：由 tx_clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
  always @(posedge tx_clk) begin
    rx_ack_meta <= rx_ack;
    rx_ack_sync <= rx_ack_meta;
  end

  // TX 状态机：发起 Req，等待 Ack，撤销 Req，等待 Ack 撤销
  // 时序过程 2：由 tx_clk posedge，rst posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
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
  // 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  reg tx_req_meta, tx_req_sync;
  reg tx_req_sync_d1;
  // 时序过程 3：由 rx_clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
  always @(posedge rx_clk) begin
    tx_req_meta    <= tx_req;
    tx_req_sync    <= tx_req_meta;
    tx_req_sync_d1 <= tx_req_sync;
  end

  // 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  reg rx_ack;

  // 时序过程 4：由 rx_clk posedge，rst posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
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
