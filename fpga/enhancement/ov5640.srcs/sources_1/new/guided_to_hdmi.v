// =============================================================================
// 项目名称：2026 年全国大学生集成电路创新创业大赛国奖项目
// 工程分区：图像增强工程（enhancement）
// 文件名称：guided_to_hdmi.v
// 主要模块：guided_to_hdmi
// 功能分类：引导滤波/磨皮算法
// 功能说明：集成灰度引导、局部统计、系数滤波和图像重建；子模式选择通用引导滤波或磨皮处理。
// 输入概述：像素数据及 HS/VS/DE 视频同步信号；控制参数由模式或模块参数给出。
// 输出概述：处理后的像素流，以及与流水线延迟严格匹配的 HS/VS/DE 信号。
// 时序约束：像素数据在视频像素时钟上升沿处理；复位极性以模块端口定义为准。
// 关联文件：guided_line_buffer.v、guided_var_a_b.v、box_filter_ab.v、guided_final_rebuild.v
// 维护要求：修改端口、位宽、流水线延迟或模式编码时，必须同步更新上层例化与项目文档。
// =============================================================================
`timescale 1 ns/ 1 ps
module guided_to_hdmi#(
parameter H_TOTAL = 11'd1344,// 实际行宽配置     
parameter EPSILON=16'd2000 // 平滑强度控制参数，越大越平滑
)(
input wire i_clk,
input wire i_rst,
input wire i_mode,
input wire i_hs,
input wire i_vs,
input wire i_de,
input wire [23:0] i_rgb_data,

// 输出信号直接连接到 HDMI 输出端口
output wire o_hs,
output wire o_vs,
output wire o_de,
output wire [23:0] o_rgb_data
);
wire m_hs,m_vs,m_de;
wire [23:0] ycbcr_data;
wire [23:0] original_rgb_data;
wire m0_hs,m0_vs,m0_de;
wire m1_hs,m1_vs,m1_de;
wire m2_hs,m2_vs,m2_de;
wire m3_hs,m3_vs,m3_de;
wire m4_hs,m4_vs,m4_de;
wire m5_hs,m5_vs,m5_de;
wire m6_hs,m6_vs,m6_de;
wire m7_hs,m7_vs,m7_de;
wire m8_hs,m8_vs,m8_de;
RGB_to_YCbCr u_rgb2ycbcr_guided (
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_hs(i_hs),
    .i_vs(i_vs),
    .i_data_en(i_de),
    .i_rgb(i_rgb_data), 

    .o_hs(m0_hs),
    .o_vs(m0_vs),
    .o_data_en(m0_de),
    .o_ycbcr(ycbcr_data),
    .o_raw_rgb(original_rgb_data)
); 

wire [23:0] center_ycbcr ;
wire [23:0] original_rgb_data_d1;
wire [10:0] col_sum_y;
wire [18:0] col_sum_y2;

guided_line_buffer #(
   .H_TOTAL(H_TOTAL) 
)u_line_buffer (
    .i_clk(i_clk),
    .i_rst(i_rst),
    
    .i_hs(m0_hs), // 注意这里用 m0_hs，保持与数据流同步
    .i_vs(m0_vs), // 注意这里用 m0_vs，保持与数据流同步
    .i_data_en(m0_de), 
    .i_ycbcr(ycbcr_data), // 直接用 YCbCr 数据进行滤波，保持色彩信息更完整
    .i_rgb(original_rgb_data),
    //输出
    .o_col_sum_Y(col_sum_y),
    .o_col_sum_Y2(col_sum_y2),

    .o_center_ycbcr(center_ycbcr),
    .o_hs_center(m1_hs),
    .o_vs_center(m1_vs),
    .o_de_center(m1_de),
    .o_center_rgb(original_rgb_data_d1)
);
wire [11:0] mean_Y;
wire [23:0] mean_Y2;
wire [23:0] ycbcr_sync;
wire [23:0] original_rgb_data_d2;
box_filter_y u_box_filter_y (
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_col_sum_Y(col_sum_y),
    .i_col_sum_Y2(col_sum_y2),
    .i_center_ycbcr(center_ycbcr),
    .i_rgb(original_rgb_data_d1),
    .i_hs(m1_hs), // 注意这里用 m1_hs，保持与数据流同步
    .i_vs(m1_vs), // 注意这里用 m1_vs，保持与数据流同步
    .i_de(m1_de), 

    .o_mean_Y(mean_Y), 
    .o_mean_Y2(mean_Y2), 

    .o_ycbcr_sync(ycbcr_sync), 
    .o_rgb(original_rgb_data_d2),
    .o_hs_sync(m2_hs),
    .o_vs_sync(m2_vs),
    .o_de_sync(m2_de)
);
wire [23:0] box_ycbcr;
assign box_ycbcr = {mean_Y, ycbcr_sync[15:0]}; // 用均值 Y 替换原中心像素的 Y 分量，保持 CbCr 不变
wire [11:0] a_val;
wire [11:0] b_val;
wire [23:0] ycbcr_sync1;
wire [23:0] original_rgb_data_d3;
guided_var_a_b #(
    .EPSILON(EPSILON) // 平滑强度控制参数
)u_guided_var_a_b (
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_mean_Y(mean_Y),
    .i_mean_Y2(mean_Y2),
    .i_ycbcr_sync(ycbcr_sync),
    .i_rgb(original_rgb_data_d2),
    .i_hs(m2_hs), // 注意这里用 m2_hs，保持与数据流同步
    .i_vs(m2_vs), // 注意这里用 m2_vs，保持与数据
    .i_de(m2_de),
    .o_a_val(a_val), // 输出局部线性系数 a；系数 b 由下一端口输出。
    .o_b_val(b_val),
    .o_ycbcr_out(ycbcr_sync1), 
    .o_rgb(original_rgb_data_d3),
    .o_hs_out(m3_hs),
    .o_vs_out(m3_vs),
    .o_de_out(m3_de)
);
wire [14:0] col_sum_a;
wire [14:0] col_sum_b;
wire [23:0] ycbcr_sync2;
wire [23:0] original_rgb_data_d4;
guided_line_buffer_a_b #(
    .H_TOTAL(H_TOTAL)
)u_line_buffer_a_b (
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_hs(m3_hs), // 注意这里用 m3_hs，保持与数据流同步
    .i_vs(m3_vs), // 注意这里用 m3_vs，保持与数据
    .i_de(m3_de),
    .i_ycbcr_delayed(ycbcr_sync1), // 一路跟过来的原始 YCbCr 数据，保持对齐
    .i_rgb(original_rgb_data_d3),
    .i_a(a_val),
    .i_b(b_val),
    .o_col_sum_a(col_sum_a),
    .o_col_sum_b(col_sum_b),
    .o_center_ycbcr(ycbcr_sync2), // 输出与系数窗口中心对齐的 YCbCr 像素。
    .o_rgb(original_rgb_data_d4),
    .o_hs_center(m4_hs),
    .o_vs_center(m4_vs),
    .o_de_center(m4_de)
);
wire [23:0] ycbcr_sync3;
wire [11:0] mean_a;
wire [11:0] mean_b;
wire [23:0] original_rgb_data_d5;
box_filter_ab u_box_filter_ab (
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_col_sum_a(col_sum_a),
    .i_col_sum_b(col_sum_b),
    .i_center_ycbcr(ycbcr_sync2), // 输入与 a、b 系数窗口对齐的中心 YCbCr 像素。
    .i_rgb(original_rgb_data_d4),
    .i_hs(m4_hs), // 注意这里用 m4_hs，保持与数据流同步
    .i_vs(m4_vs), // 注意这里用 m4_vs，保持与数据流同步
    .i_de(m4_de), 

    .o_mean_a(mean_a), 
    .o_mean_b(mean_b), 

    .o_ycbcr_sync(ycbcr_sync3), 
    .o_rgb(original_rgb_data_d5),
    .o_hs_sync(m5_hs), // 再次对齐后的同步信号，保持与后续模块同步
    .o_vs_sync(m5_vs),
    .o_de_sync(m5_de)
);
wire [23:0] final_ycbcr;
wire [23:0] original_rgb_data_d6;
guided_final_rebuild u_guided_final_rebuild (
    .i_clk(i_clk),
    .i_rst(i_rst),  
    .i_mean_a(mean_a), // 来自 box_filter_ab 的 a 均值
    .i_mean_b(mean_b), // 来自 box_filter_ab 的 b 均值
    .i_ycbcr_sync(ycbcr_sync3), // 来自 box_filter_ab 的对齐后的 YCbCr 数据
    .i_rgb(original_rgb_data_d5),
    .i_hs(m5_hs), // 注意这里用 m5_hs，保持与数据流同步
    .i_vs(m5_vs), // 注意这里用 m5_vs，保持与数据流同步
    .i_de(m5_de), // 注意这里用 m5_de，保持与数据流同步

    .o_final_ycbcr(final_ycbcr), // 最终输出的 YCbCr 数据，供 HDMI 输出使用
    .o_rgb(original_rgb_data_d6),
    .o_hs_out(m6_hs),      // 最终输出的 HSYNC 信号
    .o_vs_out(m6_vs),      // 最终输出的 VSYNC 信号
    .o_de_out(m6_de)       // 最终输出的数据使能信号
);
wire [23:0] final_ycbcr_meiyan;

meiyan_rebuild u_guided_meiyan (
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_mean_a(mean_a), // 来自 box_filter_ab 的 a 均值
    .i_mean_b(mean_b), // 来自 box_filter_ab 的 b 均值
    .i_ycbcr_sync(ycbcr_sync3), // 来自 box_filter_ab 的对齐后的 YCbCr 数据
    .i_hs(m5_hs), // 注意这里用 m5_hs，保持与数据流同步
    .i_vs(m5_vs), // 注意这里用 m5_vs，保持与数据流同步
    .i_de(m5_de), // 注意这里用 m5_de，保持与数据流同步

    .o_final_ycbcr(final_ycbcr_meiyan), // 最终输出的 YCbCr 数据，供 HDMI 输出使用
    .o_hs_out(m7_hs),      // 最终输出的 HSYNC 信号
    .o_vs_out(m7_vs),      // 最终输出的 VSYNC 信号
    .o_de_out(m7_de)       // 最终输出的数据使能信号
);
wire [23:0] original_rgb_data_d7;
reg hs_r,vs_r,de_r;
reg [23:0] filtered_ycbcr;
reg [23:0] filtered_rgb;
wire [23:0] filtered_ycbcr_r;
wire [23:0] filtered_rgb_r;
always @(posedge i_clk) begin
    case(i_mode) 
        1'd0:begin
            hs_r <= m6_hs;
            vs_r <= m6_vs;
            de_r <= m6_de;
            filtered_ycbcr <= final_ycbcr;
            filtered_rgb <= original_rgb_data_d6;
        end
        1'd1:begin
            hs_r <= m7_hs;
            vs_r <= m7_vs;
            de_r <= m7_de;
            filtered_ycbcr <= final_ycbcr_meiyan;
            filtered_rgb <= 0;
        end
    endcase
end
assign m8_hs = hs_r;
assign m8_vs = vs_r;
assign m8_de = de_r;
assign filtered_ycbcr_r = filtered_ycbcr;
assign filtered_rgb_r = filtered_rgb;

wire [23:0] filtered_rgb_out;
YCbCr_to_RGB u_ycbcr_to_rgb (
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_hs(m8_hs),
    .i_vs(m8_vs),
    .i_data_en(m8_de),
    .i_ycbcr(filtered_ycbcr_r), // 将选定支路的 YCbCr 结果转换回 RGB888。
    .i_rgb(filtered_rgb_r),
    .o_hs(m_hs),    
    .o_vs(m_vs),
    .o_data_en(m_de),
    .o_rgb(filtered_rgb_out) ,
    .o_original_rgb(original_rgb_data_d7)
);


assign o_hs = m_hs;
assign o_vs = m_vs;
assign o_de = m_de;
assign o_rgb_data = o_de?filtered_rgb_out:24'h000000; 
/*
assign o_hs = i_hs; // 直接传递输入的同步信号，保持时序一致性
assign o_vs = i_vs;
assign o_de = i_de;
*/
//assign o_rgb_data = o_de?filtered_rgb:24'h000000; // 直接输出滤波后的中心像素数据，送往 HDMI 输出端口;
endmodule


 


