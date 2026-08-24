// =============================================================================
// 项目名称：2026 年全国大学生集成电路创新创业大赛国奖项目
// 工程分区：基础图像处理工程（base）
// 文件名称：ram_large_192k.v
// 主要模块：ram_cascaded_128k
// 功能分类：几何变换存储
// 功能说明：级联片上 RAM，为旋转与帧内地址重排提供大容量像素缓存。
// 输入概述：读写时钟、FIFO 请求、帧地址、突发长度及待写像素数据。
// 输出概述：读出像素数据、SDRAM 命令/地址/数据和初始化完成状态。
// 时序约束：跨越视频与 SDRAM 时钟域；FIFO 清空、帧边界和突发握手必须保持同步。
// 关联文件：video_rotator_bram.v
// 维护要求：修改端口、位宽、流水线延迟或模式编码时，必须同步更新上层例化与项目文档。
// =============================================================================
// 双时钟级联包装器：拼装 2 个 65536 (64K) BRAM IP 核 (适配 2拍同步延迟配置)
module ram_cascaded_128k (
    input  wire        wr_clk,   // 写时钟
    input  wire        rd_clk,   // 读时钟
    input  wire [15:0] data,     // 写数据总线
    input  wire [16:0] wr_addr,  // 写地址 (17位，寻址 128K 空间)
    input  wire        wr_en,    // 总写使能
    input  wire [16:0] rd_addr,  // 读地址 (17位)
    input  wire        rd_en,    // 总读使能
    output wire [15:0] q         // 最终读出的数据
);

  // 地址切片
  // 17位地址的高1位（第16位）作为“片选”，决定访问第 0 块还是第 1 块 RAM。
  // 低16位（15:0）作为内部地址，到对应的 RAM 内部去寻址。
  wire wr_bank = wr_addr[16];
  wire rd_bank = rd_addr[16];

  // 定义一个由两组 16-bit 组成的“数组”，用来分别接收两个 RAM 的读出数据
  wire [15:0] q_bus[0:1];

  // 批量例化 (实例化) 硬件电路模块
  genvar i;  // 声明生成变量，专用于在综合阶段复制硬件
  generate
    // 告诉综合器：帮我把下面的电路复制 2 份
    for (i = 0; i < 2; i = i + 1) begin : ram_blocks
      // 实例化底层的 64K RAM IP 核
      ram_64k_ip u_ram (
          .rdclock  (rd_clk),
          .wrclock  (wr_clk),
          .data     (data),           // 待写数据广播给两个 RAM
          .rdaddress(rd_addr[15:0]),  // 读地址低16位广播给两个 RAM
          .wraddress(wr_addr[15:0]),  // 写地址低16位广播给两个 RAM

          // 写使能控制：只有全局写使能有效，且高位地址(wr_bank)刚好等于当前 RAM 的编号(i)时，才写入
          .wren(wr_en && (wr_bank == i)),

          // 功耗优化：只有全局读使能有效，且高位地址(rd_bank)等于当前 RAM 的编号(i)时，才读取
          .rden(rd_en && (rd_bank == i)),

          // 将当前 RAM 读出的数据连到总线数组的第 i 组上
          .q(q_bus[i])
      );
    end
  endgenerate

  // 读数据多路复用与延迟对齐
  // 由于底层 IP 核配置了输出寄存器 (Read output port)，读取数据需要等待 2 个时钟周期。
  // 也就是说，现在的 rd_addr 对应的真实数据，要在 2 拍后才会出现在 q_bus 上。
  // 因此，用来决定“挑选哪一块 RAM 的数据”的片选信号，也必须去排队等 2 拍！
  reg rd_bank_d1, rd_bank_d2;

  always @(posedge rd_clk) begin
    rd_bank_d1 <= rd_bank;  // 第 1 拍延迟：记录 1 拍前的读片选
    rd_bank_d2 <= rd_bank_d1;  // 第 2 拍延迟：记录 2 拍前的读片选
  end

  // 时间对齐完毕！用 2 拍前的片选信号，去挑选现在刚刚冒出来的 q_bus 数据
  assign q = q_bus[rd_bank_d2];

endmodule
