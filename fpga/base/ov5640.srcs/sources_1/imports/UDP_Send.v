// =============================================================================
// 项目名称：2026 年全国大学生集成电路创新创业大赛国奖项目
// 作者：Ethereal
// 工程分区：基础图像处理工程（base）
// 文件名称：UDP_Send.v
// 主要模块：UDP_Send
// 功能分类：以太网图传
// 功能说明：生成包含视频载荷的以太网/IPv4/UDP 数据帧，并按帧起点协议发送 RGB565 分片。
// 输入概述：视频/协议载荷、发送触发、PHY 管理数据及系统时钟。
// 输出概述：以太网发送数据、CRC、MDIO 控制或 PHY 初始化状态。
// 时序约束：发送状态机与 PHY 接口时钟同步；帧边界和 CRC 覆盖范围不得随意修改。
// 关联文件：CRC32_D8.v、phy_reg_config.v、top.v
// 维护要求：修改端口、位宽、流水线延迟或模式编码时，必须同步更新上层例化与项目文档。
// =============================================================================
`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// [Ethereal注释] 正文导读：生成包含视频载荷的以太网/IPv4/UDP 数据帧，并按帧起点协议发送 RGB565 分片。
// [Ethereal注释] 阅读顺序：先确认参数和端口，再沿内部信号、时序过程及子模块例化追踪数据流。
// [Ethereal注释] 修改约束：协议字段、有效脉冲和跨时钟控制必须成组更新，并与上位机及外设时序保持一致。
// -----------------------------------------------------------------------------
// [Ethereal注释] 模块 UDP_Send：以下接口构成综合边界，上层通过端口连接数据流、控制流和状态信号。
module UDP_Send (
    // [Ethereal注释] 接口信号：input 接收上游数据/控制，output 返回处理结果/状态，inout 连接双向器件总线。
    input wire Clk,
    input wire Rst_n,

    // 🌟 帧同步强制清空信号
    input wire frame_vsync,

    input wire [47:0] des_mac,
    input wire [47:0] src_mac,
    input wire [15:0] des_port,
    input wire [15:0] src_port,
    input wire [31:0] des_ip,
    input wire [31:0] src_ip,
    input wire [15:0] data_length,

    output reg        GMII_TXEN,
    output reg  [7:0] GMII_TXD,
    output wire       GMII_GTXC,

    input  wire        wrclk,
    input  wire        wrreq,
    input  wire [ 7:0] wrdata,
    output wire [12:0] wrusedw
);

  // [Ethereal注释] 组合连线组 1：从 GMII_GTXC 开始的连续赋值随右值立即更新，不增加寄存器延迟。
  assign GMII_GTXC = Clk;

  // [Ethereal注释] 参数配置：综合期确定位宽、容量、频率或算法强度，修改后需重新验证资源和时序。
  localparam IDLE = 0, PRE = 1, HDRS = 2, DATA = 3, CRC = 4, IPG = 5;

  // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  reg  [ 2:0] state;
  reg  [ 5:0] hdr_cnt;
  reg  [15:0] data_cnt;

  reg  [ 7:0] n_txd;
  reg         n_txen;

  reg         c_en;
  reg         c_rst_n;
  wire [31:0] c_out;

  // =========================================================================
  // 包计数器强制与物理帧对齐
  // =========================================================================
  reg  [ 9:0] pkt_cnt;
  // [Ethereal注释] 时序过程 1：由 Clk posedge，Rst_n negedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
  always @(posedge Clk or negedge Rst_n) begin
    if (!Rst_n) begin
      pkt_cnt <= 10'd0;
    end else if (frame_vsync) begin
      pkt_cnt <= 10'd0;  // 只要物理帧 VSYNC 到来，无条件归零
    end else if (state == DATA && data_cnt == 16'd1) begin
      pkt_cnt <= pkt_cnt + 1'b1;
    end
  end

  // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  wire is_first_packet = (pkt_cnt == 10'd0);

  reg [7:0] hdr_buf[0:41];

  // [Ethereal注释] 参数配置：综合期确定位宽、容量、频率或算法强度，修改后需重新验证资源和时序。
  localparam L_DATA_LEN = 16'd1200;
  localparam L_IP_TOT = 16'd1228;
  localparam L_UDP_TOT = 16'd1208;
  localparam L_IP_CHK = 16'hB262;

  // [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
  wire [7:0] fifo_q;
  reg        fifo_rdreq;

  // =========================================================================
  // 将 VSYNC 引入内部 DCFIFO 的异步复位
  // =========================================================================
  // [Ethereal注释] 子模块例化 1（eth_dcfifo）：封装 FIFO IP，在数据通路中完成缓存、速率匹配或跨时钟域传输。
  eth_dcfifo u_eth_fifo (
      .aclr   (!Rst_n || frame_vsync),
      .data   (wrdata),
      .rdclk  (Clk),
      .rdreq  (fifo_rdreq),
      .wrclk  (wrclk),
      .wrreq  (wrreq),
      .q      (fifo_q),
      .rdusedw(wrusedw),
      .wrusedw()
  );

  // [Ethereal注释] 子模块例化 2（CRC32_D8）：按字节更新以太网 CRC32，生成帧校验序列。
  CRC32_D8 u_crc32 (
      .Clk    (Clk),
      .Reset  (c_rst_n),
      .Data_in(n_txd),
      .Enable (c_en),
      .Crc    (),
      .CrcNext(),
      .Crc_eth(c_out)
  );

  // [Ethereal注释] 时序过程 2：由 Clk posedge，Rst_n negedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
  always @(posedge Clk or negedge Rst_n) begin
    if (!Rst_n) begin
      state <= IDLE;
      hdr_cnt <= 0;
      data_cnt <= 0;
      n_txd <= 0;
      n_txen <= 0;
      c_en <= 0;
      c_rst_n <= 0;
      fifo_rdreq <= 0;
      hdr_buf[0] <= 0;
    end else begin
      if (frame_vsync) begin
        state  <= IDLE;
        n_txen <= 0;
        c_en   <= 0;
      end else begin
        // [Ethereal注释] 分支选择 1：依据 state 选择状态或算法路径；default 覆盖非法或空闲条件。
        case (state)
          IDLE: begin
            n_txen <= 0;
            hdr_cnt <= 0;
            c_rst_n <= 0;
            c_en <= 0;
            data_cnt <= L_DATA_LEN;

            // ---------- 以太网 MAC 头 (14 字节) ----------
            hdr_buf[0] <= des_mac[47:40];
            hdr_buf[1] <= des_mac[39:32];
            hdr_buf[2] <= des_mac[31:24];
            hdr_buf[3] <= des_mac[23:16];
            hdr_buf[4] <= des_mac[15:8];
            hdr_buf[5] <= des_mac[7:0];
            hdr_buf[6] <= src_mac[47:40];
            hdr_buf[7] <= src_mac[39:32];
            hdr_buf[8] <= src_mac[31:24];
            hdr_buf[9] <= src_mac[23:16];
            hdr_buf[10] <= src_mac[15:8];
            hdr_buf[11] <= src_mac[7:0];
            hdr_buf[12] <= 8'h08;  // IP Type
            hdr_buf[13] <= 8'h00;

            // ---------- IP 头 (20 字节) ----------
            hdr_buf[14] <= 8'h45;  // Version/IHL
            hdr_buf[15] <= 8'h00;  // TOS
            hdr_buf[16] <= L_IP_TOT[15:8];
            hdr_buf[17] <= L_IP_TOT[7:0];
            hdr_buf[18] <= 8'h00;  // ID
            hdr_buf[19] <= 8'h00;
            hdr_buf[20] <= 8'h40;  // Flags
            hdr_buf[21] <= 8'h00;  // 🌟 修复：补回漏掉的 Frag Offset Low
            hdr_buf[22] <= 8'h40;  // 🌟 修复：补回漏掉的 TTL (64)
            hdr_buf[23] <= 8'h11;  // Protocol: UDP (17)
            hdr_buf[24] <= L_IP_CHK[15:8];  // Checksum
            hdr_buf[25] <= L_IP_CHK[7:0];
            hdr_buf[26] <= src_ip[31:24];
            hdr_buf[27] <= src_ip[23:16];
            hdr_buf[28] <= src_ip[15:8];
            hdr_buf[29] <= src_ip[7:0];
            hdr_buf[30] <= des_ip[31:24];
            hdr_buf[31] <= des_ip[23:16];
            hdr_buf[32] <= des_ip[15:8];
            hdr_buf[33] <= des_ip[7:0];

            // ---------- UDP 头 (8 字节) ----------
            hdr_buf[34] <= src_port[15:8];
            hdr_buf[35] <= src_port[7:0];
            hdr_buf[36] <= des_port[15:8];
            hdr_buf[37] <= des_port[7:0];
            hdr_buf[38] <= L_UDP_TOT[15:8];
            hdr_buf[39] <= L_UDP_TOT[7:0];
            hdr_buf[40] <= 8'h00;  // Checksum Off
            hdr_buf[41] <= 8'h00;

            if (wrusedw >= L_DATA_LEN) state <= PRE;
          end

          PRE: begin
            n_txen  <= 1;
            c_rst_n <= 1;
            n_txd   <= (hdr_cnt < 7) ? 8'h55 : 8'hD5;

            if (hdr_cnt == 7) begin
              hdr_cnt <= 0;
              state   <= HDRS;
            end else hdr_cnt <= hdr_cnt + 1;
          end

          HDRS: begin
            c_en <= 1;
            // 首包篡改目标端口作为 FPGA 同步暗号
            if (hdr_cnt == 35 && is_first_packet) n_txd <= 8'hFF;
            else n_txd <= hdr_buf[hdr_cnt];

            // Normal FIFO 提前 2 拍请求
            if (hdr_cnt == 40) begin
              fifo_rdreq <= 1;
            end

            if (hdr_cnt == 41) begin
              hdr_cnt <= 0;
              state   <= DATA;
            end else hdr_cnt <= hdr_cnt + 1;
          end

          DATA: begin
            n_txd <= fifo_q;
            // 提前一拍拉低读请求
            if (data_cnt == 16'd2) begin
              fifo_rdreq <= 0;
            end

            if (data_cnt == 16'd1) begin
              state   <= CRC;
              hdr_cnt <= 0;
            end else data_cnt <= data_cnt - 1;
          end

          CRC: begin
            c_en <= 0;
            // [Ethereal注释] 分支选择 2：依据 hdr_cnt 选择状态或算法路径；default 覆盖非法或空闲条件。
            case (hdr_cnt)
              0: n_txd <= c_out[31:24];
              1: n_txd <= c_out[23:16];
              2: n_txd <= c_out[15:8];
              3: begin
                n_txd   <= c_out[7:0];
                state   <= IPG;
                hdr_cnt <= 0;
              end
              default: n_txd <= 8'h00;
            endcase
            if (hdr_cnt != 3) hdr_cnt <= hdr_cnt + 1;
          end

          IPG: begin
            n_txen <= 0;
            if (hdr_cnt >= 23) begin
              hdr_cnt <= 0;
              state   <= IDLE;
            end else hdr_cnt <= hdr_cnt + 1;
          end
        endcase
      end
    end
  end

  // [Ethereal注释] 时序过程 3：由 Clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
  always @(posedge Clk) begin
    GMII_TXD  <= n_txd;
    GMII_TXEN <= n_txen;
  end
endmodule
