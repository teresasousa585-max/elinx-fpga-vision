// =============================================================================
// 项目名称：2026 年全国大学生集成电路创新创业大赛国奖项目
// 工程分区：基础图像处理工程（base）
// 文件名称：sdram_fifo_ctrl.v
// 主要模块：sdram_fifo_ctrl
// 功能分类：帧缓存控制
// 功能说明：协调异步读写 FIFO、突发地址和帧边界，连接视频时钟域与 SDRAM 时钟域。
// 输入概述：读写时钟、FIFO 请求、帧地址、突发长度及待写像素数据。
// 输出概述：读出像素数据、SDRAM 命令/地址/数据和初始化完成状态。
// 时序约束：跨越视频与 SDRAM 时钟域；FIFO 清空、帧边界和突发握手必须保持同步。
// 关联文件：sdram_control.v、sdram_top.v、读写 FIFO IP
// 维护要求：修改端口、位宽、流水线延迟或模式编码时，必须同步更新上层例化与项目文档。
// =============================================================================
`timescale 1ns / 1ps

module sdram_fifo_ctrl (
    input wire I_ref_clk,  // 参考时钟
    input wire I_rst_n,    // 系统复位,低电平有效

    // 写部分:外部-->FIFO
    input wire        I_fifo_wr_clk,   // fifo写时钟
    input wire        I_fifo_wr_req,   // 写入fifo请求
    input wire [15:0] I_fifo_wr_data,  // 写入fifo的数据
    input wire [23:0] I_wr_saddr,      // 写入sdram的起始地址
    input wire [23:0] I_wr_eaddr,      // 写入sdram的终止地址
    input wire [11:0] I_wr_brust,      // 写入sdram的突发长度
    input wire        I_fifo_wr_load,  // 写入fifo数据清空

    // wr_fifo:FIFO(写)-->SDRAM(读)
    output reg         O_sdram_wr_req,   // 数据写入sdram写请求
    input  wire        I_sdram_wr_ack,   // 数据写入sdram写响应
    output reg  [23:0] O_sdram_wr_addr,  // 写数据进sdram的地址
    output wire [15:0] O_sdram_wr_data,  // 写入sdram的数据

    // rd_fifo:SDRAM(写)-->FIFO(读)
    output reg         O_sdram_rd_req,   // 数据读出sdram读请求
    input  wire        I_sdram_rd_ack,   // 数据读出sdram读响应
    output reg  [23:0] O_sdram_rd_addr,  // 读数据进fifo的地址
    input  wire [15:0] I_sdram_rd_data,  // 读入fifo的数据

    // 读部分:FIFO-->外部
    input  wire        I_fifo_rd_clk,   // 数据读出fifo读时钟
    input  wire        I_fifo_rd_req,   // 数据读出fifo读请求
    output wire [15:0] O_fifo_rd_data,  // 读出fifo的数据
    input  wire [23:0] I_rd_saddr,      // 读出sdram的起始地址
    input  wire [23:0] I_rd_eaddr,      // 读出sdram的终止地址
    input  wire [11:0] I_rd_brust,      // 读出sdram的突发长度
    input  wire        I_fifo_rd_load,  // 读出fifo数据清空

    // sdram
    input wire I_sdram_init_done,   // sdram初始化完成
    input wire I_sdram_rd_valid,    // sdram数据读使能
    input wire I_sdram_pingpang_en  // sdram乒乓操作使能
);

  // 写fifo数据清空信号缓存
  reg fifo_wr_load_r1;
  reg fifo_wr_load_r2;
  // 读fifo数据清空缓存
  reg fifo_rd_load_r1;
  reg fifo_rd_load_r2;
  // sdram写响应信号缓存
  reg sdram_wr_ack1;
  reg sdram_wr_ack2;
  // sdram读响应信号缓存
  reg sdram_rd_ack1;
  reg sdram_rd_ack2;
  // sdram读使能信号
  reg sdram_rd_valid1;
  reg sdram_rd_valid2;

  // 写fifo数据清空信号上升沿
  wire fifo_wr_load_p;
  // 读fifo数据清空信号上升沿
  wire fifo_rd_load_p;
  // 写sdram响应信号下降沿
  wire sdram_wr_ack_n;
  // 读sdram响应信号下降沿
  wire sdram_rd_ack_n;

  // sdram_wr_fifo
  wire [11:0] wr_fifo_use;
  // sdram_rd_fifo
  wire [11:0] rd_fifo_use;

  // -------------------------------------------------------------
  // 信号打拍与边沿检测
  // -------------------------------------------------------------
  always @(posedge I_ref_clk or negedge I_rst_n) begin
    if (I_rst_n == 1'b0) begin
      fifo_wr_load_r1 <= 1'b0;
      fifo_wr_load_r2 <= 1'b0;
    end else begin
      fifo_wr_load_r1 <= I_fifo_wr_load;
      fifo_wr_load_r2 <= fifo_wr_load_r1;
    end
  end

  always @(posedge I_ref_clk or negedge I_rst_n) begin
    if (I_rst_n == 1'b0) begin
      fifo_rd_load_r1 <= 1'b0;
      fifo_rd_load_r2 <= 1'b0;
    end else begin
      fifo_rd_load_r1 <= I_fifo_rd_load;
      fifo_rd_load_r2 <= fifo_rd_load_r1;
    end
  end

  always @(posedge I_ref_clk or negedge I_rst_n) begin
    if (I_rst_n == 1'b0) begin
      sdram_wr_ack1 <= 1'b0;
      sdram_wr_ack2 <= 1'b0;
    end else begin
      sdram_wr_ack1 <= I_sdram_wr_ack;
      sdram_wr_ack2 <= sdram_wr_ack1;
    end
  end

  always @(posedge I_ref_clk or negedge I_rst_n) begin
    if (I_rst_n == 1'b0) begin
      sdram_rd_ack1 <= 1'b0;
      sdram_rd_ack2 <= 1'b0;
    end else begin
      sdram_rd_ack1 <= I_sdram_rd_ack;
      sdram_rd_ack2 <= sdram_rd_ack1;
    end
  end

  always @(posedge I_ref_clk or negedge I_rst_n) begin
    if (I_rst_n == 1'b0) begin
      sdram_rd_valid1 <= 1'b0;
      sdram_rd_valid2 <= 1'b0;
    end else begin
      sdram_rd_valid1 <= I_sdram_rd_valid;
      sdram_rd_valid2 <= sdram_rd_valid1;
    end
  end

  // 边沿提取赋值
  assign fifo_wr_load_p = (~fifo_wr_load_r2) & fifo_wr_load_r1;
  assign fifo_rd_load_p = (~fifo_rd_load_r2) & fifo_rd_load_r1;
  assign sdram_wr_ack_n = sdram_wr_ack2 & (~sdram_wr_ack1);
  assign sdram_rd_ack_n = sdram_rd_ack2 & (~sdram_rd_ack1);

  // =========================================================================
  // ? 核心时序优化：增加寄存器斩断过长的组合逻辑
  // 将地址减法单独流水一级，为组合运算提供完整时钟周期并改善时序裕量。
  // =========================================================================
  reg [23:0] wr_end_threshold;
  reg [23:0] rd_end_threshold;
  always @(posedge I_ref_clk or negedge I_rst_n) begin
    if (!I_rst_n) begin
      wr_end_threshold <= 24'd0;
      rd_end_threshold <= 24'd0;
    end else begin
      wr_end_threshold <= I_wr_eaddr - I_wr_brust;
      rd_end_threshold <= I_rd_eaddr - I_rd_brust;
    end
  end

  // 乒乓操作 - 写入地址逻辑 (基于帧脉冲强制切换)
  reg rw_bank_flag;  // 0:写Bank0, 1:写Bank1

  always @(posedge I_ref_clk or negedge I_rst_n) begin
    if (I_rst_n == 1'b0) begin
      O_sdram_wr_addr <= 24'd0;
      rw_bank_flag    <= 1'b0;
    end else if (fifo_wr_load_p) begin
      // 收到摄像头新一帧起点的瞬间，强制翻转Bank标志
      if (I_sdram_pingpang_en) begin
        O_sdram_wr_addr <= {~rw_bank_flag, I_wr_saddr[22:0]};
        rw_bank_flag    <= ~rw_bank_flag;
      end else begin
        O_sdram_wr_addr <= I_wr_saddr;
      end
    end else if (sdram_wr_ack_n) begin
      // ? 核心修改：使用提前算好的寄存器 wr_end_threshold，代替动态减法
      if (O_sdram_wr_addr[22:0] < wr_end_threshold[22:0]) begin
        O_sdram_wr_addr <= O_sdram_wr_addr + I_wr_brust;
      end else begin
        // 本帧如果提前写满，地址回卷到当前Bank的头部等待下一帧
        O_sdram_wr_addr <= {O_sdram_wr_addr[23], I_wr_saddr[22:0]};
      end
    end
  end

  // 乒乓操作 - 读取地址逻辑
  always @(posedge I_ref_clk or negedge I_rst_n) begin
    if (I_rst_n == 1'b0) begin
      O_sdram_rd_addr <= 24'd0;
    end else if (fifo_rd_load_p) begin
      // 收到HDMI新帧起点时，去读摄像头上一次完整写完的Bank（即非正在写的Bank）
      if (I_sdram_pingpang_en) begin
        O_sdram_rd_addr <= {~rw_bank_flag, I_rd_saddr[22:0]};
      end else begin
        O_sdram_rd_addr <= I_rd_saddr;
      end
    end else if (sdram_rd_ack_n) begin
      // ???? 核心修改：使用提前算好的寄存器 rd_end_threshold，代替动态减法
      if (O_sdram_rd_addr[22:0] < rd_end_threshold[22:0]) begin
        O_sdram_rd_addr <= O_sdram_rd_addr + I_rd_brust;
      end else begin
        O_sdram_rd_addr <= {O_sdram_rd_addr[23], I_rd_saddr[22:0]};
      end
    end
  end

  // SDRAM 读写请求产生模块
  always @(posedge I_ref_clk or negedge I_rst_n) begin
    if (I_rst_n == 1'b0) begin
      O_sdram_wr_req <= 1'b0;
      O_sdram_rd_req <= 1'b0;
    end else if (I_sdram_init_done) begin
      // 将读请求(HDMI)放在第一位,绝对保证视频流不断供
      //注意：经过无数次尝试，这里rd_fifo_use < I_wr_brust不能有任何修改！
      if ((rd_fifo_use < I_wr_brust) && sdram_rd_valid2) begin
        O_sdram_rd_req <= 1'b1;
        O_sdram_wr_req <= 1'b0;
      end  // 读请求满足后，才处理写请求(摄像头)
      else if (wr_fifo_use >= I_wr_brust) begin
        O_sdram_wr_req <= 1'b1;
        O_sdram_rd_req <= 1'b0;
      end else begin
        O_sdram_wr_req <= 1'b0;
        O_sdram_rd_req <= 1'b0;
      end
    end else begin
      O_sdram_wr_req <= 1'b0;
      O_sdram_rd_req <= 1'b0;
    end
  end

  // 核心时序优化：纯寄存器直驱的单脉冲异步复位
  // 利用 D 触发器的异步复位端吸收全局 I_rst_n，消灭组合逻辑（天才！ BY Ethereal）
  reg wr_fifo_aclr_reg;
  reg rd_fifo_aclr_reg;

  always @(posedge I_ref_clk or negedge I_rst_n) begin
    if (!I_rst_n) begin
      // 1. 全局硬件复位时，寄存器被异步置 1，传递给 FIFO
      wr_fifo_aclr_reg <= 1'b1;
      rd_fifo_aclr_reg <= 1'b1;
    end else begin
      // 2. 正常工作时，抓取 1 个周期的单脉冲 (不展宽，不丢像素)
      wr_fifo_aclr_reg <= fifo_wr_load_p;
      rd_fifo_aclr_reg <= fifo_rd_load_p;
    end
  end

  wire wr_fifo_aclr_global;
  wire rd_fifo_aclr_global;

  //使用 Altera/亿海微 体系的全局信号原语
  GLOBAL u_global_wr (
      .in (wr_fifo_aclr_reg),
      .out(wr_fifo_aclr_global)
  );

  GLOBAL u_global_rd (
      .in (rd_fifo_aclr_reg),
      .out(rd_fifo_aclr_global)
  );

  // FIFO 例化：只接这根纯净的寄存器线
  sdram_wr_fifo sdram_wr_fifo_inst (
      .wrclk  (I_fifo_wr_clk),
      .wrreq  (I_fifo_wr_req),
      .data   (I_fifo_wr_data),
      .rdclk  (I_ref_clk),
      .rdreq  (I_sdram_wr_ack),
      .q      (O_sdram_wr_data),
      .aclr   (wr_fifo_aclr_global),  // 无组合逻辑
      .rdusedw(wr_fifo_use)
  );

  sdram_rd_fifo sdram_rd_fifo_inst (
      .wrclk  (I_ref_clk),
      .wrreq  (I_sdram_rd_ack),
      .data   (I_sdram_rd_data),
      .rdclk  (I_fifo_rd_clk),
      .rdreq  (I_fifo_rd_req),
      .q      (O_fifo_rd_data),
      .aclr   (rd_fifo_aclr_global),  // 无组合逻辑
      .wrusedw(rd_fifo_use)
  );

endmodule

// `timescale 1ns / 1ps

// module sdram_fifo_ctrl (
//     input wire I_ref_clk,  // 参考时钟 [cite: 1]
//     input wire I_rst_n,    // 系统复位,低电平有效 [cite: 1]

//     // 写部分:外部-->FIFO [cite: 1]
//     input wire        I_fifo_wr_clk,   // fifo写时钟 [cite: 1]
//     input wire        I_fifo_wr_req,   // 写入fifo请求 [cite: 1]
//     input wire [15:0] I_fifo_wr_data,  // 写入fifo的数据 [cite: 1]
//     input wire [23:0] I_wr_saddr,      // 写入sdram的起始地址 [cite: 1]
//     input wire [23:0] I_wr_eaddr,      // 写入sdram的终止地址 [cite: 1, 2]
//     input wire [11:0] I_wr_brust,      // 写入sdram的突发长度 [cite: 2]
//     input wire        I_fifo_wr_load,  // 写入fifo数据清空 [cite: 2]

//     // wr_fifo:FIFO(写)-->SDRAM(读) [cite: 2]
//     output reg         O_sdram_wr_req,   // 数据写入sdram写请求 [cite: 2]
//     input  wire        I_sdram_wr_ack,   // 数据写入sdram写响应 [cite: 2]
//     output reg  [23:0] O_sdram_wr_addr,  // 写数据进sdram的地址 [cite: 2]
//     output wire [15:0] O_sdram_wr_data,  // 写入sdram的数据 [cite: 2]

//     // rd_fifo:SDRAM(写)-->FIFO(读) [cite: 2]
//     output reg         O_sdram_rd_req,   // 数据读出sdram读请求 [cite: 3]
//     input  wire        I_sdram_rd_ack,   // 数据读出sdram读响应 [cite: 3]
//     output reg  [23:0] O_sdram_rd_addr,  // 读数据进fifo的地址 [cite: 3]
//     input  wire [15:0] I_sdram_rd_data,  // 读入fifo的数据 [cite: 3]

//     // 读部分:FIFO-->外部 [cite: 3]
//     input  wire        I_fifo_rd_clk,   // 数据读出fifo读时钟 [cite: 3]
//     input  wire        I_fifo_rd_req,   // 数据读出fifo读请求 [cite: 3]
//     output wire [15:0] O_fifo_rd_data,  // 读出fifo的数据 [cite: 4]
//     input  wire [23:0] I_rd_saddr,      // 读出sdram的起始地址 [cite: 4]
//     input  wire [23:0] I_rd_eaddr,      // 读出sdram的终止地址 [cite: 4]
//     input  wire [11:0] I_rd_brust,      // 读出sdram的突发长度 [cite: 4]
//     input  wire        I_fifo_rd_load,  // 读出fifo数据清空 [cite: 4]

//     // sdram [cite: 4]
//     input wire I_sdram_init_done,   // sdram初始化完成 [cite: 4]
//     input wire I_sdram_rd_valid,    // sdram数据读使能 [cite: 4]
//     input wire I_sdram_pingpang_en  // sdram乒乓操作使能 [cite: 5]
// );

//   // 信号打拍与边沿检测寄存器 [cite: 5, 6, 7]
//   reg fifo_wr_load_r1, fifo_wr_load_r2;
//   reg fifo_rd_load_r1, fifo_rd_load_r2;
//   reg sdram_wr_ack1, sdram_wr_ack2;
//   reg sdram_rd_ack1, sdram_rd_ack2;
//   reg sdram_rd_valid1, sdram_rd_valid2;

//   wire fifo_wr_load_p = (~fifo_wr_load_r2) & fifo_wr_load_r1;
//   wire fifo_rd_load_p = (~fifo_rd_load_r2) & fifo_rd_load_r1;
//   wire sdram_wr_ack_n = sdram_wr_ack2 & (~sdram_wr_ack1);
//   wire sdram_rd_ack_n = sdram_rd_ack2 & (~sdram_rd_ack1);

//   wire [11:0] wr_fifo_use;
//   wire [11:0] rd_fifo_use;

//   // -------------------------------------------------------------
//   // 信号打拍逻辑 [cite: 9-18]
//   // -------------------------------------------------------------
//   always @(posedge I_ref_clk or negedge I_rst_n) begin
//     if (I_rst_n == 1'b0) begin
//       fifo_wr_load_r1 <= 1'b0;
//       fifo_wr_load_r2 <= 1'b0;
//       fifo_rd_load_r1 <= 1'b0;
//       fifo_rd_load_r2 <= 1'b0;
//       sdram_wr_ack1   <= 1'b0;
//       sdram_wr_ack2   <= 1'b0;
//       sdram_rd_ack1   <= 1'b0;
//       sdram_rd_ack2   <= 1'b0;
//       sdram_rd_valid1 <= 1'b0;
//       sdram_rd_valid2 <= 1'b0;
//     end else begin
//       fifo_wr_load_r1 <= I_fifo_wr_load;
//       fifo_wr_load_r2 <= fifo_wr_load_r1;
//       fifo_rd_load_r1 <= I_fifo_rd_load;
//       fifo_rd_load_r2 <= fifo_rd_load_r1;
//       sdram_wr_ack1   <= I_sdram_wr_ack;
//       sdram_wr_ack2   <= sdram_wr_ack1;
//       sdram_rd_ack1   <= I_sdram_rd_ack;
//       sdram_rd_ack2   <= sdram_rd_ack1;
//       sdram_rd_valid1 <= I_sdram_rd_valid;
//       sdram_rd_valid2 <= sdram_rd_valid1;
//     end
//   end

//   // -------------------------------------------------------------
//   // 核心优化 1：阈值预计算 (寄存器隔离减法器) [cite: 21]
//   // -------------------------------------------------------------
//   reg [23:0] wr_end_threshold;
//   reg [23:0] rd_end_threshold;

//   always @(posedge I_ref_clk or negedge I_rst_n) begin
//     if (!I_rst_n) begin
//       wr_end_threshold <= 24'd0;
//       rd_end_threshold <= 24'd0;
//     end else begin
//       wr_end_threshold <= I_wr_eaddr - I_wr_brust;
//       rd_end_threshold <= I_rd_eaddr - I_rd_brust;
//     end
//   end

//   // -------------------------------------------------------------
//   // 核心优化 2：全地址预计算 (Next-Address Look-ahead)
//   // 提前算好“下一跳”地址，消除 ack_n 脉冲到来时的比较和加法延迟
//   // -------------------------------------------------------------
//   reg [23:0] next_wr_addr;
//   reg [23:0] next_rd_addr;

//   always @(posedge I_ref_clk or negedge I_rst_n) begin
//     if (!I_rst_n) begin
//       next_wr_addr <= 24'd0;
//     end else if (O_sdram_wr_addr[22:0] < wr_end_threshold[22:0]) begin
//       next_wr_addr <= O_sdram_wr_addr + I_wr_brust;
//     end else begin
//       next_wr_addr <= {O_sdram_wr_addr[23], I_wr_saddr[22:0]};
//     end
//   end

//   always @(posedge I_ref_clk or negedge I_rst_n) begin
//     if (!I_rst_n) begin
//       next_rd_addr <= 24'd0;
//     end else if (O_sdram_rd_addr[22:0] < rd_end_threshold[22:0]) begin
//       next_rd_addr <= O_sdram_rd_addr + I_rd_brust;
//     end else begin
//       next_rd_addr <= {O_sdram_rd_addr[23], I_rd_saddr[22:0]};
//     end
//   end

//   // -------------------------------------------------------------
//   // 地址更新逻辑：直接使用预计算好的 next_addr
//   // -------------------------------------------------------------
//   reg rw_bank_flag;  // 0:写Bank0, 1:写Bank1 [cite: 24, 25]

//   always @(posedge I_ref_clk or negedge I_rst_n) begin
//     if (I_rst_n == 1'b0) begin
//       O_sdram_wr_addr <= 24'd0;
//       rw_bank_flag    <= 1'b0;
//     end else if (fifo_wr_load_p) begin
//       if (I_sdram_pingpang_en) begin
//         O_sdram_wr_addr <= {~rw_bank_flag, I_wr_saddr[22:0]};
//         rw_bank_flag    <= ~rw_bank_flag;
//       end else begin
//         O_sdram_wr_addr <= I_wr_saddr;
//       end
//     end else if (sdram_wr_ack_n) begin
//       // 此时没有任何比较和加法，直接寄存器赋值，时序极其充裕
//       O_sdram_wr_addr <= next_wr_addr;
//     end
//   end

//   always @(posedge I_ref_clk or negedge I_rst_n) begin
//     if (I_rst_n == 1'b0) begin
//       O_sdram_rd_addr <= 24'd0;
//     end else if (fifo_rd_load_p) begin
//       if (I_sdram_pingpang_en) begin
//         O_sdram_rd_addr <= {~rw_bank_flag, I_rd_saddr[22:0]};
//       end else begin
//         O_sdram_rd_addr <= I_rd_saddr;
//       end
//     end else if (sdram_rd_ack_n) begin
//       O_sdram_rd_addr <= next_rd_addr;
//     end
//   end

//   // -------------------------------------------------------------
//   // sdram 读写请求产生 [cite: 37-42]
//   // -------------------------------------------------------------
//   always @(posedge I_ref_clk or negedge I_rst_n) begin
//     if (I_rst_n == 1'b0) begin
//       O_sdram_wr_req <= 1'b0;
//       O_sdram_rd_req <= 1'b0;
//     end else if (I_sdram_init_done) begin
//       if ((rd_fifo_use < I_wr_brust) && sdram_rd_valid2) begin
//         O_sdram_rd_req <= 1'b1;
//         O_sdram_wr_req <= 1'b0;
//       end else if (wr_fifo_use >= I_wr_brust) begin
//         O_sdram_wr_req <= 1'b1;
//         O_sdram_rd_req <= 1'b0;
//       end else begin
//         O_sdram_wr_req <= 1'b0;
//         O_sdram_rd_req <= 1'b0;
//       end
//     end else begin
//       O_sdram_wr_req <= 1'b0;
//       O_sdram_rd_req <= 1'b0;
//     end
//   end

//   // -------------------------------------------------------------
//   // FIFO 复位与例化 [cite: 43-50]
//   // -------------------------------------------------------------
//   reg wr_fifo_aclr_reg, rd_fifo_aclr_reg;
//   always @(posedge I_ref_clk or negedge I_rst_n) begin
//     if (!I_rst_n) begin
//       wr_fifo_aclr_reg <= 1'b1;
//       rd_fifo_aclr_reg <= 1'b1;
//     end else begin
//       wr_fifo_aclr_reg <= fifo_wr_load_p;
//       rd_fifo_aclr_reg <= fifo_rd_load_p;
//     end
//   end

//   wire wr_fifo_aclr_global, rd_fifo_aclr_global;
//   GLOBAL u_global_wr (
//       .in (wr_fifo_aclr_reg),
//       .out(wr_fifo_aclr_global)
//   );
//   GLOBAL u_global_rd (
//       .in (rd_fifo_aclr_reg),
//       .out(rd_fifo_aclr_global)
//   );

//   sdram_wr_fifo sdram_wr_fifo_inst (
//       .wrclk(I_fifo_wr_clk),
//       .wrreq(I_fifo_wr_req),
//       .data(I_fifo_wr_data),
//       .rdclk(I_ref_clk),
//       .rdreq(I_sdram_wr_ack),
//       .q(O_sdram_wr_data),
//       .aclr(wr_fifo_aclr_global),
//       .rdusedw(wr_fifo_use)
//   );

//   sdram_rd_fifo sdram_rd_fifo_inst (
//       .wrclk(I_ref_clk),
//       .wrreq(I_sdram_rd_ack),
//       .data(I_sdram_rd_data),
//       .rdclk(I_fifo_rd_clk),
//       .rdreq(I_fifo_rd_req),
//       .q(O_fifo_rd_data),
//       .aclr(rd_fifo_aclr_global),
//       .wrusedw(rd_fifo_use)
//   );

// endmodule
