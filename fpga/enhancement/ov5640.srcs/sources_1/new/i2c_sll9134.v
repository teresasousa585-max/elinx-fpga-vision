// =============================================================================
// 项目名称：2026 年全国大学生集成电路创新创业大赛国奖项目
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

module sii9134_i2c_init #(
    parameter CLK_FRE = 100
) (
    input wire i_clk,
    input wire i_rst,

    inout  wire io_i2c_scl,
    inout  wire io_i2c_sda,
    output reg  o_init_done,
    output reg  o_err
);

  localparam DEV_ADDR = 8'h76;
  localparam REG_NUM = 6;

  localparam DIV_CNT_MAX = (CLK_FRE * 1000000) / 400000 - 1;
  reg [15:0] clk_cnt;
  reg i2c_tick;

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

  reg [15:0] lut_data;
  reg [ 3:0] lut_index;
  always @(*) begin
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

  localparam S_IDLE = 4'd0;
  localparam S_START = 4'd1;
  localparam S_SEND_BYTE = 4'd2;
  localparam S_ACK = 4'd3;
  localparam S_STOP = 4'd4;
  localparam S_DONE = 4'd5;
  localparam S_STOP_ERR = 4'd6;  // 出错时释放总线
  localparam S_ERR_RETRY = 4'd7;  // 延时重试

  reg [ 3:0] state;
  reg [ 1:0] step;
  reg [ 3:0] bit_cnt;
  reg [ 1:0] byte_cnt;
  reg [ 7:0] shift_reg;
  reg [15:0] delay_cnt;

  reg r_scl, r_sda;
  //SCL 和 SDA 全部配置为纯开漏输出
  assign io_i2c_scl = r_scl ? 1'bz : 1'b0;
  assign io_i2c_sda = r_sda ? 1'bz : 1'b0;

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
