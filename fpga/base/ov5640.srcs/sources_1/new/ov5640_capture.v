// =============================================================================
// 文件名称：ov5640_capture.v
// 主要模块：ov5640_capture
// 功能说明：采集 OV5640 像素与同步信号，输出连续 RGB565 数据流。
// 维护说明：修改接口或时序时，请同步更新本文件注释和上层例化。
// =============================================================================

`timescale 1ns / 1ps

module ov5640_capture (
    input wire i_pclk,
    input wire i_rst,

    input wire       i_vsync,
    input wire       i_href,
    input wire [7:0] i_data,

    output wire        o_frame_vsync,
    output reg         o_data_en,
    output reg  [15:0] o_rgb565
);

  reg rst_pclk_d1, rst_pclk_d2;
  always @(posedge i_pclk) begin
    rst_pclk_d1 <= i_rst;
    rst_pclk_d2 <= rst_pclk_d1;
  end

  reg vsync_d1, vsync_d2;
  reg href_d1, href_d2;
  reg [7:0] data_d1;

  always @(negedge i_pclk) begin
    if (rst_pclk_d2) begin
      vsync_d1 <= 1'b0;
      vsync_d2 <= 1'b0;
      href_d1  <= 1'b0;
      href_d2  <= 1'b0;
      data_d1  <= 8'd0;
    end else begin
      vsync_d1 <= i_vsync;
      vsync_d2 <= vsync_d1;
      href_d1  <= i_href;
      href_d2  <= href_d1;
      data_d1  <= i_data;
    end
  end

  // 提取 VSYNC 下降沿作为帧起始 (OV5640默认场同步为高电平期间消隐)
  assign o_frame_vsync = vsync_d2;

  reg       byte_flag;
  reg [7:0] data_high;

  always @(negedge i_pclk) begin
    if (rst_pclk_d2) begin
      byte_flag <= 1'b0;
      o_data_en <= 1'b0;
      o_rgb565  <= 16'd0;
    end else if (href_d1) begin
      if (byte_flag == 1'b0) begin
        data_high <= data_d1;
        byte_flag <= 1'b1;
        o_data_en <= 1'b0;
      end else begin
        o_rgb565  <= {data_high, data_d1};
        byte_flag <= 1'b0;
        o_data_en <= 1'b1;
      end
    end else begin
      byte_flag <= 1'b0;
      o_data_en <= 1'b0;
    end
  end

endmodule
