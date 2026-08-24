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

    output wire o_frame_vsync,  // 帧同步清空信号

    output wire        o_hs,
    output wire        o_vs,
    output wire        o_de,
    output reg  [23:0] o_rgb_out, // 送给屏幕的对齐数据

    // 将内部坐标给 top.v 以供画中画定位
    output wire [10:0] o_h_cnt,
    output wire [ 9:0] o_v_cnt,
    output wire        o_pre_de  //输出基础有效区，供Top产生读请求
);

  localparam H_ACTIVE = 11'd1024, H_FP = 11'd160, H_SYNC = 11'd20, H_BP = 11'd140, H_TOTAL = 11'd1344;
  localparam V_ACTIVE = 10'd600, V_FP = 10'd12, V_SYNC = 10'd3, V_BP = 10'd20, V_TOTAL = 10'd635;

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
      end else h_cnt <= h_cnt + 1'b1;
    end
  end

  wire pre_hs = ((h_cnt >= H_ACTIVE + H_FP) && (h_cnt < H_ACTIVE + H_FP + H_SYNC));
  wire pre_vs = ((v_cnt >= V_ACTIVE + V_FP) && (v_cnt < V_ACTIVE + V_FP + V_SYNC));
  wire pre_de = (h_cnt < H_ACTIVE) && (v_cnt < V_ACTIVE);

  // 新增：输出基础显示区间
  assign o_pre_de = pre_de;

  reg vs_d1, vs_d2;
  always @(posedge i_pclk) begin
    if (i_rst) begin
      vs_d1 <= 1'b0;
      vs_d2 <= 1'b0;
    end else begin
      vs_d1 <= pre_vs;
      vs_d2 <= vs_d1;
    end
  end
  assign o_frame_vsync = vs_d1 && !vs_d2;

  //  4 级移位寄存器，拖延屏幕同步信号
  reg [3:0] hs_pipe, vs_pipe, de_pipe;
  always @(posedge i_pclk) begin
    if (i_rst) begin
      hs_pipe   <= 4'd0;
      vs_pipe   <= 4'd0;
      de_pipe   <= 4'd0;
      o_rgb_out <= 24'd0;
    end else begin
      hs_pipe   <= {hs_pipe[2:0], pre_hs};
      vs_pipe   <= {vs_pipe[2:0], pre_vs};
      de_pipe   <= {de_pipe[2:0], pre_de};

      // 只有在延迟了 4 拍的数据有效门开启时，才吃入 i_rgb
      o_rgb_out <= de_pipe[2] ? i_rgb : 24'h000000;
    end
  end

  // 将延迟对齐后的同步信号发给物理引脚
  assign o_hs = hs_pipe[3];
  assign o_vs = vs_pipe[3];
  assign o_de = de_pipe[3];


  assign o_h_cnt = h_cnt;
  assign o_v_cnt = v_cnt;

endmodule


