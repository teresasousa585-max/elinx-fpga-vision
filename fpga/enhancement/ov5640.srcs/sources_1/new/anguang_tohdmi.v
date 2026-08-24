// =============================================================================
// 项目名称：2026 年全国大学生集成电路创新创业大赛国奖项目
// 工程分区：图像增强工程（enhancement）
// 文件名称：anguang_tohdmi.v
// 主要模块：anguang_tohdmi
// 功能分类：暗光增强算法
// 功能说明：组织暗光照度估计、增强应用和视频时序对齐，输出 RGB888 增强画面。
// 输入概述：像素数据及 HS/VS/DE 视频同步信号；控制参数由模式或模块参数给出。
// 输出概述：处理后的像素流，以及与流水线延迟严格匹配的 HS/VS/DE 信号。
// 时序约束：像素数据在视频像素时钟上升沿处理；复位极性以模块端口定义为准。
// 关联文件：anguang_guided.v、anguang_enhance_apply.v
// 维护要求：修改端口、位宽、流水线延迟或模式编码时，必须同步更新上层例化与项目文档。
// =============================================================================
`timescale 1 ns/ 1 ps
module anguang_tohdmi#(
parameter H_TOTAL = 11'd1344, // 每行总时钟数（含消隐区）
parameter EPSILON=16'd1000

)(
input wire i_clk,
input wire i_rst,

input wire i_hs,
input wire i_vs,
input wire i_de,
input wire [23:0] i_rgb_data,

// 输出信号直接连接到 HDMI 输出端口
output wire o_hs,
output wire o_vs,
output wire o_de,
output wire [23:0] o_rgb_data,
output wire [23:0] o_original_rgb_data// 原始数据
);

wire [23:0] ycbcr_data;
wire [23:0] original_rgb_data;
wire [23:0] filtered_rgb;
wire m0_hs,m0_vs,m0_de;
wire m1_hs,m1_vs,m1_de;
wire m2_hs,m2_vs,m2_de;
wire m3_hs,m3_vs,m3_de;
wire m4_hs,m4_vs,m4_de;
wire m5_hs,m5_vs,m5_de;
wire m6_hs,m6_vs,m6_de;


RGB_to_YCbCr u_rgb2ycbcr_anguang (
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_hs(i_hs),
    .i_vs(i_vs),
    .i_data_en(i_de),
    .i_rgb(i_rgb_data), 

    .o_hs(m1_hs),
    .o_vs(m1_vs),
    .o_data_en(m1_de),
    .o_ycbcr(ycbcr_data),
    .o_raw_rgb(original_rgb_data)
); 

wire [23:0] original_rgb_data_d1;
wire [7:0] guided_y;
anguang_guided #(
   .H_TOTAL(H_TOTAL) ,
   .EPSILON(EPSILON)
)u_anguang_guided (
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_ycbcr(ycbcr_data),
    .i_hs(m1_hs),
    .i_vs(m1_vs),
    .i_de(m1_de),
    .i_rgb(original_rgb_data),//输入滤波后的数据
    .o_hs_out(m2_hs),
    .o_vs_out(m2_vs),
    .o_de_out(m2_de),
    .o_y(guided_y),
    .o_rgb(original_rgb_data_d1)//输出滤波后的数据可以用来做对比
);
wire [23:0] original_rgb_data_d2;
wire [23:0] enhanced_rgb_data;
anguang_enhance_apply u_anguang_enhance_apply (
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_y_guided(guided_y),
    .i_rgb_aligned(original_rgb_data_d1),
    .i_hs(m2_hs),
    .i_vs(m2_vs),
    .i_de(m2_de),

    .o_rgb_original(original_rgb_data_d2),
    .o_rgb_final(enhanced_rgb_data),
    .o_hs(m3_hs),
    .o_vs(m3_vs),
    .o_de(m3_de)
);
/*
wire [23:0] enhanced_rgb_data_mid;
wire [23:0] original_rgb_data_d3;
anguang_midvalue u_anguang_midvalue (
    .i_clk(i_clk),
    .i_rst(i_rst),

    .i_hs(m3_hs),
    .i_vs(m3_vs),
    .i_de(m3_de),

    .i_rgb_enhanced(enhanced_rgb_data),
    .i_rgb_original(original_rgb_data_d2),

    .o_rgb_filtered(enhanced_rgb_data_mid),
    .o_rgb_original_sync(original_rgb_data_d3),
    .o_hs(m4_hs),
    .o_vs(m4_vs),
    .o_de(m4_de)
);
*/
assign o_rgb_data= enhanced_rgb_data;
assign o_hs = m3_hs;
assign o_vs = m3_vs;
assign o_de = m3_de;
assign o_original_rgb_data = original_rgb_data_d2;
//assign o_rgb_data = o_de?filtered_rgb:24'h000000; // 直接输出滤波后的中心像素数据，送往 HDMI 输出端口;
endmodule
