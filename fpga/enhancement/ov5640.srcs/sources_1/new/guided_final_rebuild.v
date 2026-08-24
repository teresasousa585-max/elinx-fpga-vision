// =============================================================================
// 文件名称：guided_final_rebuild.v
// 主要模块：guided_final_rebuild
// 功能说明：依据引导滤波系数重建输出图像。
// 维护说明：修改接口或时序时，请同步更新本文件注释和上层例化。
// =============================================================================

`timescale 1 ns/ 1 ps
module guided_final_rebuild(
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
    reg [11:0] in_mean_a_r;
    reg [11:0] in_mean_b_r;
    reg [23:0] in_ycbcr_r;
    reg [23:0] in_rgb_r; // RGB 旁路第 1 拍
    reg        in_hs_r, in_vs_r, in_de_r;

    always @(posedge i_clk) begin
        in_mean_a_r <= i_mean_a;
        in_mean_b_r <= i_mean_b;
        in_ycbcr_r  <= i_ycbcr_sync;
        in_rgb_r    <= i_rgb; 
        in_hs_r     <= i_hs; 
        in_vs_r     <= i_vs; 
        in_de_r     <= i_de;
    end

    wire [7:0] y_raw = in_ycbcr_r[23:16]; // 从缓存里提取 Y

    // ==========================================
    // Stage 2
    // ==========================================
    reg [19:0] mult_a_y;
    reg [12:0] mean_b_plus_8; // 增加 1 位位宽防溢出
    reg [23:0] ycbcr_d1;
    reg [23:0] rgb_d1; // RGB 旁路第 2 拍
    reg        hs_d1, vs_d1, de_d1;

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
    reg [12:0] add_q; 
    reg [23:0] ycbcr_d2;
    reg [23:0] rgb_d2; // RGB 旁路第 3 拍
    reg        hs_d2, vs_d2, de_d2;

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
    reg [7:0]  final_y;    
    reg [15:0] final_cbcr;  
    reg [23:0] rgb_d3; // RGB 旁路第 4 拍
    reg        hs_d3, vs_d3, de_d3;

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
    reg [7:0]  final_y_d1;
    reg [15:0] final_cbcr_d1;
    reg [23:0] rgb_d4; // RGB 旁路第 5 拍
    reg        hs_d4, vs_d4, de_d4;
    
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
    assign o_final_ycbcr = {final_y_d1, final_cbcr_d1};
    assign o_rgb         = rgb_d4;
    assign o_hs_out      = hs_d4;
    assign o_vs_out      = vs_d4;
    assign o_de_out      = de_d4;

endmodule