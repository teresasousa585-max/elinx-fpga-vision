// =============================================================================
// 文件名称：anguang_guided.v
// 主要模块：anguang_guided
// 功能说明：利用引导滤波估计暗光增强所需的光照分量。
// 维护说明：修改接口或时序时，请同步更新本文件注释和上层例化。
// =============================================================================

`timescale 1 ns/ 1 ps
module anguang_guided#(
parameter H_TOTAL = 11'd1344,// ʵ���п�����     
parameter EPSILON=16'd2000 // ƽ��ǿ�ȿ��Ʋ�����Խ��Խƽ��
)(
    input  wire        i_clk,
    input  wire        i_rst, 
    
    input  wire [23:0]  i_ycbcr,
    input  wire        i_hs,
    input  wire        i_vs,
    input  wire        i_de,
    input  wire [23:0]  i_rgb,
    
    output wire        o_hs_out,
    output wire        o_vs_out,
    output wire        o_de_out,
    output wire [7:0]  o_y,
    output  wire [23:0]  o_rgb
);
wire m1_hs,m1_vs,m1_de;
wire m2_hs,m2_vs,m2_de;
wire m3_hs,m3_vs,m3_de;
wire m4_hs,m4_vs,m4_de;
wire m5_hs,m5_vs,m5_de;
wire m6_hs,m6_vs,m6_de;

wire [11:0] mean_Y;
wire [23:0] mean_Y2;
wire [23:0] ycbcr_sync;
wire [23:0] center_ycbcr ;
wire [23:0] center_rgb;
wire [10:0] col_sum_y;
wire [18:0] col_sum_y2;

guided_line_buffer #(
   .H_TOTAL(H_TOTAL) 
)u_line_buffer_anguang (
    .i_clk(i_clk),
    .i_rst(i_rst),

    .i_hs(i_hs), 
    .i_vs(i_vs), 
    .i_data_en(i_de), 
    .i_ycbcr(i_ycbcr), 
    .i_rgb(i_rgb),
    //���
    .o_col_sum_Y(col_sum_y),
    .o_col_sum_Y2(col_sum_y2),

    .o_center_ycbcr(center_ycbcr),
    .o_hs_center(m1_hs),
    .o_vs_center(m1_vs),
    .o_de_center(m1_de),
    .o_center_rgb(center_rgb)
);

wire [23:0] center_rgb_d1;
box_filter_y u_box_filter_y_anguang (
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_col_sum_Y(col_sum_y),
    .i_col_sum_Y2(col_sum_y2),
    .i_center_ycbcr(center_ycbcr),
    .i_rgb(center_rgb),
    .i_hs(m1_hs), // ע�������� m1_hs��������������ͬ��
    .i_vs(m1_vs), // ע�������� m1_vs��������������ͬ��
    .i_de(m1_de), 

    .o_mean_Y(mean_Y), 
    .o_mean_Y2(mean_Y2), 

    .o_ycbcr_sync(ycbcr_sync), 
    .o_rgb(center_rgb_d1),
    .o_hs_sync(m2_hs),
    .o_vs_sync(m2_vs),
    .o_de_sync(m2_de)
);

wire [11:0] a_val;
wire [11:0] b_val;
wire [23:0] ycbcr_sync1;
wire [23:0] center_rgb_d2;
guided_var_a_b #(
    .EPSILON(EPSILON) // ƽ��ǿ�ȿ��Ʋ���
)u_guided_var_a_b_anguang (
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_mean_Y(mean_Y),
    .i_mean_Y2(mean_Y2),
    .i_ycbcr_sync(ycbcr_sync),
    .i_rgb(center_rgb_d1),
    .i_hs(m2_hs), // ע�������� m2_hs��������������ͬ��
    .i_vs(m2_vs), // ע�������� m2_vs������������
    .i_de(m2_de),
    .o_a_val(a_val), // ���� a �� b ��ֵ��ʱ������ˣ����������Ҫ��������������˿�
    .o_b_val(b_val),
    .o_ycbcr_out(ycbcr_sync1), 
    .o_rgb(center_rgb_d2),
    .o_hs_out(m3_hs),
    .o_vs_out(m3_vs),
    .o_de_out(m3_de)
);

wire [14:0] col_sum_a;
wire [14:0] col_sum_b;
wire [23:0] ycbcr_sync2;
wire [23:0] center_rgb_d3;
guided_line_buffer_a_b #(
    .H_TOTAL(H_TOTAL)
)u_line_buffer_a_b (
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_hs(m3_hs), // ע�������� m3_hs��������������ͬ��
    .i_vs(m3_vs), // ע�������� m3_vs������������
    .i_de(m3_de),
    .i_ycbcr_delayed(ycbcr_sync1), // һ·��������ԭʼ YCbCr ���ݣ����ֶ���
    .i_rgb(center_rgb_d2),
    .i_a(a_val),
    .i_b(b_val),
    .o_col_sum_a(col_sum_a),
    .o_col_sum_b(col_sum_b),
    .o_center_ycbcr(ycbcr_sync2), // ֱ������������������� YCbCr ����
    .o_rgb(center_rgb_d3),
    .o_hs_center(m4_hs),
    .o_vs_center(m4_vs),
    .o_de_center(m4_de)
);
wire [23:0] ycbcr_sync3;
wire [11:0] mean_a;
wire [11:0] mean_b;
wire [23:0] center_rgb_d4;
box_filter_ab u_box_filter_ab (
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_col_sum_a(col_sum_a),
    .i_col_sum_b(col_sum_b),
    .i_center_ycbcr(ycbcr_sync2), // ֱ������������������� YCbCr ���ݽ����˲�
    .i_rgb(center_rgb_d3),
    .i_hs(m4_hs), // ע�������� m4_hs��������������ͬ��
    .i_vs(m4_vs), // ע�������� m4_vs��������������ͬ��
    .i_de(m4_de), 

    .o_mean_a(mean_a), 
    .o_mean_b(mean_b), 

    .o_ycbcr_sync(ycbcr_sync3), 
    .o_rgb(center_rgb_d4),
    .o_hs_sync(m5_hs), // �ٴζ�����ͬ���źţ����������ģ��ͬ��
    .o_vs_sync(m5_vs),
    .o_de_sync(m5_de)
);
wire [23:0] final_ycbcr;
wire [23:0] center_rgb_d5;
guided_final_rebuild u_guided_final_rebuild (
    .i_clk(i_clk),
    .i_rst(i_rst),  
    .i_mean_a(mean_a), // ���� box_filter_ab �� a ��ֵ
    .i_mean_b(mean_b), // ���� box_filter_ab �� b ��ֵ
    .i_ycbcr_sync(ycbcr_sync3), // ���� box_filter_ab �Ķ����� YCbCr ����
    .i_rgb(center_rgb_d4),
    .i_hs(m5_hs), // ע�������� m5_hs��������������ͬ��
    .i_vs(m5_vs), // ע�������� m5_vs��������������ͬ��
    .i_de(m5_de), // ע�������� m5_de��������������ͬ��

    .o_final_ycbcr(final_ycbcr), // ��������� YCbCr ���ݣ��� HDMI ���ʹ��
    .o_rgb(center_rgb_d5),
    .o_hs_out(m6_hs),      // ��������� HSYNC �ź�
    .o_vs_out(m6_vs),      // ��������� VSYNC �ź�
    .o_de_out(m6_de)       // �������������ʹ���ź�
);
assign o_hs_out = m6_hs;
assign o_vs_out = m6_vs;
assign o_de_out = m6_de;
assign o_y = final_ycbcr[23:16];
assign o_rgb = center_rgb_d5;
endmodule


 



