// =============================================================================
// 项目名称：2026 年全国大学生集成电路创新创业大赛国奖项目
// 作者：Ethereal
// 工程分区：图像增强工程（enhancement）
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

// -----------------------------------------------------------------------------
// 正文导读：协调异步读写 FIFO、突发地址和帧边界，连接视频时钟域与 SDRAM 时钟域。
// 阅读顺序：先确认参数和端口，再沿内部信号、时序过程及子模块例化追踪数据流。
// 修改约束：读写地址、突发长度、FIFO 清空和跨时钟握手必须保持一致，避免帧错位或数据溢出。
// -----------------------------------------------------------------------------
// 模块 sdram_fifo_ctrl：以下接口构成综合边界，上层通过端口连接数据流、控制流和状态信号。
module sdram_fifo_ctrl (
    // 接口信号：input 接收上游数据/控制，output 返回处理结果/状态，inout 连接双向器件总线。
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
  // 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
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
  // 时序过程 1：由 I_ref_clk posedge，I_rst_n negedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
  always @(posedge I_ref_clk or negedge I_rst_n) begin
    if (I_rst_n == 1'b0) begin
      fifo_wr_load_r1 <= 1'b0;
      fifo_wr_load_r2 <= 1'b0;
    end else begin
      fifo_wr_load_r1 <= I_fifo_wr_load;
      fifo_wr_load_r2 <= fifo_wr_load_r1;
    end
  end

  // 时序过程 2：由 I_ref_clk posedge，I_rst_n negedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
  always @(posedge I_ref_clk or negedge I_rst_n) begin
    if (I_rst_n == 1'b0) begin
      fifo_rd_load_r1 <= 1'b0;
      fifo_rd_load_r2 <= 1'b0;
    end else begin
      fifo_rd_load_r1 <= I_fifo_rd_load;
      fifo_rd_load_r2 <= fifo_rd_load_r1;
    end
  end

  // 时序过程 3：由 I_ref_clk posedge，I_rst_n negedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
  always @(posedge I_ref_clk or negedge I_rst_n) begin
    if (I_rst_n == 1'b0) begin
      sdram_wr_ack1 <= 1'b0;
      sdram_wr_ack2 <= 1'b0;
    end else begin
      sdram_wr_ack1 <= I_sdram_wr_ack;
      sdram_wr_ack2 <= sdram_wr_ack1;
    end
  end

  // 时序过程 4：由 I_ref_clk posedge，I_rst_n negedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
  always @(posedge I_ref_clk or negedge I_rst_n) begin
    if (I_rst_n == 1'b0) begin
      sdram_rd_ack1 <= 1'b0;
      sdram_rd_ack2 <= 1'b0;
    end else begin
      sdram_rd_ack1 <= I_sdram_rd_ack;
      sdram_rd_ack2 <= sdram_rd_ack1;
    end
  end

  // 时序过程 5：由 I_ref_clk posedge，I_rst_n negedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
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
  // 组合连线组 1：从 fifo_wr_load_p 开始的连续赋值随右值立即更新，不增加寄存器延迟。
  assign fifo_wr_load_p = (~fifo_wr_load_r2) & fifo_wr_load_r1;
  assign fifo_rd_load_p = (~fifo_rd_load_r2) & fifo_rd_load_r1;
  assign sdram_wr_ack_n = sdram_wr_ack2 & (~sdram_wr_ack1);
  assign sdram_rd_ack_n = sdram_rd_ack2 & (~sdram_rd_ack1);

  // 乒乓操作 - 写入地址逻辑 (基于帧脉冲强制切换)
  // 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  reg rw_bank_flag;  // 0:写Bank0, 1:写Bank1

  // 时序过程 6：由 I_ref_clk posedge，I_rst_n negedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
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
      if (O_sdram_wr_addr[22:0] < (I_wr_eaddr - I_wr_brust)) begin
        O_sdram_wr_addr <= O_sdram_wr_addr + I_wr_brust;
      end else begin
        // 本帧如果提前写满，地址回卷到当前Bank的头部等待下一帧
        O_sdram_wr_addr <= {O_sdram_wr_addr[23], I_wr_saddr[22:0]};
      end
    end
  end

  // 乒乓操作 - 读取地址逻辑
  // 时序过程 7：由 I_ref_clk posedge，I_rst_n negedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
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
      if (O_sdram_rd_addr[22:0] < (I_rd_eaddr - I_rd_brust)) begin
        O_sdram_rd_addr <= O_sdram_rd_addr + I_rd_brust;
      end else begin
        O_sdram_rd_addr <= {O_sdram_rd_addr[23], I_rd_saddr[22:0]};
      end
    end
  end

  // SDRAM 读写请求产生模块
  // 时序过程 8：由 I_ref_clk posedge，I_rst_n negedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
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
// -------------------------------------------------------------
  // 核心时序优化：纯寄存器直驱 + 流水线打拍缓解高扇出
  // -------------------------------------------------------------
  // 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  reg wr_fifo_aclr_reg_d1;
  reg rd_fifo_aclr_reg_d1;
  
  // 纯净的终级寄存器（去掉原语，让编译器自动优化它的物理位置）
  reg wr_fifo_aclr_reg_final;
  reg rd_fifo_aclr_reg_final;

  // 时序过程 9：由 I_ref_clk posedge，I_rst_n negedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
  always @(posedge I_ref_clk or negedge I_rst_n) begin
    if (!I_rst_n) begin
      // 1. 全局硬件复位时，寄存器被异步置 1
      wr_fifo_aclr_reg_d1 <= 1'b1;
      rd_fifo_aclr_reg_d1 <= 1'b1;
      
      wr_fifo_aclr_reg_final <= 1'b1;
      rd_fifo_aclr_reg_final <= 1'b1;
    end else begin
      // 2. 第一拍：抓取单脉冲 (消化前面的组合逻辑)
      wr_fifo_aclr_reg_d1 <= fifo_wr_load_p;
      rd_fifo_aclr_reg_d1 <= fifo_rd_load_p;
      
      // 3. 第二拍：中继打拍！这能为编译器争取整整 1 个时钟周期的布线时间
      wr_fifo_aclr_reg_final <= wr_fifo_aclr_reg_d1;
      rd_fifo_aclr_reg_final <= rd_fifo_aclr_reg_d1;
    end
  end

  // ==========================================
  // FIFO 例化：连接最终打过拍的寄存器
  // ==========================================
  // 子模块例化 1（sdram_wr_fifo）：封装 FIFO IP，在数据通路中完成缓存、速率匹配或跨时钟域传输。
  sdram_wr_fifo sdram_wr_fifo_inst (
      .wrclk  (I_fifo_wr_clk),
      .wrreq  (I_fifo_wr_req),
      .data   (I_fifo_wr_data),
      .rdclk  (I_ref_clk),
      .rdreq  (I_sdram_wr_ack),
      .q      (O_sdram_wr_data),
      .aclr   (wr_fifo_aclr_reg_final),  // <--- 连到 final 寄存器
      .rdusedw(wr_fifo_use)
  );

  // 子模块例化 2（sdram_rd_fifo）：封装 FIFO IP，在数据通路中完成缓存、速率匹配或跨时钟域传输。
  sdram_rd_fifo sdram_rd_fifo_inst (
      .wrclk  (I_ref_clk),
      .wrreq  (I_sdram_rd_ack),
      .data   (I_sdram_rd_data),
      .rdclk  (I_fifo_rd_clk),
      .rdreq  (I_fifo_rd_req),
      .q      (O_fifo_rd_data),
      .aclr   (rd_fifo_aclr_reg_final),  // <--- 连到 final 寄存器
      .wrusedw(rd_fifo_use)
  );
endmodule
