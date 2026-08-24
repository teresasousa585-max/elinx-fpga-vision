// =============================================================================
// 文件名称：hdmi.v
// 主要模块：hdmi
// 功能说明：生成 HDMI 显示时序并输出处理后的视频数据。
// 维护说明：修改接口或时序时，请同步更新本文件注释和上层例化。
// =============================================================================

`timescale 1ns / 1ps

module hdmi (
    input wire        i_pclk,  // 像素时钟,50MHz
    input wire        i_rst,
    input wire [23:0] i_rgb,   // 接收来自SDRAM 的像素数据

    output wire o_fifo_rd_req,  // FIFO读请求
    output wire o_frame_vsync,  // 帧同步清空信号

    output wire        o_hs,
    output wire        o_vs,
    output wire        o_de,
    output reg  [23:0] o_rgb_out  // 送给屏幕的对齐数据
);

  // 1024x600 @ 60Hz 标准时序 (像素时钟 ~50MHz)
  localparam H_ACTIVE = 11'd1024;
  localparam H_FP = 11'd160;
  localparam H_SYNC = 11'd20;
  localparam H_BP = 11'd140;
  localparam H_TOTAL = 11'd1344;

  localparam V_ACTIVE = 10'd600;
  localparam V_FP = 10'd12;
  localparam V_SYNC = 10'd3;
  localparam V_BP = 10'd20;
  localparam V_TOTAL = 10'd635;

  // 计数器
  reg [10:0] h_cnt;
  reg [ 9:0] v_cnt;

  always @(posedge i_pclk) begin
    if (i_rst) begin
      h_cnt <= 11'd0;
      v_cnt <= 10'd0;
    end else begin
      if (h_cnt == H_TOTAL - 1) begin
        h_cnt <= 11'd0;
        if (v_cnt == V_TOTAL - 1) v_cnt <= 10'd0;
        else v_cnt <= v_cnt + 1'b1;
      end else begin
        h_cnt <= h_cnt + 1'b1;
      end
    end
  end

  // 基础同步信号生成 (使用组合逻辑)
  wire pre_hs = ((h_cnt >= H_ACTIVE + H_FP) && (h_cnt < H_ACTIVE + H_FP + H_SYNC));
  wire pre_vs = ((v_cnt >= V_ACTIVE + V_FP) && (v_cnt < V_ACTIVE + V_FP + V_SYNC));
  wire pre_de = (h_cnt < H_ACTIVE) && (v_cnt < V_ACTIVE);

  // 提前一拍发起读请求，下一拍数据 i_rgb 刚好到达，用于对齐后续的输出时序
  assign o_fifo_rd_req = pre_de;

  // 消除毛刺的 VSYNC 边沿检测 (用于外部帧同步/清空 FIFO)
  reg vs_d1, vs_d2;
  always @(posedge i_pclk) begin
    if (i_rst) begin
      vs_d1 <= 1'b0;
      vs_d2 <= 1'b0;
    end else begin
      vs_d1 <= pre_vs;  // 寄存一拍，消除比较器可能产生的组合逻辑毛刺
      vs_d2 <= vs_d1;  // 再寄存一拍，用于边沿检测
    end
  end
  // 提取正极性 VSYNC 的上升沿作为一帧开始的标志
  assign o_frame_vsync = vs_d1 && !vs_d2;

  // 两级流水线对齐 
  reg r_hs, r_vs, r_de;
  reg rr_hs, rr_vs, rr_de;

  always @(posedge i_pclk) begin
    if (i_rst) begin
      r_hs      <= 1'b0;  // 正极性默认拉低
      r_vs      <= 1'b0;
      r_de      <= 1'b0;
      rr_hs     <= 1'b0;
      rr_vs     <= 1'b0;
      rr_de     <= 1'b0;
      o_rgb_out <= 24'd0;
    end else begin
      // 第一级寄存：对齐 FIFO 送出的数据 (i_rgb 晚 pre_de 一拍到达)
      r_hs <= pre_hs;
      r_vs <= pre_vs;
      r_de <= pre_de;

      // 根据第一级有效的 r_de 锁存数据。此时 r_de 与 i_rgb 是完全同频同相的
      o_rgb_out <= r_de ? i_rgb : 24'h000000;

      // 第二级寄存：对齐 o_rgb_out 的输出延迟
      // 因为 o_rgb_out 经历了一次时序逻辑寄存，控制信号必须再打一拍去陪跑
      rr_hs <= r_hs;
      rr_vs <= r_vs;
      rr_de <= r_de;
    end
  end

  // 最终输出：完全对齐的时序
  assign o_hs = rr_hs;
  assign o_vs = rr_vs;
  assign o_de = rr_de;

endmodule
