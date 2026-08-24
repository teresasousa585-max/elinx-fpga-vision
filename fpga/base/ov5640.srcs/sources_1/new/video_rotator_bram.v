// =============================================================================
// 文件名称：video_rotator_bram.v
// 主要模块：video_rotator_bram
// 功能说明：利用片上存储完成视频帧旋转。
// 维护说明：修改接口或时序时，请同步更新本文件注释和上层例化。
// =============================================================================

`timescale 1ns / 1ps

module video_rotator_bram (
    input wire       wr_clk,   // 写时钟 (摄像头)
    input wire       rd_clk,   // 读时钟 (HDMI 50MHz)
    input wire       rst,      // 异步复位输入 (来自 sys_clk)
    input wire [1:0] rot_mode, // 2:90度旋转, 3:仿射错切(平移形变)

    input wire        i_vsync,
    input wire        i_de,
    input wire [15:0] i_rgb,

    input  wire [10:0] o_h_cnt,
    input  wire [ 9:0] o_v_cnt,
    output wire        o_de,     // 改为 wire，直接输出消除1拍延迟
    output wire [15:0] o_rgb     // 改为 wire，直接输出消除1拍延迟
);

  // ---------- 1. 异步复位同步处理 (CDC安全) ----------
  reg rst_wr_d1, rst_wr;
  always @(posedge wr_clk) begin
    {rst_wr, rst_wr_d1} <= {rst_wr_d1, rst};
  end

  reg rst_rd_d1, rst_rd;
  always @(posedge rd_clk) begin
    {rst_rd, rst_rd_d1} <= {rst_rd_d1, rst};
  end

  // ---------- 2. 模式控制信号同步与防抖 ----------
  reg [1:0] rot_mode_d1, rot_mode_d2;
  reg [1:0] active_rot_mode;
  always @(posedge rd_clk) begin
    if (rst_rd) begin
      rot_mode_d1 <= 2'd0;
      rot_mode_d2 <= 2'd0;
      active_rot_mode <= 2'd0;
    end else begin
      rot_mode_d1 <= rot_mode;
      rot_mode_d2 <= rot_mode_d1;
      // 仅在一帧的起点更新模式，防止画面撕裂
      if (o_h_cnt == 11'd0 && o_v_cnt == 10'd0) begin
        active_rot_mode <= rot_mode_d2;
      end
    end
  end

  // ---------- 写端控制 ----------
  reg r_vsync, r_de;
  reg [15:0] r_rgb;
  always @(posedge wr_clk) begin
    r_vsync <= i_vsync;
    r_de <= i_de;
    r_rgb <= i_rgb;
  end

  reg pingpong_wr, vsync_d1, vsync_d2;
  always @(posedge wr_clk) begin
    if (rst_wr) begin
      vsync_d1 <= 1'b0;
      vsync_d2 <= 1'b0;
      pingpong_wr <= 1'b0;
    end else begin
      vsync_d1 <= r_vsync;
      vsync_d2 <= vsync_d1;
      if (vsync_d1 && !vsync_d2) pingpong_wr <= ~pingpong_wr;
    end
  end

  // 核心锁：帧级同步，只在屏幕原点(0,0)切换读指针，彻底消灭绿线
  reg pingpong_wr_sync1, pingpong_wr_sync2;
  always @(posedge rd_clk) begin
    if (rst_rd) begin
      pingpong_wr_sync1 <= 1'b0;
      pingpong_wr_sync2 <= 1'b0;
    end else begin
      pingpong_wr_sync1 <= pingpong_wr;
      pingpong_wr_sync2 <= pingpong_wr_sync1;
    end
  end

  reg pingpong_rd;
  always @(posedge rd_clk) begin
    if (rst_rd) pingpong_rd <= 1'b0;
    else if (o_h_cnt == 11'd0 && o_v_cnt == 10'd0) pingpong_rd <= pingpong_wr_sync2;
  end

  // ---------- 写入地址生成 ----------
  reg [16:0] wr_offset;
  always @(posedge wr_clk) begin
    if (vsync_d1 && !vsync_d2) wr_offset <= 17'd0;
    else if (r_de && wr_offset < 17'd65535) wr_offset <= wr_offset + 1'b1;
  end

  // 物理双区隔离：使用 65536 翻转最高位
  wire [16:0] final_wr_addr_comb = (pingpong_wr ? 17'd65536 : 17'd0) + wr_offset;
  reg [16:0] final_wr_addr_reg;
  reg final_wr_en_reg;
  reg [15:0] final_wr_data_reg;
  always @(posedge wr_clk) begin
    final_wr_addr_reg <= final_wr_addr_comb;
    final_wr_en_reg   <= r_de;
    final_wr_data_reg <= r_rgb;
  end


  // 【Pipeline Stage 1】: 坐标边界判断与减法 (消耗 1 拍)
  reg in_win_90_s1, in_win_shear_s1;
  reg [10:0] h_sub_90_s1, h_sub_shear_s1;
  reg [9:0] v_sub_90_s1, v_sub_shear_s1;

  always @(posedge rd_clk) begin
    // Mode 9: 90度旋转 150x256
    in_win_90_s1 <= (o_h_cnt >= 11'd437 && o_h_cnt < 11'd587) && (o_v_cnt >= 10'd172 && o_v_cnt < 10'd428);
    h_sub_90_s1 <= o_h_cnt - 11'd437;
    v_sub_90_s1 <= o_v_cnt - 10'd172;

    // Mode 13: 错切 331x150
    in_win_shear_s1 <= (o_h_cnt >= 11'd347 && o_h_cnt < 11'd678) && (o_v_cnt >= 10'd225 && o_v_cnt < 10'd375);
    h_sub_shear_s1 <= o_h_cnt - 11'd347;
    v_sub_shear_s1 <= o_v_cnt - 10'd225;
  end

  // ---------- 3. 修复仿射错切隐式位宽截断 ----------
  wire [10:0] orig_x_shear_comb = h_sub_shear_s1 - (v_sub_shear_s1 >> 1);

  // 【Pipeline Stage 2】: 核心映射与读使能生成 (消耗 1 拍)
  reg [16:0] rd_offset_s2;
  reg rd_en_s2;

  always @(posedge rd_clk) begin
    if (active_rot_mode == 2'd2) begin
      // --- 90度旋转 ---
      if (in_win_90_s1) begin
        rd_en_s2 <= 1'b1;
        rd_offset_s2 <= {1'b0, 8'd149 - h_sub_90_s1[7:0], v_sub_90_s1[7:0]};
      end else begin
        rd_en_s2 <= 1'b0;
        rd_offset_s2 <= 17'd0;
      end
    end else if (active_rot_mode == 2'd3) begin
      // --- 仿射错切 ---
      if (in_win_shear_s1) begin
        // 边界保护逻辑：切出标准的平行四边形
        // 使用修正后全位宽的 orig_x 进行判断，规避溢出风险
        if (h_sub_shear_s1 >= (v_sub_shear_s1 >> 1) && orig_x_shear_comb < 11'd256) begin
          rd_en_s2 <= 1'b1;
          rd_offset_s2 <= {1'b0, v_sub_shear_s1[7:0], orig_x_shear_comb[7:0]};
        end else begin
          rd_en_s2 <= 1'b0;
          rd_offset_s2 <= 17'd0;
        end
      end else begin
        rd_en_s2 <= 1'b0;
        rd_offset_s2 <= 17'd0;
      end
    end else begin
      // 兜底安全逻辑
      rd_en_s2 <= 1'b0;
      rd_offset_s2 <= 17'd0;
    end
  end

  // 【Pipeline Stage 3 & 4】: BRAM 本身的 2 拍物理延迟
  wire [16:0] final_rd_addr = (pingpong_rd ? 17'd0 : 17'd65536) + rd_offset_s2;
  wire [15:0] ram_q;

  ram_cascaded_128k u_frame_buffer (
      .wr_clk(wr_clk),
      .rd_clk(rd_clk),
      .data(final_wr_data_reg),
      .wr_addr(final_wr_addr_reg),
      .wr_en(final_wr_en_reg),
      .rd_addr(final_rd_addr),
      .rd_en(rd_en_s2),
      .q(ram_q)
  );

  // 严格对齐输出信号：延迟 rd_en_s2 两次以对齐 ram_q 的 2 拍延迟
  reg rd_en_s3, rd_en_s4;
  always @(posedge rd_clk) begin
    if (rst_rd) begin
      rd_en_s3 <= 1'b0;
      rd_en_s4 <= 1'b0;
    end else begin
      rd_en_s3 <= rd_en_s2;
      rd_en_s4 <= rd_en_s3;
    end
  end

  // ---------- 4. 消除1拍冗余延迟，实现完美的4拍对齐 ----------
  // 此时 o_de 和 o_rgb 相对于 o_h_cnt 输入正好是 4 拍延迟 (s1 -> s2 -> BRAM x2)
  // 完美对接 top.v 里的 current_pixel_d4 逻辑！
  assign o_de  = rd_en_s4;
  assign o_rgb = rd_en_s4 ? ram_q : 16'h0000;

endmodule
