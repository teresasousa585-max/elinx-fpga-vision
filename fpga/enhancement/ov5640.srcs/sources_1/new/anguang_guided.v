// =============================================================================
// 项目名称：2026 年全国大学生集成电路创新创业大赛国奖项目
// 作者：Ethereal
// 工程分区：图像增强工程（enhancement）
// 文件名称：anguang_guided.v
// 主要模块：anguang_guided
// 功能分类：暗光增强算法
// 功能说明：通过引导滤波估计平滑照度分量，为暗光增益计算提供基础数据。
// 输入概述：像素数据及 HS/VS/DE 视频同步信号；控制参数由模式或模块参数给出。
// 输出概述：处理后的像素流，以及与流水线延迟严格匹配的 HS/VS/DE 信号。
// 时序约束：像素数据在视频像素时钟上升沿处理；复位极性以模块端口定义为准。
// 关联文件：guided_*、box_filter_*.v、anguang_enhance_apply.v
// 维护要求：修改端口、位宽、流水线延迟或模式编码时，必须同步更新上层例化与项目文档。
// =============================================================================
`timescale 1 ns/ 1 ps
// -----------------------------------------------------------------------------
// [Ethereal注释] 正文导读：通过引导滤波估计平滑照度分量，为暗光增益计算提供基础数据。
// [Ethereal注释] 阅读顺序：先确认参数和端口，再沿内部信号、时序过程及子模块例化追踪数据流。
// [Ethereal注释] 修改约束：像素数据、有效信号和 HS/VS 必须保持同拍；跨时钟数据必须使用 FIFO 或握手。
// -----------------------------------------------------------------------------
// [Ethereal注释] 模块 anguang_guided：以下接口构成综合边界，上层通过端口连接数据流、控制流和状态信号。
module anguang_guided#(
// [Ethereal注释] 参数配置：综合期确定位宽、容量、频率或算法强度，修改后需重新验证资源和时序。
parameter H_TOTAL = 11'd1344, // 每行总时钟数（含消隐区）
parameter EPSILON=16'd2000 // 平滑强度控制参数，越大越平滑
)(
    // [Ethereal注释] 接口信号：input 接收上游数据/控制，output 返回处理结果/状态，inout 连接双向器件总线。
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
// [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
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

// [Ethereal注释] 子模块例化 1（guided_line_buffer）：构造引导图的局部窗口，输出均值与方差计算所需的邻域数据。
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
    //输出
    .o_col_sum_Y(col_sum_y),
    .o_col_sum_Y2(col_sum_y2),

    .o_center_ycbcr(center_ycbcr),
    .o_hs_center(m1_hs),
    .o_vs_center(m1_vs),
    .o_de_center(m1_de),
    .o_center_rgb(center_rgb)
);

// [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
wire [23:0] center_rgb_d1;
// [Ethereal注释] 子模块例化 2（box_filter_y）：对引导图窗口执行盒式滤波，得到局部亮度均值及相关统计量。
box_filter_y u_box_filter_y_anguang (
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_col_sum_Y(col_sum_y),
    .i_col_sum_Y2(col_sum_y2),
    .i_center_ycbcr(center_ycbcr),
    .i_rgb(center_rgb),
    .i_hs(m1_hs), // 注意这里用 m1_hs，保持与数据流同步
    .i_vs(m1_vs), // 注意这里用 m1_vs，保持与数据流同步
    .i_de(m1_de), 

    .o_mean_Y(mean_Y), 
    .o_mean_Y2(mean_Y2), 

    .o_ycbcr_sync(ycbcr_sync), 
    .o_rgb(center_rgb_d1),
    .o_hs_sync(m2_hs),
    .o_vs_sync(m2_vs),
    .o_de_sync(m2_de)
);

// [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
wire [11:0] a_val;
wire [11:0] b_val;
wire [23:0] ycbcr_sync1;
wire [23:0] center_rgb_d2;
// [Ethereal注释] 子模块例化 3（guided_var_a_b）：根据局部统计量计算引导滤波线性系数 a、b。
guided_var_a_b #(
    .EPSILON(EPSILON) // 平滑强度控制参数
)u_guided_var_a_b_anguang (
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_mean_Y(mean_Y),
    .i_mean_Y2(mean_Y2),
    .i_ycbcr_sync(ycbcr_sync),
    .i_rgb(center_rgb_d1),
    .i_hs(m2_hs), // 注意这里用 m2_hs，保持与数据流同步
    .i_vs(m2_vs), // 注意这里用 m2_vs，保持与数据
    .i_de(m2_de),
    .o_a_val(a_val), // 输出局部线性系数 a；系数 b 由下一端口输出。
    .o_b_val(b_val),
    .o_ycbcr_out(ycbcr_sync1), 
    .o_rgb(center_rgb_d2),
    .o_hs_out(m3_hs),
    .o_vs_out(m3_vs),
    .o_de_out(m3_de)
);

// [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
wire [14:0] col_sum_a;
wire [14:0] col_sum_b;
wire [23:0] ycbcr_sync2;
wire [23:0] center_rgb_d3;
// [Ethereal注释] 子模块例化 4（guided_line_buffer_a_b）：缓存系数 a、b 并构造其局部窗口，为系数均值计算提供数据。
guided_line_buffer_a_b #(
    .H_TOTAL(H_TOTAL)
)u_line_buffer_a_b (
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_hs(m3_hs), // 注意这里用 m3_hs，保持与数据流同步
    .i_vs(m3_vs), // 注意这里用 m3_vs，保持与数据
    .i_de(m3_de),
    .i_ycbcr_delayed(ycbcr_sync1), // 一路跟过来的原始 YCbCr 数据，保持对齐
    .i_rgb(center_rgb_d2),
    .i_a(a_val),
    .i_b(b_val),
    .o_col_sum_a(col_sum_a),
    .o_col_sum_b(col_sum_b),
    .o_center_ycbcr(ycbcr_sync2), // 输出与系数窗口中心对齐的 YCbCr 像素。
    .o_rgb(center_rgb_d3),
    .o_hs_center(m4_hs),
    .o_vs_center(m4_vs),
    .o_de_center(m4_de)
);
// [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
wire [23:0] ycbcr_sync3;
wire [11:0] mean_a;
wire [11:0] mean_b;
wire [23:0] center_rgb_d4;
// [Ethereal注释] 子模块例化 5（box_filter_ab）：对线性系数 a、b 执行盒式均值滤波，并对齐中心像素旁路。
box_filter_ab u_box_filter_ab (
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_col_sum_a(col_sum_a),
    .i_col_sum_b(col_sum_b),
    .i_center_ycbcr(ycbcr_sync2), // 输入与 a、b 系数窗口对齐的中心 YCbCr 像素。
    .i_rgb(center_rgb_d3),
    .i_hs(m4_hs), // 注意这里用 m4_hs，保持与数据流同步
    .i_vs(m4_vs), // 注意这里用 m4_vs，保持与数据流同步
    .i_de(m4_de), 

    .o_mean_a(mean_a), 
    .o_mean_b(mean_b), 

    .o_ycbcr_sync(ycbcr_sync3), 
    .o_rgb(center_rgb_d4),
    .o_hs_sync(m5_hs), // 再次对齐后的同步信号，保持与后续模块同步
    .o_vs_sync(m5_vs),
    .o_de_sync(m5_de)
);
// [Ethereal注释] 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
wire [23:0] final_ycbcr;
wire [23:0] center_rgb_d5;
// [Ethereal注释] 子模块例化 6（guided_final_rebuild）：使用均值系数和中心引导值重建滤波输出 q=mean(a)×I+mean(b)。
guided_final_rebuild u_guided_final_rebuild (
    .i_clk(i_clk),
    .i_rst(i_rst),  
    .i_mean_a(mean_a), // 来自 box_filter_ab 的 a 均值
    .i_mean_b(mean_b), // 来自 box_filter_ab 的 b 均值
    .i_ycbcr_sync(ycbcr_sync3), // 来自 box_filter_ab 的对齐后的 YCbCr 数据
    .i_rgb(center_rgb_d4),
    .i_hs(m5_hs), // 注意这里用 m5_hs，保持与数据流同步
    .i_vs(m5_vs), // 注意这里用 m5_vs，保持与数据流同步
    .i_de(m5_de), // 注意这里用 m5_de，保持与数据流同步

    .o_final_ycbcr(final_ycbcr), // 最终输出的 YCbCr 数据，供 HDMI 输出使用
    .o_rgb(center_rgb_d5),
    .o_hs_out(m6_hs),      // 最终输出的 HSYNC 信号
    .o_vs_out(m6_vs),      // 最终输出的 VSYNC 信号
    .o_de_out(m6_de)       // 最终输出的数据使能信号
);
// [Ethereal注释] 组合连线组 1：从 o_hs_out 开始的连续赋值随右值立即更新，不增加寄存器延迟。
assign o_hs_out = m6_hs;
assign o_vs_out = m6_vs;
assign o_de_out = m6_de;
assign o_y = final_ycbcr[23:16];
assign o_rgb = center_rgb_d5;
endmodule


 

