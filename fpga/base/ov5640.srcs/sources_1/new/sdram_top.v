// =============================================================================
// 项目名称：2026 年全国大学生集成电路创新创业大赛国奖项目
// 作者：Ethereal
// 工程分区：基础图像处理工程（base）
// 文件名称：sdram_top.v
// 主要模块：sdram_top
// 功能分类：帧缓存控制
// 功能说明：封装 SDRAM 控制器和读写 FIFO，提供视频帧缓存的统一顶层接口。
// 输入概述：读写时钟、FIFO 请求、帧地址、突发长度及待写像素数据。
// 输出概述：读出像素数据、SDRAM 命令/地址/数据和初始化完成状态。
// 时序约束：跨越视频与 SDRAM 时钟域；FIFO 清空、帧边界和突发握手必须保持同步。
// 关联文件：sdram_control.v、sdram_fifo_ctrl.v
// 维护要求：修改端口、位宽、流水线延迟或模式编码时，必须同步更新上层例化与项目文档。
// =============================================================================
// -----------------------------------------------------------------------------
// [Ethereal注释] 正文导读：封装 SDRAM 控制器和读写 FIFO，提供视频帧缓存的统一顶层接口。
// [Ethereal注释] 阅读顺序：先确认参数和端口，再沿内部信号、时序过程及子模块例化追踪数据流。
// [Ethereal注释] 修改约束：读写地址、突发长度、FIFO 清空和跨时钟握手必须保持一致，避免帧错位或数据溢出。
// -----------------------------------------------------------------------------
// [Ethereal注释] 模块 sdram_top：以下接口构成综合边界，上层通过端口连接数据流、控制流和状态信号。
module sdram_top (
    // [Ethereal注释] 接口信号：input 接收上游数据/控制，output 返回处理结果/状态，inout 连接双向器件总线。
    input   wire    I_ref_clk,  // sdram 控制器参考时钟
    input   wire    I_out_clk,  // sdram 相位偏移驱动时钟
    input   wire    I_rst_n,    // 复位信号，低电平有效
    // 写部分
    input   wire    I_fifo_wr_clk,  // 写fifo:写时钟
    input   wire    I_fifo_wr_req,  // 写fifo:写使能
    input   wire    [15:0]I_fifo_wr_data, // 写fifo:写入的数据
    input   wire    I_fifo_wr_load, // 写fifo:清空

    input wire [11:0] I_wr_burst,  // 写数据突发长度
    input wire [23:0] I_wr_saddr,  // 写数据起始位置
    input wire [23:0] I_wr_eaddr,  // 写数据终止位置

    // 读部分
    input   wire    I_fifo_rd_clk,  // 读fifo:读时钟
    input   wire    I_fifo_rd_req,  // 读fifo:读使能
    output  wire    [15:0]O_fifo_rd_data, // 读fifo:读出的数据
    input   wire    I_fifo_rd_load, // 读fifo:读清空

    input wire [11:0] I_rd_burst,  // 读数据突发长度
    input wire [23:0] I_rd_saddr,  // 读数据起始位置
    input wire [23:0] I_rd_eaddr,  // 读数据终止位置

    // 使能端口
    input   wire    I_sdram_rd_valid, // SDRAM 读使能
    input   wire    I_sdram_pingpang_en,    // SDRAM 乒乓操作使能
    output  wire    O_sdram_init_done,  // SDRAM 初始化完成标志

    // SDRAM 芯片接口
    output  wire    O_sdram_clk,    // SDRAM 驱动时钟
    output  wire    O_sdram_cke,    // SDRAM 时钟使能信号
    output  wire    O_sdram_cs_n,   // SDRAM 片选信号
    output  wire    O_sdram_ras_n,  // SDRAM 行选信号
    output  wire    O_sdram_cas_n,  // SDRAM 列选信号
    output  wire    O_sdram_we_n,   // SDRAM 写使能信号
    output  wire    [1:0]O_sdram_bank,   // SDRAM Bank地址线
    output  wire    [12:0]O_sdram_addr,   // SDRAM 地址总线
    inout   wire    [15:0]IO_sdram_dq,   // SDRAM 数据总线
    output  wire    [1:0]O_sdram_dqm    // SDRAM 数据掩码
);

  //sdram_fifo_ctrl
  // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  wire sdram_wr_req;
  wire [23:0] sdram_wr_addr;
  wire [15:0] sdram_wr_data;

  wire sdram_rd_req;
  wire [23:0] sdram_rd_addr;

  // sdram_control
  wire sdram_wr_ack;

  wire sdram_rd_ack;
  wire [15:0] sdram_rd_data;

  // [Ethereal注释] 组合连线组 1：从 O_sdram_dqm 开始的连续赋值随右值立即更新，不增加寄存器延迟。
  assign O_sdram_dqm = 2'b00;
  assign O_sdram_clk = I_out_clk;

  //sdram_fifo_ctrl
  // [Ethereal注释] 子模块例化 1（sdram_fifo_ctrl）：协调异步读写 FIFO、突发地址和帧边界，连接视频时钟域与 SDRAM 时钟域。
  sdram_fifo_ctrl sdram_fifo_ctrl (
      .I_ref_clk(I_ref_clk),  // 参考时钟
      .I_rst_n  (I_rst_n),    // 系统复位,低电平有效

      // 写部分:外部-->FIFO
      .I_fifo_wr_clk (I_fifo_wr_clk),   // fifo写时钟
      .I_fifo_wr_req (I_fifo_wr_req),   // 写入fifo请求
      .I_fifo_wr_data(I_fifo_wr_data),  // 写入fifo的数据
      .I_wr_saddr    (I_wr_saddr),      // 写入sdram的起始地址
      .I_wr_eaddr    (I_wr_eaddr),      // 写入sdram的终止地址
      .I_wr_brust    (I_wr_burst),      // 写入sdram的突发长度
      .I_fifo_wr_load(I_fifo_wr_load),  // 写入fifo数据清空

      // wr_fifo:FIFO(写)-->SDRAM(读)
      .O_sdram_wr_req (sdram_wr_req),   // 数据写入sdram写请求
      .I_sdram_wr_ack (sdram_wr_ack),   // 数据写入sdram写响应
      .O_sdram_wr_addr(sdram_wr_addr),  // 写数据进sdram的地址
      .O_sdram_wr_data(sdram_wr_data),  // 写入sdram的数据

      // rd_fifo:SDRAM(写)-->FIFO(读)
      .O_sdram_rd_req (sdram_rd_req),   // 数据读出sdram读请求
      .I_sdram_rd_ack (sdram_rd_ack),   // 数据读出sdram读响应
      .O_sdram_rd_addr(sdram_rd_addr),  // 读数据进fifo的地址
      .I_sdram_rd_data(sdram_rd_data),  // 读入fifo的数据

      // 读部分:FIFO-->外部
      .I_fifo_rd_clk (I_fifo_rd_clk),   // 数据读出fifo读时钟
      .I_fifo_rd_req (I_fifo_rd_req),   // 数据读出fifo读请求
      .O_fifo_rd_data(O_fifo_rd_data),  // 读出fifo的数据
      .I_rd_saddr    (I_rd_saddr),      // 读出sdram的起始地址
      .I_rd_eaddr    (I_rd_eaddr),      // 读出sdram的终止地址
      .I_rd_brust    (I_rd_burst),      // 读出sdram的突发长度
      .I_fifo_rd_load(I_fifo_rd_load),  // 读出fifo数据清空

      // SDRAM
      .I_sdram_init_done  (O_sdram_init_done),  // sdram初始化完成
      .I_sdram_rd_valid   (I_sdram_rd_valid),    // sdram数据读使能
      .I_sdram_pingpang_en (I_sdram_pingpang_en)// sdram乒乓操作使能
  );

  // sdram_control
  // [Ethereal注释] 子模块例化 2（sdram_control）：实现 SDRAM 上电初始化、自动刷新、突发读写和芯片引脚时序。
  sdram_control sdram_control (
      .I_ref_clk(I_ref_clk),  // 参考时钟
      .I_rst_n  (I_rst_n),    // 复位信号，低电平有效

      // SDRAM 控制器写端口
      .I_sdram_wr_req  (sdram_wr_req),   // 写sdram请求信号
      .O_sdram_wr_ack  (sdram_wr_ack),   // 写sdram响应信号
      .I_sdram_wr_addr (sdram_wr_addr),  // 写sdram时地址
      .I_sdram_wr_burst(I_wr_burst),     // 写sdram时数据突发长度
      .I_sdram_wr_data (sdram_wr_data),  // 写入sdram的数据

      // SDRAM 控制器读端口
      .I_sdram_rd_req  (sdram_rd_req),   // 读sdram请求信号
      .O_sdram_rd_ack  (sdram_rd_ack),   // 读sdram响应信号
      .I_sdram_rd_addr (sdram_rd_addr),  // 读sdram时地址
      .I_sdram_rd_burst(I_rd_burst),     // 读sdram时数据突发长度
      .O_sdram_rd_data (sdram_rd_data),  // 读出sdram的数据

      .O_sdram_init_done(O_sdram_init_done),  // SDRAM初始化完成

      // SDRAM PHY
      .O_sdram_cke  (O_sdram_cke),    // SDRAM 时钟有效信号
      .O_sdram_cs_n (O_sdram_cs_n),   // SDRAM 片选信号
      .O_sdram_ras_n(O_sdram_ras_n),  // SDRAM 行选信号
      .O_sdram_cas_n(O_sdram_cas_n),  // SDRAM 列选信号
      .O_sdram_we_n (O_sdram_we_n),   // SDRAM 写使能信号
      .O_sdram_bank (O_sdram_bank),   // SDRAM Bank地址线
      .O_sdram_addr (O_sdram_addr),   // SDRAM 地址总线
      .IO_sdram_dq  (IO_sdram_dq)     // SDRAM 数据总线
  );

endmodule
