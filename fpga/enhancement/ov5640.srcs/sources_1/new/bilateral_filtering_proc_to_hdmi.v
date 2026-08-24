// =============================================================================
// 文件名称：bilateral_filtering_proc_to_hdmi.v
// 主要模块：bilateral_filtering_proc_to_hdmi
// 功能说明：组织双边滤波流水线并对齐 HDMI 视频时序。
// 维护说明：修改接口或时序时，请同步更新本文件注释和上层例化。
// =============================================================================

`timescale 1 ns/ 1 ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 04-13-2026 16:31:17
// Design Name:
// Module Name: bilateral_filtering_proc_to_hdmi
// Project Name:
// Target Devices:
// Tool Versions:
// Description:
//
// Dependencies:
//
// Revision:
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////


module bilateral_filtering_proc_to_hdmi#(
parameter PIXEL_PER_LINE = 11'd1024     
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
output wire [23:0] o_rgb_data
);
wire [23:0] p11,p12,p13;
wire [23:0] p21,p22,p23;    
wire [23:0] p31,p32,p33;
wire m_hs,m_vs,m_de;
wire [23:0] ycrcb_data;

wire m0_hs,m0_vs,m0_de;
wire m1_hs,m1_vs,m1_de;
wire m2_hs,m2_vs,m2_de;
RGB_to_YCbCr u_rgb_to_ycbcr (
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_hs(i_hs),
    .i_vs(i_vs),
    .i_data_en(i_de),
    .i_rgb(i_rgb_data), 

    .o_hs(m0_hs),
    .o_vs(m0_vs),
    .o_data_en(m0_de),
    .o_ycbcr(ycrcb_data) 
);  

wire [23:0] p22_ycbcr ;
bilateral_filtering_Line_buffer #(
    .H_TOTAL(11'd1344) 
) u_line_buffer (
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_hs(m0_hs), // ע�������� m0_hs��������������ͬ��
    .i_vs(m0_vs), // ע�������� m0_vs��������������ͬ��
    .i_data_en(m0_de), 
    .i_rgb_data(ycrcb_data), // ֱ���� YCbCr ���ݽ����˲�������ɫ����Ϣ������

    .o_p11(p11),.o_p12(p12),.o_p13(p13),
    .o_p21(p21),.o_p22(p22_ycbcr),.o_p23(p23),
    .o_p31(p31),.o_p32(p32),.o_p33(p33),

    .o_hs(m1_hs),
    .o_vs(m1_vs),
    .o_data_en(m1_de) 
);

wire [23:0] filtered_ycbcr;
 bilateral_core u_bilateral_core (
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_hs(m1_hs),
    .i_vs(m1_vs),
    .i_data_en(m1_de),

    .i_p11(p11),.i_p12(p12),.i_p13(p13),
    .i_p21(p21),.i_p22(p22_ycbcr),.i_p23(p23),
    .i_p31(p31),.i_p32(p32),.i_p33(p33),

    .o_hs(m2_hs),
    .o_vs(m2_vs),
    .o_data_en(m2_de),
    .o_ycbcr_filtered(filtered_ycbcr) // ֱ������˲���� YCbCr ���ݣ����� RGB ת��ģ��
    );
YCbCr_to_RGB u_ycbcr_to_rgb (
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_hs(m2_hs),
    .i_vs(m2_vs),
    .i_data_en(m2_de),
    .i_ycbcr(filtered_ycbcr), // ֱ�������˲���� YCbCr ���ݽ���ת��

    .o_hs(m_hs),    
    .o_vs(m_vs),
    .o_data_en(m_de),
    .o_rgb(p22) 
);
assign o_hs = m_hs;
assign o_vs = m_vs;
assign o_de = m_de;

/*
assign o_hs = i_hs; // ֱ�Ӵ��������ͬ���źţ�����ʱ��һ����
assign o_vs = i_vs;
assign o_de = i_de;
*/
assign o_rgb_data = o_de?p22:24'h000000; // ֱ������˲���������������ݣ����� HDMI ����˿�;
endmodule
