// =============================================================================
// 项目名称：2026 年全国大学生集成电路创新创业大赛国奖项目
// 作者：Ethereal
// 工程分区：基础图像处理工程（base）
// 文件名称：uart_rx.v
// 主要模块：uart_rx
// 功能分类：串口通信
// 功能说明：按设定波特率完成 UART 起始位检测、数据采样和字节有效指示。
// 输入概述：串行数据或模式控制数据，以及对应时钟和复位信号。
// 输出概述：解析/同步后的模式数据、有效脉冲或选定的视频通路。
// 时序约束：控制更新仅在完整帧或握手完成后生效，禁止直接跨时钟域采样多位总线。
// 关联文件：uart_cmd_parser.v、top.v
// 维护要求：修改端口、位宽、流水线延迟或模式编码时，必须同步更新上层例化与项目文档。
// =============================================================================
`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// [Ethereal注释] 正文导读：按设定波特率完成 UART 起始位检测、数据采样和字节有效指示。
// [Ethereal注释] 阅读顺序：先确认参数和端口，再沿内部信号、时序过程及子模块例化追踪数据流。
// [Ethereal注释] 修改约束：协议字段、有效脉冲和跨时钟控制必须成组更新，并与上位机及外设时序保持一致。
// -----------------------------------------------------------------------------
// [Ethereal注释] 模块 uart_rx：以下接口构成综合边界，上层通过端口连接数据流、控制流和状态信号。
module uart_rx #(
    // [Ethereal注释] 参数配置：综合期确定位宽、容量、频率或算法强度，修改后需重新验证资源和时序。
    parameter CLK_FRE    = 100,      // 主频 100MHz
    parameter BAUD_RATE  = 1000000,  // 目标波特率 1M
    parameter DATA_WIDTH = 8         // 数据位宽
) (
    // [Ethereal注释] 接口信号：input 接收上游数据/控制，output 返回处理结果/状态，inout 连接双向器件总线。
    input                         i_clk_sys,    // 系统时钟
    input                         i_rst,        // 高电平同步复位
    input                         i_uart_rx,    // UART接收引脚
    output reg [DATA_WIDTH-1 : 0] o_uart_data,
    output reg                    o_rx_done
);

  // 100MHz / 1M = 100
  // [Ethereal注释] 参数配置：综合期确定位宽、容量、频率或算法强度，修改后需重新验证资源和时序。
  localparam CLK_COUNT = (CLK_FRE * 1000000) / BAUD_RATE;

  // 三级打拍同步，消除跨时钟域亚稳态
  // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  reg [2:0] rx_reg;
  // [Ethereal注释] 时序过程 1：由 i_clk_sys posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
  always @(posedge i_clk_sys) begin
    if (i_rst) rx_reg <= 3'b111;
    else rx_reg <= {rx_reg[1:0], i_uart_rx};
  end

  // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  wire rx_falling = (rx_reg[2] & !rx_reg[1]);  // 捕捉起始位下降沿
  wire rx_sync = rx_reg[2];  // 同步后的接收信号

  // 状态机
  // [Ethereal注释] 参数配置：综合期确定位宽、容量、频率或算法强度，修改后需重新验证资源和时序。
  localparam S_IDLE = 3'd0;
  localparam S_START = 3'd1;
  localparam S_DATA = 3'd2;
  localparam S_STOP = 3'd3;

  // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  reg [2:0] state;
  reg [15:0] cycle_cnt;
  reg [3:0] bit_cnt;
  reg [DATA_WIDTH-1:0] rx_temp;

  // 多数表决采样寄存器
  reg smp1, smp2, smp3;
  // 表决逻辑：3次采样中至少有2次为1，结果才为1；否则为0
  wire bit_val = (smp1 & smp2) | (smp1 & smp3) | (smp2 & smp3);

  // [Ethereal注释] 时序过程 2：由 i_clk_sys posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
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
      // [Ethereal注释] 分支选择 1：依据 state 选择状态或算法路径；default 覆盖非法或空闲条件。
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
