// =============================================================================
// 项目名称：2026 年全国大学生集成电路创新创业大赛国奖项目
// 工程分区：基础图像处理工程（base）
// 文件名称：ov5640_capture.v
// 主要模块：ov5640_capture
// 功能分类：摄像头接口
// 功能说明：在像素时钟域采集 OV5640 RGB565 数据及同步信号，形成内部视频流。
// 输入概述：外设时钟、同步/像素数据或待显示视频流。
// 输出概述：初始化控制、规范化视频流或板级显示接口信号。
// 时序约束：外设接口遵循对应器件时序；进入算法通路前须保持 HS/VS/DE 与像素对齐。
// 关联文件：ov5640_i2c_init.v、top.v
// 维护要求：修改端口、位宽、流水线延迟或模式编码时，必须同步更新上层例化与项目文档。
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
