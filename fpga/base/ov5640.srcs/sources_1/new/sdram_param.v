// =============================================================================
// 项目名称：2026 年全国大学生集成电路创新创业大赛国奖项目
// 作者：Ethereal
// 工程分区：基础图像处理工程（base）
// 文件名称：sdram_param.v
// 主要模块：参数与辅助定义
// 功能分类：存储参数
// 功能说明：定义 SDRAM 初始化、读写、刷新状态与关键时序计数宏。
// 输入概述：读写时钟、FIFO 请求、帧地址、突发长度及待写像素数据。
// 输出概述：读出像素数据、SDRAM 命令/地址/数据和初始化完成状态。
// 时序约束：跨越视频与 SDRAM 时钟域；FIFO 清空、帧边界和突发握手必须保持同步。
// 关联文件：sdram_control.v、sdram_fifo_ctrl.v
// 维护要求：修改端口、位宽、流水线延迟或模式编码时，必须同步更新上层例化与项目文档。
// =============================================================================
// SDRAM 初始化各个状态
// -----------------------------------------------------------------------------
// [Ethereal注释] 正文导读：定义 SDRAM 初始化、读写、刷新状态与关键时序计数宏。
// [Ethereal注释] 阅读顺序：先确认参数和端口，再沿内部信号、时序过程及子模块例化追踪数据流。
// [Ethereal注释] 修改约束：状态编码与时序计数值必须匹配 SDRAM 数据手册和工程时钟频率。
// -----------------------------------------------------------------------------
// [Ethereal注释] 宏定义组：描述状态编码、器件命令或时序终止条件，引用处必须与位宽一致。
`define I_NOP 5'd0  // 等待上电200us稳定
`define I_PCH 5'd1  // 预充电命令
`define I_TRP 5'd2  // 预充电过程等待
`define I_ARF 5'd3  // 自刷新命令
`define I_TRF 5'd4  // 自刷新过程等待
`define I_LMR 5'd5  // 模式寄存器配置命令
`define I_TRSC 5'd6 // 模式寄存器配置过程等待
`define I_DONE 5'd7 // 初始化完成

// SDRAM 工作各个状态
`define IDLE 4'd0   // 空闲状态
`define ACT 4'd1  // 行激活有效状态
`define TRCD 4'd2   // 行激活过程等待
`define WR 4'd3     // 写操作
`define WR_BE 4'd4  // 写数据
`define TWR 4'd5    // 写回
`define RD 4'd6     // 读操作
`define CL 4'd7     // 列潜伏期
`define RD_BE 4'd8  // 读数据
`define PCH 4'd9    // 预充电状态
`define TRP 4'd10   // 预充电过程等待
`define ARF 4'd11   // 自动刷新
`define TRFC 4'd12  // 自动刷新过程等待

// 延时参数
`define end_trp     O_cnt_clk == TRP  // 预充电过程等待结束
`define end_trf    O_cnt_clk == TRC  // 自动刷新过程等待结束
`define end_trsc    O_cnt_clk == TRSC // 模式寄存器配置过程等待结束
`define end_trcd    O_cnt_clk == TRCD-1  // 
`define end_cl     O_cnt_clk == TCL-1
`define end_wrburst O_cnt_clk == I_sdram_wr_burst - 1
`define end_twrite  O_cnt_clk == I_sdram_wr_burst - 1
`define end_rdburst O_cnt_clk == I_sdram_rd_burst - 4
`define end_tread   O_cnt_clk == I_sdram_rd_burst + 2
`define end_twr     O_cnt_clk == TWR

// SDRAM 操作命令 {CKE,CS_N,RAS_N,CAS_N,WE_N}
`define CMD_INIT    5'b01111    // INIT
`define CMD_NOP     5'b10111    // NOP
`define CMD_PCH     5'b10010    // PCH
`define CMD_ARF     5'b10001    // ARF
`define CMD_LMR     5'b10000    // LMR
`define CMD_ACT     5'b10011    // ACT
`define CMD_WR      5'b10100    // WR
`define CMD_RD      5'b10101    // RD
`define CMD_BT      5'b10110    // BT