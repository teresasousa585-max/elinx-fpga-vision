// =============================================================================
// 项目名称：2026 年全国大学生集成电路创新创业大赛国奖项目
// 作者：Ethereal
// 工程分区：基础图像处理工程（base）
// 文件名称：histogram_equalization.v
// 主要模块：histogram_equalization
// 功能分类：图像增强算法
// 功能说明：统计灰度直方图并生成均衡化映射，提高低对比度画面的灰度分布范围。
// 输入概述：像素数据及 HS/VS/DE 视频同步信号；控制参数由模式或模块参数给出。
// 输出概述：处理后的像素流，以及与流水线延迟严格匹配的 HS/VS/DE 信号。
// 时序约束：像素数据在视频像素时钟上升沿处理；复位极性以模块端口定义为准。
// 关联文件：rgb2ycbcr.v、video_algo_manager.v、hist_ram IP
// 维护要求：修改端口、位宽、流水线延迟或模式编码时，必须同步更新上层例化与项目文档。
// =============================================================================
`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// [Ethereal注释] 正文导读：统计灰度直方图并生成均衡化映射，提高低对比度画面的灰度分布范围。
// [Ethereal注释] 阅读顺序：先确认参数和端口，再沿内部信号、时序过程及子模块例化追踪数据流。
// [Ethereal注释] 修改约束：读写地址、突发长度、FIFO 清空和跨时钟握手必须保持一致，避免帧错位或数据溢出。
// -----------------------------------------------------------------------------
// [Ethereal注释] 模块 histogram_equalization：以下接口构成综合边界，上层通过端口连接数据流、控制流和状态信号。
module histogram_equalization (
    // [Ethereal注释] 接口信号：input 接收上游数据/控制，output 返回处理结果/状态，inout 连接双向器件总线。
    input  wire       clk,
    input  wire       rst,
    input  wire       hs,
    vsync,
    de,
    // [Ethereal注释] 接口信号：input 接收上游数据/控制，output 返回处理结果/状态，inout 连接双向器件总线。
    input  wire [7:0] din,
    output reg        hs_out,
    vsync_out,
    de_out,
    // [Ethereal注释] 接口信号：input 接收上游数据/控制，output 返回处理结果/状态，inout 连接双向器件总线。
    output reg  [7:0] dout
);

  // =========================================================================
  // 1. 同步信号与 Ping-Pong 切换
  // =========================================================================
  // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  reg buf_sel;
  reg vsync_d1, vsync_d2;
  wire vsync_rising = (vsync_d1 && !vsync_d2);

  // [Ethereal注释] 时序过程 1：由 clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
  always @(posedge clk) begin
    if (rst) begin
      vsync_d1 <= 1'b0;
      vsync_d2 <= 1'b0;
      buf_sel  <= 1'b0;
    end else begin
      vsync_d1 <= vsync;
      vsync_d2 <= vsync_d1;
      if (vsync_rising) buf_sel <= ~buf_sel;
    end
  end

  // =========================================================================
  // 2. 状态机
  // =========================================================================
  // [Ethereal注释] 参数配置：综合期确定位宽、容量、频率或算法强度，修改后需重新验证资源和时序。
  localparam IDLE = 2'd0, SUM = 2'd1, CLEAR = 2'd2;
  // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  reg [1:0] state;
  reg [8:0] calc_idx, calc_idx_d1;
  reg [31:0] cdf_acc, cdf_acc_d1;  // ← 增加 cdf_acc_d1

  // =========================================================================
  // 3. 准确的读写冲突保护 (时序满足读写时序)
  // =========================================================================
  reg [7:0] din_d1, din_d2;
  reg de_d1, de_d2;

  // 当前拍：准备写入信息
  wire [ 7:0] write_addr_cur = din_d1;
  wire [31:0] write_data_cur = (buf_sel == 1'b0 ? real_count_0_comb : real_count_1_comb) + 1'b1;
  wire        write_en_cur_0 = (buf_sel == 1'b0) ? de_d1 : 1'b0;
  wire        write_en_cur_1 = (buf_sel == 1'b1) ? de_d1 : 1'b0;

  // 下一拍：检测当前 din_d2 是否与上一拍的写地址冲突
  wire        collision_0 = (din_d2 == write_addr_cur) && (write_en_cur_0) && de_d2;
  wire        collision_1 = (din_d2 == write_addr_cur) && (write_en_cur_1) && de_d2;

  // 记忆上一拍的写入值（用于旁路）
  reg  [31:0] write_data_saved;
  // [Ethereal注释] 时序过程 2：由 clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
  always @(posedge clk) begin
    if (rst) begin
      din_d1 <= 0;
      de_d1 <= 0;
      din_d2 <= 0;
      de_d2 <= 0;
      write_data_saved <= 0;
    end else begin
      din_d1 <= din;
      de_d1 <= de;
      din_d2 <= din_d1;
      de_d2 <= de_d1;
      write_data_saved <= write_data_cur;  // 保存当前拍的写值
    end
  end

  // 真实计数（考虑旁路）- 组合逻辑（不依赖自身）
  // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  wire [31:0] real_count_0_comb = (collision_0) ? write_data_saved : ram0_rd_data;
  wire [31:0] real_count_1_comb = (collision_1) ? write_data_saved : ram1_rd_data;

  // BRAM 接口
  wire [ 7:0] ram0_rd_addr = (buf_sel == 1'b0) ? din : calc_idx[7:0];
  wire [ 7:0] ram0_wr_addr = (buf_sel == 1'b0) ? din_d1 : calc_idx_d1[7:0];
  wire [31:0] ram0_wr_data = (buf_sel == 1'b0) ? write_data_cur : 32'd0;
  wire        ram0_wr_en = (buf_sel == 1'b0) ? de_d1 : (state == CLEAR && !calc_idx_d1[8]);
  wire [31:0] ram0_rd_data;

  wire [ 7:0] ram1_rd_addr = (buf_sel == 1'b1) ? din : calc_idx[7:0];
  wire [ 7:0] ram1_wr_addr = (buf_sel == 1'b1) ? din_d1 : calc_idx_d1[7:0];
  wire [31:0] ram1_wr_data = (buf_sel == 1'b1) ? write_data_cur : 32'd0;
  wire        ram1_wr_en = (buf_sel == 1'b1) ? de_d1 : (state == CLEAR && !calc_idx_d1[8]);
  wire [31:0] ram1_rd_data;

  // [Ethereal注释] 子模块例化 1（hist_ram）：封装片上存储器 IP，为行缓存、帧内缓存或直方图统计提供存储资源。
  hist_ram u_hist_ram_0 (
      .clock(clk),
      .data(ram0_wr_data),
      .rdaddress(ram0_rd_addr),
      .wraddress(ram0_wr_addr),
      .wren(ram0_wr_en),
      .q(ram0_rd_data)
  );
  // [Ethereal注释] 子模块例化 2（hist_ram）：封装片上存储器 IP，为行缓存、帧内缓存或直方图统计提供存储资源。
  hist_ram u_hist_ram_1 (
      .clock(clk),
      .data(ram1_wr_data),
      .rdaddress(ram1_rd_addr),
      .wraddress(ram1_wr_addr),
      .wren(ram1_wr_en),
      .q(ram1_rd_data)
  );

  // =========================================================================
  // 4. CDF 计算与映射表更新 (修复时序)
  // =========================================================================
  // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  wire [31:0] cur_hist_val = (buf_sel == 1'b0) ? ram1_rd_data : ram0_rd_data;

  // ← 关键修复：用延迟的 CDF 值来映射
  wire [39:0] mapped_val_full = ({8'd0, cdf_acc_d1} * 40'd109) >> 18;
  wire [ 7:0] mapped_val = (mapped_val_full > 255) ? 8'd255 : mapped_val_full[7:0];

  reg         map_wr_en;
  reg  [ 7:0] map_wr_addr;
  reg  [ 7:0] map_wr_data;

  // [Ethereal注释] 时序过程 3：由 clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
  always @(posedge clk) begin
    if (rst) begin
      state <= IDLE;
      calc_idx <= 9'd0;
      calc_idx_d1 <= 9'd0;
      cdf_acc <= 32'd0;
      cdf_acc_d1 <= 32'd0;
      map_wr_en <= 1'b0;
    end else begin
      cdf_acc_d1  <= cdf_acc;  // ← 关键：保存前一拍的 CDF 值
      calc_idx_d1 <= calc_idx;

      // [Ethereal注释] 分支选择 1：依据 state 选择状态或算法路径；default 覆盖非法或空闲条件。
      case (state)
        IDLE: begin
          map_wr_en <= 1'b0;
          if (vsync_rising) begin
            state <= SUM;
            calc_idx <= 9'd0;
            cdf_acc <= 32'd0;
            cdf_acc_d1 <= 32'd0;
          end
        end
        SUM: begin
          if (calc_idx <= 9'd255) calc_idx <= calc_idx + 1'b1;

          if (!calc_idx_d1[8]) begin
            cdf_acc     <= cdf_acc + cur_hist_val;  // 更新累加器
            map_wr_addr <= calc_idx_d1[7:0];
            map_wr_data <= mapped_val;  // 用旧的 cdf_acc_d1
            map_wr_en   <= 1'b1;
          end else begin
            map_wr_en <= 1'b0;
          end

          if (calc_idx_d1 == 9'd255) begin
            state <= CLEAR;
            calc_idx <= 9'd0;
          end
        end
        CLEAR: begin
          map_wr_en <= 1'b0;
          if (calc_idx <= 9'd255) calc_idx <= calc_idx + 1'b1;
          if (calc_idx_d1 == 9'd255) begin
            state <= IDLE;
            calc_idx <= 9'd0;
          end
        end
        default: state <= IDLE;
      endcase
    end
  end

  // =========================================================================
  // 5. 映射输出 (精确 2 拍对齐)
  // =========================================================================
  // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  wire [7:0] lut_q_data;
  // [Ethereal注释] 子模块例化 3（map_table）：封装只读存储器 IP，提供算法查找表或定点运算常量。
  map_table u_map_table (
      .clock(clk),
      .data(map_wr_data),
      .wraddress(map_wr_addr),
      .wren(map_wr_en),
      .rdaddress(din),
      .q(lut_q_data)
  );

  // 只需要打 1 拍缓冲，配合输出寄存器达到 2 拍准确对齐
  // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  reg hs_d1, de_d1_out, vs_d1;
  // [Ethereal注释] 时序过程 4：由 clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
  always @(posedge clk) begin
    if (rst) begin
      hs_d1 <= 0;
      hs_out <= 0;
      de_d1_out <= 0;
      de_out <= 0;
      vs_d1 <= 0;
      vsync_out <= 0;
      dout <= 0;
    end else begin
      // 第一拍：输入信号打拍等待，同时 BRAM 正在内部读取 din
      hs_d1 <= hs;
      de_d1_out <= de;
      vs_d1 <= vsync;

      // 第二拍：BRAM 的数据 (lut_q_data) 吐出，直接与打了一拍的同步信号携手输出
      hs_out <= hs_d1;
      de_out <= de_d1_out;
      vsync_out <= vs_d1;
      dout <= de_d1_out ? lut_q_data : 8'd0;
    end
  end

endmodule
