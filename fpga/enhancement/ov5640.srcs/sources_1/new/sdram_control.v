// =============================================================================
// 项目名称：2026 年全国大学生集成电路创新创业大赛国奖项目
// 作者：Ethereal
// 工程分区：图像增强工程（enhancement）
// 文件名称：sdram_control.v
// 主要模块：sdram_control
// 功能分类：帧缓存控制
// 功能说明：实现 SDRAM 上电初始化、自动刷新、突发读写和芯片引脚时序。
// 输入概述：读写时钟、FIFO 请求、帧地址、突发长度及待写像素数据。
// 输出概述：读出像素数据、SDRAM 命令/地址/数据和初始化完成状态。
// 时序约束：跨越视频与 SDRAM 时钟域；FIFO 清空、帧边界和突发握手必须保持同步。
// 关联文件：sdram_param.v、sdram_fifo_ctrl.v、sdram_top.v
// 维护要求：修改端口、位宽、流水线延迟或模式编码时，必须同步更新上层例化与项目文档。
// =============================================================================
`timescale 1ns / 1ps
//主要优化点：结合了多个模块综合一起，并且采用多个技术来提高SDRAM的带宽
// -----------------------------------------------------------------------------
// [Ethereal注释] 正文导读：实现 SDRAM 上电初始化、自动刷新、突发读写和芯片引脚时序。
// [Ethereal注释] 阅读顺序：先确认参数和端口，再沿内部信号、时序过程及子模块例化追踪数据流。
// [Ethereal注释] 修改约束：读写地址、突发长度、FIFO 清空和跨时钟握手必须保持一致，避免帧错位或数据溢出。
// -----------------------------------------------------------------------------
// [Ethereal注释] 模块 sdram_control：以下接口构成综合边界，上层通过端口连接数据流、控制流和状态信号。
module sdram_control (
    // [Ethereal注释] 接口信号：input 接收上游数据/控制，output 返回处理结果/状态，inout 连接双向器件总线。
    input wire I_ref_clk,  // 参考时钟 (125MHz)
    input wire I_rst_n,    // 复位信号，低电平有效

    // ---------------- SDRAM 内部写请求 ----------------
    input  wire        I_sdram_wr_req,
    output wire        O_sdram_wr_ack,
    input  wire [23:0] I_sdram_wr_addr,
    input  wire [ 9:0] I_sdram_wr_burst,  //256，别随便改
    input  wire [15:0] I_sdram_wr_data,

    // ---------------- SDRAM 内部读请求 ----------------
    input  wire        I_sdram_rd_req,
    output wire        O_sdram_rd_ack,
    input  wire [23:0] I_sdram_rd_addr,
    input  wire [ 9:0] I_sdram_rd_burst,  //256，别随便改
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

  // 时序参数配置 (125MHz下的最优参数，单位为时钟周期）
  // [Ethereal注释] 参数配置：综合期确定位宽、容量、频率或算法强度，修改后需重新验证资源和时序。
  localparam TRP = 3;
  localparam TRC = 8;
  localparam TRSC = 3;
  localparam TRCD = 3;
  localparam TCL = 3;
  localparam TWR = 2;
  localparam T_REF = 976;

  // SDRAM 命令宏定义 {CS_N, RAS_N, CAS_N, WE_N}
  localparam CMD_LMR = 4'b0000;
  localparam CMD_ARF = 4'b0001;
  localparam CMD_PRE = 4'b0010;
  localparam CMD_ACT = 4'b0011;
  localparam CMD_WR = 4'b0100;
  localparam CMD_RD = 4'b0101;
  localparam CMD_NOP = 4'b0111;

  // 状态机定义 (去掉冗余等待状态)
  localparam S_INIT_WAIT = 4'd0;
  localparam S_INIT_PRE = 4'd1;
  localparam S_INIT_ARF = 4'd2;
  localparam S_INIT_LMR = 4'd3;
  localparam S_IDLE = 4'd4;
  localparam S_WR = 4'd5;
  localparam S_RD = 4'd6;

  // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  reg [ 3:0] state;
  reg [14:0] delay_cnt;
  reg [ 3:0] arf_cnt;
  reg [ 9:0] ref_timer;
  reg        ref_req;
  reg        is_rd_flag;
  reg [ 1:0] active_bank;

  // 流水线追踪器
  reg [ 9:0] burst_remain;
  reg [ 9:0] current_col;

  // [Ethereal注释] 组合连线组 1：从 O_sdram_cke 开始的连续赋值随右值立即更新，不增加寄存器延迟。
  assign O_sdram_cke = 1'b1;

  // 核心主状态机 (Auto-Precharge Pipeline FSM)
  // [Ethereal注释] 时序过程 1：由 I_ref_clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
  always @(posedge I_ref_clk) begin
    if (!I_rst_n) begin
      state <= S_INIT_WAIT;
      delay_cnt <= 25000;  // 125MHz 上电等待 200us
      {O_sdram_cs_n, O_sdram_ras_n, O_sdram_cas_n, O_sdram_we_n} <= CMD_NOP;
      O_sdram_init_done <= 1'b0;
      ref_timer <= T_REF;
      ref_req <= 1'b0;
      active_bank <= 2'b00;
      burst_remain <= 10'd0;
      current_col <= 10'd0;
    end else begin
      if (ref_timer > 0) ref_timer <= ref_timer - 1'b1;
      else begin
        ref_timer <= T_REF;
        ref_req   <= 1'b1;
      end

      if (delay_cnt > 0) begin
        delay_cnt <= delay_cnt - 1'b1;
        {O_sdram_cs_n, O_sdram_ras_n, O_sdram_cas_n, O_sdram_we_n} <= CMD_NOP;
      end else begin
        // [Ethereal注释] 分支选择 1：依据 state 选择状态或算法路径；default 覆盖非法或空闲条件。
        case (state)
          S_INIT_WAIT: begin
            {O_sdram_cs_n, O_sdram_ras_n, O_sdram_cas_n, O_sdram_we_n} <= CMD_PRE;
            O_sdram_addr <= 13'h1FFF;
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
              // 核心：CL=3, Burst Length = 8
              O_sdram_addr <= 13'h033;
              delay_cnt <= TRSC;
              state <= S_IDLE;
              O_sdram_init_done <= 1'b1;
            end
          end

          S_IDLE: begin
            if (ref_req) begin
              {O_sdram_cs_n, O_sdram_ras_n, O_sdram_cas_n, O_sdram_we_n} <= CMD_ARF;
              delay_cnt <= TRC;
              ref_req <= 1'b0;
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
              // 核心：最后一次发送，A10设为1，开启自动预充电
              O_sdram_addr <= {2'b00, 1'b1, 1'b0, current_col[8:0]};
              // 延时 = 剩余写入周期 + 写恢复 + 预充电时间
              delay_cnt <= burst_remain + TWR + TRP - 1;
              state <= S_IDLE;  // 直接跳回 IDLE，隐藏预充电时间
            end else begin
              // 连续流水线发送，A10设为0
              O_sdram_addr <= {2'b00, 1'b0, 1'b0, current_col[8:0]};
              delay_cnt <= 8 - 1;  // 间隔刚好 8 拍，数据总线 0 缝隙
              burst_remain <= burst_remain - 10'd8;
              current_col <= current_col + 10'd8;
              state <= S_WR;
            end
          end

          S_RD: begin
            {O_sdram_cs_n, O_sdram_ras_n, O_sdram_cas_n, O_sdram_we_n} <= CMD_RD;
            O_sdram_bank <= active_bank;
            if (burst_remain <= 8) begin
              // 最后一次读取，A10设为1，自动预充电
              O_sdram_addr <= {2'b00, 1'b1, 1'b0, current_col[8:0]};
              // 延时 = 读取周期 + 潜伏期 (等待总线空闲) + 安全余量
              delay_cnt <= burst_remain + TCL + TRP - 1;
              state <= S_IDLE;
            end else begin
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

  // Write Path (适配 Normal FIFO，超前预取1拍)
  // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  reg       wr_ack_r;
  reg [9:0] wr_data_cnt;

  // [Ethereal注释] 组合连线组 1：从 O_sdram_wr_ack 开始的连续赋值随右值立即更新，不增加寄存器延迟。
  assign O_sdram_wr_ack = wr_ack_r;

  // [Ethereal注释] 时序过程 2：由 I_ref_clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
  always @(posedge I_ref_clk) begin
    if (!I_rst_n) begin
      wr_ack_r <= 1'b0;
      wr_data_cnt <= 10'd0;
    end else begin
      // 精确捕捉第一次发出 CMD_WR 的前一个周期
      if (state == S_WR && !is_rd_flag && delay_cnt == 1 && burst_remain == I_sdram_wr_burst) begin
        wr_ack_r <= 1'b1;
        wr_data_cnt <= I_sdram_wr_burst - 1;
      end else if (wr_ack_r) begin
        if (wr_data_cnt > 0) wr_data_cnt <= wr_data_cnt - 1'b1;
        else wr_ack_r <= 1'b0;
      end
    end
  end

  // [Ethereal注释] 组合连线组 1：从 IO_sdram_dq 开始的连续赋值随右值立即更新，不增加寄存器延迟。
  assign IO_sdram_dq = (wr_ack_r) ? I_sdram_wr_data : 16'hzzzz;

  // Read Path (匹配 TCL 潜伏期)
  // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  reg [ 9:0] rd_shift;
  reg        rd_ack_r;
  reg [ 9:0] rd_data_cnt;
  reg [15:0] rd_data_r;

  // [Ethereal注释] 组合连线组 1：从 O_sdram_rd_ack 开始的连续赋值随右值立即更新，不增加寄存器延迟。
  assign O_sdram_rd_ack  = rd_ack_r;
  assign O_sdram_rd_data = rd_data_r;

  // [Ethereal注释] 时序过程 3：由 I_ref_clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
  always @(posedge I_ref_clk) begin
    if (!I_rst_n) begin
      rd_shift <= 10'd0;
      rd_ack_r <= 1'b0;
      rd_data_cnt <= 10'd0;
      rd_data_r <= 16'd0;
    end else begin
      // 精确捕捉第一次发出 CMD_RD 的那个周期
      rd_shift <= {
        rd_shift[8:0], (state == S_RD && delay_cnt == 0 && burst_remain == I_sdram_rd_burst)
      };

      if (rd_shift[TCL]) begin
        rd_ack_r <= 1'b1;
        rd_data_cnt <= I_sdram_rd_burst - 1;
      end else if (rd_ack_r) begin
        if (rd_data_cnt > 0) rd_data_cnt <= rd_data_cnt - 1'b1;
        else rd_ack_r <= 1'b0;
      end

      rd_data_r <= IO_sdram_dq;
    end
  end

endmodule
