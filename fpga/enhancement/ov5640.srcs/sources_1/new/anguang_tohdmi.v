// =============================================================================
// 文件名称：anguang_tohdmi.v
// 主要模块：anguang_tohdmi
// 功能说明：对齐暗光增强结果与 HDMI 视频时序。
// 维护说明：修改接口或时序时，请同步更新本文件注释和上层例化。
// =============================================================================

`timescale 1 ns/ 1 ps
module anguang_tohdmi#(
parameter H_TOTAL = 11'd1344,// ʵ���п�����     
parameter EPSILON=16'd1000

)(
input wire i_clk,
input wire i_rst,

input wire i_hs,
input wire i_vs,
input wire i_de,
input wire [23:0] i_rgb_data,

// ����ź�ֱ�����ӵ� HDMI ����˿�
output wire o_hs,
output wire o_vs,
output wire o_de,
output wire [23:0] o_rgb_data,
output wire [23:0] o_original_rgb_data// ԭʼ����
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
    .i_rgb(original_rgb_data),//�����˲��������
    .o_hs_out(m2_hs),
    .o_vs_out(m2_vs),
    .o_de_out(m2_de),
    .o_y(guided_y),
    .o_rgb(original_rgb_data_d1)//����˲�������ݿ����������Ա�
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
//assign o_rgb_data = o_de?filtered_rgb:24'h000000; // ֱ������˲���������������ݣ����� HDMI ����˿�;
endmodule