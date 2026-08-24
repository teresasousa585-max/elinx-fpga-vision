// =============================================================================
// 项目名称：2026 年全国大学生集成电路创新创业大赛国奖项目
// 作者：Ethereal
// 工程分区：图像增强工程（enhancement）
// 文件名称：i2c_sll9134.v
// 主要模块：sii9134_i2c_init
// 功能分类：显示接口
// 功能说明：通过 I2C 初始化 SII9134 HDMI 发送器寄存器。
// 输入概述：外设时钟、同步/像素数据或待显示视频流。
// 输出概述：初始化控制、规范化视频流或板级显示接口信号。
// 时序约束：外设接口遵循对应器件时序；进入算法通路前须保持 HS/VS/DE 与像素对齐。
// 关联文件：hdmi.v、top.v
// 维护要求：修改端口、位宽、流水线延迟或模式编码时，必须同步更新上层例化与项目文档。
// =============================================================================
`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// [Ethereal注释] 正文导读：通过 I2C 初始化 SII9134 HDMI 发送器寄存器。
// [Ethereal注释] 阅读顺序：先确认参数和端口，再沿内部信号、时序过程及子模块例化追踪数据流。
// [Ethereal注释] 修改约束：协议字段、有效脉冲和跨时钟控制必须成组更新，并与上位机及外设时序保持一致。
// -----------------------------------------------------------------------------
// [Ethereal注释] 模块 sii9134_i2c_init：以下接口构成综合边界，上层通过端口连接数据流、控制流和状态信号。
module sii9134_i2c_init #(
    // [Ethereal注释] 参数配置：综合期确定位宽、容量、频率或算法强度，修改后需重新验证资源和时序。
    parameter CLK_FRE = 100
) (
    // [Ethereal注释] 接口信号：input 接收上游数据/控制，output 返回处理结果/状态，inout 连接双向器件总线。
    input wire i_clk,
    input wire i_rst,

    inout  wire io_i2c_scl,
    inout  wire io_i2c_sda,
    output reg  o_init_done,
    output reg  o_err
);

  // [Ethereal注释] 参数配置：综合期确定位宽、容量、频率或算法强度，修改后需重新验证资源和时序。
  localparam DEV_ADDR = 8'h76;
  localparam REG_NUM = 6;

  localparam DIV_CNT_MAX = (CLK_FRE * 1000000) / 400000 - 1;
  // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  reg [15:0] clk_cnt;
  reg i2c_tick;

  // [Ethereal注释] 时序过程 1：由 i_clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
  always @(posedge i_clk) begin
    if (i_rst) begin
      clk_cnt  <= 0;
      i2c_tick <= 0;
    end else if (clk_cnt == DIV_CNT_MAX) begin
      clk_cnt  <= 0;
      i2c_tick <= 1'b1;
    end else begin
      clk_cnt  <= clk_cnt + 1'b1;
      i2c_tick <= 1'b0;
    end
  end

  // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  reg [15:0] lut_data;
  reg [ 3:0] lut_index;
  // [Ethereal注释] 组合过程 1：根据当前输入/状态计算结果；所有输出须在各分支完整赋值以避免锁存器。
  always @(*) begin
    // [Ethereal注释] 分支选择 1：依据 lut_index 选择状态或算法路径；default 覆盖非法或空闲条件。
    case (lut_index)
      4'd0: lut_data = {8'h08, 8'h35};
      4'd1: lut_data = {8'h09, 8'h00};
      4'd2: lut_data = {8'h0A, 8'h06};
      4'd3: lut_data = {8'h0C, 8'h00};
      4'd4: lut_data = {8'h1A, 8'h00};
      4'd5: lut_data = {8'h2F, 8'h00};
      default: lut_data = 16'h0000;
    endcase
  end

  // [Ethereal注释] 参数配置：综合期确定位宽、容量、频率或算法强度，修改后需重新验证资源和时序。
  localparam S_IDLE = 4'd0;
  localparam S_START = 4'd1;
  localparam S_SEND_BYTE = 4'd2;
  localparam S_ACK = 4'd3;
  localparam S_STOP = 4'd4;
  localparam S_DONE = 4'd5;
  localparam S_STOP_ERR = 4'd6;  // 出错时释放总线
  localparam S_ERR_RETRY = 4'd7;  // 延时重试

  // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  reg [ 3:0] state;
  reg [ 1:0] step;
  reg [ 3:0] bit_cnt;
  reg [ 1:0] byte_cnt;
  reg [ 7:0] shift_reg;
  reg [15:0] delay_cnt;

  reg r_scl, r_sda;
  //SCL 和 SDA 全部配置为纯开漏输出
  // [Ethereal注释] 组合连线组 1：从 io_i2c_scl 开始的连续赋值随右值立即更新，不增加寄存器延迟。
  assign io_i2c_scl = r_scl ? 1'bz : 1'b0;
  assign io_i2c_sda = r_sda ? 1'bz : 1'b0;

  // [Ethereal注释] 时序过程 2：由 i_clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
  always @(posedge i_clk) begin
    if (i_rst) begin
      state       <= S_IDLE;
      step        <= 0;
      bit_cnt     <= 0;
      byte_cnt    <= 0;
      lut_index   <= 0;
      r_scl       <= 1'b1;
      r_sda       <= 1'b1;
      o_init_done <= 1'b0;
      o_err       <= 1'b0;
      delay_cnt   <= 0;
    end else if (i2c_tick) begin
      // [Ethereal注释] 分支选择 2：依据 state 选择状态或算法路径；default 覆盖非法或空闲条件。
      case (state)
        S_IDLE: begin
          r_scl <= 1'b1;
          r_sda <= 1'b1;
          o_err <= 1'b0;
          if (delay_cnt < 16'd4000) begin
            delay_cnt <= delay_cnt + 1'b1;
          end else if (lut_index < REG_NUM) begin
            state    <= S_START;
            step     <= 0;
            byte_cnt <= 0;
          end else begin
            state       <= S_DONE;
            o_init_done <= 1'b1;
          end
        end

        S_START: begin
          // [Ethereal注释] 分支选择 3：依据 step 选择状态或算法路径；default 覆盖非法或空闲条件。
          case (step)
            0: begin
              r_scl <= 1'b1;
              r_sda <= 1'b1;
              step  <= 1;
            end
            1: begin
              r_scl <= 1'b1;
              r_sda <= 1'b0;
              step  <= 2;
            end
            2: begin
              r_scl <= 1'b0;
              r_sda <= 1'b0;
              step  <= 3;
            end
            3: begin
              state <= S_SEND_BYTE;
              step <= 0;
              bit_cnt <= 7;
              if (byte_cnt == 0) shift_reg <= DEV_ADDR;
              else if (byte_cnt == 1) shift_reg <= lut_data[15:8];
              else shift_reg <= lut_data[7:0];
            end
          endcase
        end

        S_SEND_BYTE: begin
          // [Ethereal注释] 分支选择 4：依据 step 选择状态或算法路径；default 覆盖非法或空闲条件。
          case (step)
            0: begin
              r_scl <= 1'b0;
              r_sda <= shift_reg[bit_cnt];
              step  <= 1;
            end
            1: begin
              r_scl <= 1'b1;
              step  <= 2;
            end
            2: begin
              r_scl <= 1'b1;
              step  <= 3;
            end
            3: begin
              r_scl <= 1'b0;
              if (bit_cnt == 0) begin
                state <= S_ACK;
                step  <= 0;
              end else begin
                bit_cnt <= bit_cnt - 1'b1;
                step    <= 0;
              end
            end
          endcase
        end

        S_ACK: begin
          // [Ethereal注释] 分支选择 5：依据 step 选择状态或算法路径；default 覆盖非法或空闲条件。
          case (step)
            0: begin
              r_scl <= 1'b0;
              r_sda <= 1'b1;
              step  <= 1;
            end
            1: begin
              r_scl <= 1'b1;
              step  <= 2;
            end
            2: begin
              r_scl <= 1'b1;
              if (io_i2c_sda == 1'b1) begin
                o_err <= 1'b1;
              end
              step <= 3;
            end
            3: begin
              r_scl <= 1'b0;
              if (o_err) begin
                state <= S_STOP_ERR;  // NACK发生，跳转去安全释放总线
              end else begin
                if (byte_cnt == 2) begin
                  state <= S_STOP;
                end else begin
                  state <= S_SEND_BYTE;
                  byte_cnt <= byte_cnt + 1'b1;
                  bit_cnt <= 7;
                  if (byte_cnt == 0) shift_reg <= lut_data[15:8];
                  else shift_reg <= lut_data[7:0];
                end
              end
              step <= 0;
            end
          endcase
        end

        // 正常的完成一次寄存器写入
        S_STOP: begin
          // [Ethereal注释] 分支选择 6：依据 step 选择状态或算法路径；default 覆盖非法或空闲条件。
          case (step)
            0: begin
              r_scl <= 1'b0;
              r_sda <= 1'b0;
              step  <= 1;
            end
            1: begin
              r_scl <= 1'b1;
              r_sda <= 1'b0;
              step  <= 2;
            end
            2: begin
              r_scl <= 1'b1;
              r_sda <= 1'b1;
              step  <= 3;
            end
            3: begin
              lut_index <= lut_index + 1'b1;
              state <= S_IDLE;
              step <= 0;
            end
          endcase
        end

        // 报错后的总线安全释放
        S_STOP_ERR: begin
          // [Ethereal注释] 分支选择 7：依据 step 选择状态或算法路径；default 覆盖非法或空闲条件。
          case (step)
            0: begin
              r_scl <= 1'b0;
              r_sda <= 1'b0;
              step  <= 1;
            end
            1: begin
              r_scl <= 1'b1;
              r_sda <= 1'b0;
              step  <= 2;
            end
            2: begin
              r_scl <= 1'b1;
              r_sda <= 1'b1;
              step  <= 3;
            end
            3: begin
              state <= S_ERR_RETRY;
              step <= 0;
              delay_cnt <= 0;
            end
          endcase
        end

        // 延时100毫秒后自动再次尝试写入该寄存器
        S_ERR_RETRY: begin
          r_scl <= 1'b1;
          r_sda <= 1'b1;
          if (delay_cnt < 16'd40_000) begin
            delay_cnt <= delay_cnt + 1'b1;
          end else begin
            state <= S_START;
            step <= 0;
            byte_cnt <= 0;
            o_err <= 1'b0;  // 清除错误标志，重新尝试
          end
        end

        S_DONE: begin
          r_scl <= 1'b1;
          r_sda <= 1'b1;
        end
        default: state <= S_IDLE;
      endcase
    end
  end
endmodule
