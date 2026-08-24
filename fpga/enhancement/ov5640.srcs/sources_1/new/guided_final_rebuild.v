// =============================================================================
// 项目名称：2026 年全国大学生集成电路创新创业大赛国奖项目
// 作者：Ethereal
// 工程分区：图像增强工程（enhancement）
// 文件名称：guided_final_rebuild.v
// 主要模块：guided_final_rebuild
// 功能分类：引导滤波算法
// 功能说明：使用均值系数和中心引导值重建滤波输出 q=mean(a)×I+mean(b)。
// 输入概述：像素数据及 HS/VS/DE 视频同步信号；控制参数由模式或模块参数给出。
// 输出概述：处理后的像素流，以及与流水线延迟严格匹配的 HS/VS/DE 信号。
// 时序约束：像素数据在视频像素时钟上升沿处理；复位极性以模块端口定义为准。
// 关联文件：box_filter_ab.v、guided_to_hdmi.v
// 维护要求：修改端口、位宽、流水线延迟或模式编码时，必须同步更新上层例化与项目文档。
// =============================================================================
`timescale 1 ns/ 1 ps
// -----------------------------------------------------------------------------
// 正文导读：使用均值系数和中心引导值重建滤波输出 q=mean(a)×I+mean(b)。
// 阅读顺序：先确认参数和端口，再沿内部信号、时序过程及子模块例化追踪数据流。
// 修改约束：像素数据、有效信号和 HS/VS 必须保持同拍；跨时钟数据必须使用 FIFO 或握手。
// -----------------------------------------------------------------------------
// 模块 guided_final_rebuild：以下接口构成综合边界，上层通过端口连接数据流、控制流和状态信号。
module guided_final_rebuild(
    // 接口信号：input 接收上游数据/控制，output 返回处理结果/状态，inout 连接双向器件总线。
    input  wire        i_clk,
    input  wire        i_rst, 
    
    // 来自第二级均值滤波器 (box_filter_ab) 的输出
    input  wire [11:0] i_mean_a,
    input  wire [11:0] i_mean_b,
    input  wire [23:0] i_ycbcr_sync, // {Y[23:16], Cb[15:8], Cr[7:0]}
    input  wire [23:0] i_rgb,        // 【新增】原数据旁路输入
    input  wire        i_hs,
    input  wire        i_vs,
    input  wire        i_de,
    
    // 最终输出给 HDMI 的图像
    output wire [23:0] o_final_ycbcr,
    output wire [23:0] o_rgb,        // 【新增】原数据旁路输出
    output wire        o_hs_out,
    output wire        o_vs_out,
    output wire        o_de_out
);

    // ==========================================
    // Stage 1
    // ==========================================
    // 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
    reg [11:0] in_mean_a_r;
    reg [11:0] in_mean_b_r;
    reg [23:0] in_ycbcr_r;
    reg [23:0] in_rgb_r; // RGB 旁路第 1 拍
    reg        in_hs_r, in_vs_r, in_de_r;

    // 时序过程 1：由 i_clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
    always @(posedge i_clk) begin
        in_mean_a_r <= i_mean_a;
        in_mean_b_r <= i_mean_b;
        in_ycbcr_r  <= i_ycbcr_sync;
        in_rgb_r    <= i_rgb; 
        in_hs_r     <= i_hs; 
        in_vs_r     <= i_vs; 
        in_de_r     <= i_de;
    end

    // 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
    wire [7:0] y_raw = in_ycbcr_r[23:16]; // 从缓存里提取 Y

    // ==========================================
    // Stage 2
    // ==========================================
    reg [19:0] mult_a_y;
    reg [12:0] mean_b_plus_8; // 增加 1 位位宽防溢出
    reg [23:0] ycbcr_d1;
    reg [23:0] rgb_d1; // RGB 旁路第 2 拍
    reg        hs_d1, vs_d1, de_d1;

    // 时序过程 2：由 i_clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
    always @(posedge i_clk) begin
        mult_a_y      <= in_mean_a_r * y_raw; 
        mean_b_plus_8 <= in_mean_b_r + 13'd8; 
        ycbcr_d1      <= in_ycbcr_r;
        rgb_d1        <= in_rgb_r;
        hs_d1         <= in_hs_r;
        vs_d1         <= in_vs_r;
        de_d1         <= in_de_r;
    end

    // ==========================================
    // Stage 3
    // ==========================================
    // 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
    reg [12:0] add_q; 
    reg [23:0] ycbcr_d2;
    reg [23:0] rgb_d2; // RGB 旁路第 3 拍
    reg        hs_d2, vs_d2, de_d2;

    // 时序过程 3：由 i_clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
    always @(posedge i_clk) begin
        // 引导滤波的累加
        add_q    <= mult_a_y[19:8] + mean_b_plus_8;
       
        ycbcr_d2 <= ycbcr_d1;
        rgb_d2   <= rgb_d1;
        hs_d2    <= hs_d1; 
        vs_d2    <= vs_d1; 
        de_d2    <= de_d1;
    end

    // ==========================================
    // Stage 4
    // ==========================================
    // 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
    reg [7:0]  final_y;    
    reg [15:0] final_cbcr;  
    reg [23:0] rgb_d3; // RGB 旁路第 4 拍
    reg        hs_d3, vs_d3, de_d3;

    // 时序过程 4：由 i_clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
    always @(posedge i_clk) begin
        // 规范了 if-else 结构，更加安全
        if(add_q[12:4] > 9'd255) begin
            final_y <= 8'd255;
        end else begin
            final_y <= add_q[11:4];
        end
        
        final_cbcr <= ycbcr_d2[15:0]; // 色彩不变
        
        rgb_d3     <= rgb_d2;
        hs_d3      <= hs_d2; 
        vs_d3      <= vs_d2; 
        de_d3      <= de_d2;
    end

    // ==========================================
    // Stage 5: 输出信号打一拍
    // ==========================================
    // 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
    reg [7:0]  final_y_d1;
    reg [15:0] final_cbcr_d1;
    reg [23:0] rgb_d4; // RGB 旁路第 5 拍
    reg        hs_d4, vs_d4, de_d4;
    
    // 时序过程 5：由 i_clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
    always @(posedge i_clk) begin
        final_y_d1    <= final_y;
        final_cbcr_d1 <= final_cbcr;
        rgb_d4        <= rgb_d3;
        hs_d4         <= hs_d3; 
        vs_d4         <= vs_d3; 
        de_d4         <= de_d3;
    end

    // ==========================================
    // 最终输出赋值
    // ==========================================
    // 组合连线组 1：从 o_final_ycbcr 开始的连续赋值随右值立即更新，不增加寄存器延迟。
    assign o_final_ycbcr = {final_y_d1, final_cbcr_d1};
    assign o_rgb         = rgb_d4;
    assign o_hs_out      = hs_d4;
    assign o_vs_out      = vs_d4;
    assign o_de_out      = de_d4;

endmodule