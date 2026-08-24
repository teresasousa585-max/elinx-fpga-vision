// =============================================================================
// 文件名称：sdram_control.v
// 主要模块：sdram_control
// 功能说明：实现 SDRAM 初始化、刷新、读写命令与数据时序。
// 维护说明：修改接口或时序时，请同步更新本文件注释和上层例化。
// =============================================================================

`timescale 1ns / 1ps

module sdram_control (
    input wire I_ref_clk,  // 参考时钟 (125MHz)
    input wire I_rst_n,    // 复位信号，低电平有效

    // ---------------- SDRAM 内部写请求 ----------------
    input wire I_sdram_wr_req,
    output wire O_sdram_wr_ack,
    input  wire [23:0] I_sdram_wr_addr,   // 强烈建议外部传入时，低9位严格为0，防止跨页
    input wire [9:0] I_sdram_wr_burst,  // 256，别随便改
    input wire [15:0] I_sdram_wr_data,

    // ---------------- SDRAM 内部读请求 ----------------
    input wire I_sdram_rd_req,
    output wire O_sdram_rd_ack,
    input  wire [23:0] I_sdram_rd_addr,   // 强烈建议外部传入时，低9位严格为0，防止跨页
    input wire [9:0] I_sdram_rd_burst,  // 256，别随便改
    output wire [15:0] O_sdram_rd_data,

    output reg O_sdram_init_done,

    // ---------------- SDRAM PHY 物理引脚 ----------------
    output wire        O_sdram_cke,
    output reg         O_sdram_cs_n,
    output reg         O_sdram_ras_n,
    output reg         O_sdram_cas_n,
    output reg         O_sdram_we_n,
    output reg  [ 1:0] O_sdram_bank,
    output reg  [12:0] O_sdram_addr,
    inout  wire [15:0] IO_sdram_dq
);

  // ========================================================
  // 时序参数配置 (125MHz下的最优参数，单位为时钟周期）
  // ========================================================
  localparam TRP = 3;
  localparam TRC = 8;
  localparam TRSC = 3;
  localparam TRCD = 3;
  localparam TCL = 3;
  localparam TWR = 2;
  localparam T_REF = 976;

  // 读数据采样物理潜伏期补偿 (根据布线情况，通常为 TCL 或 TCL+1)
  localparam RD_LATENCY = TCL + 1;

  // SDRAM 命令宏定义 {CS_N, RAS_N, CAS_N, WE_N}
  localparam CMD_LMR = 4'b0000;
  localparam CMD_ARF = 4'b0001;
  localparam CMD_PRE = 4'b0010;
  localparam CMD_ACT = 4'b0011;
  localparam CMD_WR = 4'b0100;
  localparam CMD_RD = 4'b0101;
  localparam CMD_NOP = 4'b0111;

  // 状态机定义
  localparam S_INIT_WAIT = 4'd0;
  localparam S_INIT_PRE = 4'd1;
  localparam S_INIT_ARF = 4'd2;
  localparam S_INIT_LMR = 4'd3;
  localparam S_IDLE = 4'd4;
  localparam S_WR = 4'd5;
  localparam S_RD = 4'd6;

  reg [ 3:0] state;
  reg [14:0] delay_cnt;
  reg [ 3:0] arf_cnt;

  // 刷新机制优化：使用挂起计数器，防止 256 长突发期间漏掉刷新
  reg [ 9:0] ref_timer;
  reg [ 3:0] ref_pending;

  reg        is_rd_flag;
  reg [ 1:0] active_bank;

  // 流水线追踪器
  reg [ 9:0] burst_remain;
  reg [ 9:0] current_col;

  assign O_sdram_cke = 1'b1;

  // ========================================================
  // 核心主状态机 (Auto-Precharge Pipeline FSM)
  // ========================================================
  always @(posedge I_ref_clk) begin
    if (!I_rst_n) begin
      state <= S_INIT_WAIT;
      delay_cnt <= 25000;  // 125MHz 上电等待 200us
      {O_sdram_cs_n, O_sdram_ras_n, O_sdram_cas_n, O_sdram_we_n} <= CMD_NOP;
      O_sdram_init_done <= 1'b0;

      ref_timer <= T_REF;
      ref_pending <= 4'd0;

      active_bank <= 2'b00;
      burst_remain <= 10'd0;
      current_col <= 10'd0;
    end else begin

      // ---------------- 定时刷新计时器 ----------------
      if (ref_timer > 0) begin
        ref_timer <= ref_timer - 1'b1;
      end else begin
        ref_timer <= T_REF;
        // 攒起未处理的刷新请求，最高挂起 15 次
        if (ref_pending < 4'd15) ref_pending <= ref_pending + 1'b1;
      end

      // ---------------- 延时阻塞与状态流转 ----------------
      if (delay_cnt > 0) begin
        delay_cnt <= delay_cnt - 1'b1;
        {O_sdram_cs_n, O_sdram_ras_n, O_sdram_cas_n, O_sdram_we_n} <= CMD_NOP;
      end else begin
        case (state)
          S_INIT_WAIT: begin
            {O_sdram_cs_n, O_sdram_ras_n, O_sdram_cas_n, O_sdram_we_n} <= CMD_PRE;
            O_sdram_addr <= 13'h1FFF;  // 预充电所有 Bank
            delay_cnt <= TRP;
            state <= S_INIT_ARF;
            arf_cnt <= 8;
          end

          S_INIT_ARF: begin
            if (arf_cnt > 0) begin
              {O_sdram_cs_n, O_sdram_ras_n, O_sdram_cas_n, O_sdram_we_n} <= CMD_ARF;
              delay_cnt <= TRC;
              arf_cnt <= arf_cnt - 1'b1;
            end else begin
              {O_sdram_cs_n, O_sdram_ras_n, O_sdram_cas_n, O_sdram_we_n} <= CMD_LMR;
              O_sdram_bank <= 2'b00;
              // CL=3, Burst Length = 8
              O_sdram_addr <= 13'h033;
              delay_cnt <= TRSC;
              state <= S_IDLE;
              O_sdram_init_done <= 1'b1;
            end
          end

          S_IDLE: begin
            if (ref_pending > 0) begin
              // 优先处理积压的刷新请求
              {O_sdram_cs_n, O_sdram_ras_n, O_sdram_cas_n, O_sdram_we_n} <= CMD_ARF;
              delay_cnt <= TRC;
              ref_pending <= ref_pending - 1'b1;  // 消耗一次请求
            end else if (I_sdram_wr_req) begin
              {O_sdram_cs_n, O_sdram_ras_n, O_sdram_cas_n, O_sdram_we_n} <= CMD_ACT;
              O_sdram_bank                                               <= I_sdram_wr_addr[23:22];
              active_bank                                                <= I_sdram_wr_addr[23:22];
              O_sdram_addr                                               <= I_sdram_wr_addr[21:9];
              delay_cnt                                                  <= TRCD - 1;
              burst_remain                                               <= I_sdram_wr_burst;
              current_col                                                <= I_sdram_wr_addr[8:0];
              state                                                      <= S_WR;
              is_rd_flag                                                 <= 1'b0;
            end else if (I_sdram_rd_req) begin
              {O_sdram_cs_n, O_sdram_ras_n, O_sdram_cas_n, O_sdram_we_n} <= CMD_ACT;
              O_sdram_bank                                               <= I_sdram_rd_addr[23:22];
              active_bank                                                <= I_sdram_rd_addr[23:22];
              O_sdram_addr                                               <= I_sdram_rd_addr[21:9];
              delay_cnt                                                  <= TRCD - 1;
              burst_remain                                               <= I_sdram_rd_burst;
              current_col                                                <= I_sdram_rd_addr[8:0];
              state                                                      <= S_RD;
              is_rd_flag                                                 <= 1'b1;
            end else begin
              {O_sdram_cs_n, O_sdram_ras_n, O_sdram_cas_n, O_sdram_we_n} <= CMD_NOP;
            end
          end

          S_WR: begin
            {O_sdram_cs_n, O_sdram_ras_n, O_sdram_cas_n, O_sdram_we_n} <= CMD_WR;
            O_sdram_bank <= active_bank;
            if (burst_remain <= 8) begin
              // 最后一次发送，A10设为1，开启自动预充电
              O_sdram_addr <= {2'b00, 1'b1, 1'b0, current_col[8:0]};
              // 延时 = 剩余写入周期 + 写恢复 + 预充电时间
              delay_cnt <= burst_remain + TWR + TRP - 1;
              state <= S_IDLE;
            end else begin
              // 连续流水线发送，A10设为0
              O_sdram_addr <= {2'b00, 1'b0, 1'b0, current_col[8:0]};
              delay_cnt <= 8 - 1;
              burst_remain <= burst_remain - 10'd8;
              current_col <= current_col + 10'd8;
              state <= S_WR;
            end
          end

          S_RD: begin
            {O_sdram_cs_n, O_sdram_ras_n, O_sdram_cas_n, O_sdram_we_n} <= CMD_RD;
            O_sdram_bank <= active_bank;
            if (burst_remain <= 8) begin
              // 最后一次读取，A10设为1，开启自动预充电
              O_sdram_addr <= {2'b00, 1'b1, 1'b0, current_col[8:0]};
              delay_cnt <= burst_remain + TCL + TRP - 1;
              state <= S_IDLE;
            end else begin
              // 连续流水线读取，A10设为0
              O_sdram_addr <= {2'b00, 1'b0, 1'b0, current_col[8:0]};
              delay_cnt <= 8 - 1;
              burst_remain <= burst_remain - 10'd8;
              current_col <= current_col + 10'd8;
              state <= S_RD;
            end
          end

          default: state <= S_IDLE;
        endcase
      end
    end
  end

  // ========================================================
  // Write Path (已加入 Normal FIFO 输出对齐机制)
  // ========================================================
  reg       wr_ack_r;
  reg [9:0] wr_data_cnt;
  reg       wr_out_en;

  assign O_sdram_wr_ack = wr_ack_r;

  always @(posedge I_ref_clk) begin
    if (!I_rst_n) begin
      wr_ack_r <= 1'b0;
      wr_data_cnt <= 10'd0;
      wr_out_en <= 1'b0;
    end else begin
      // 精确捕捉第一次发出 CMD_WR 的前一个周期，提早一拍通知 FIFO
      if (state == S_WR && !is_rd_flag && delay_cnt == 1 && burst_remain == I_sdram_wr_burst) begin
        wr_ack_r <= 1'b1;
        wr_data_cnt <= I_sdram_wr_burst - 1;
      end else if (wr_ack_r) begin
        if (wr_data_cnt > 0) wr_data_cnt <= wr_data_cnt - 1'b1;
        else wr_ack_r <= 1'b0;
      end

      // 完美平移 1 拍使能信号，为 FIFO 的内部 1 拍潜伏期买单，防止最后 1 个数据被截断
      wr_out_en <= wr_ack_r;
    end
  end

  // 使用平移后的使能信号驱动三态门
  assign IO_sdram_dq = (wr_out_en) ? I_sdram_wr_data : 16'hzzzz;

  // ========================================================
  // Read Path (匹配物理读取延迟)
  // ========================================================
  reg [ 9:0] rd_shift;
  reg        rd_ack_r;
  reg [ 9:0] rd_data_cnt;
  reg [15:0] rd_data_r;

  assign O_sdram_rd_ack  = rd_ack_r;
  assign O_sdram_rd_data = rd_data_r;

  always @(posedge I_ref_clk) begin
    if (!I_rst_n) begin
      rd_shift <= 10'd0;
      rd_ack_r <= 1'b0;
      rd_data_cnt <= 10'd0;
      rd_data_r <= 16'd0;
    end else begin
      // 捕捉发出 CMD_RD 的确切周期进行移位
      rd_shift <= {
        rd_shift[8:0], (state == S_RD && delay_cnt == 0 && burst_remain == I_sdram_rd_burst)
      };

      // 视物理布线而定，使用 RD_LATENCY 触发应答信号拉高，保证外部模块拿到干净有效的数据
      if (rd_shift[RD_LATENCY]) begin
        rd_ack_r <= 1'b1;
        rd_data_cnt <= I_sdram_rd_burst - 1;
      end else if (rd_ack_r) begin
        if (rd_data_cnt > 0) rd_data_cnt <= rd_data_cnt - 1'b1;
        else rd_ack_r <= 1'b0;
      end

      // 每个时钟沿锁存总线数据
      rd_data_r <= IO_sdram_dq;
    end
  end

endmodule
