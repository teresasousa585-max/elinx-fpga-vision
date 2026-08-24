// =============================================================================
// 文件名称：box_filter_ab.v
// 主要模块：box_filter_ab
// 功能说明：对引导滤波线性系数执行窗口均值计算。
// 维护说明：修改接口或时序时，请同步更新本文件注释和上层例化。
// =============================================================================

`timescale 1 ns/ 1 ps
module box_filter_ab(
    input  wire        i_clk,
    input  wire        i_rst,
    
    // 来自上一个模块的列求和数据与中心信号
    input  wire [14:0] i_col_sum_a,   
    input  wire [14:0] i_col_sum_b,  
    input  wire [23:0] i_center_ycbcr, 
    input  wire [23:0] i_rgb,         // 【新增】原数据旁路输入
    input  wire        i_hs,
    input  wire        i_vs,
    input  wire        i_de,
    
    // 输出：最终的 5x5 窗口均值
    output wire [11:0]  o_mean_a,      
    output wire [11:0]  o_mean_b,      
    
    // 输出：再次对齐延迟后的中心像素
    output wire [23:0] o_ycbcr_sync,
    output wire [23:0] o_rgb,         // 【新增】原数据旁路输出
    output wire        o_hs_sync,
    output wire        o_vs_sync,
    output wire        o_de_sync
    );

    // 1. 缓存最近 5 列的和 
    reg [14:0] col_a_d0, col_a_d1, col_a_d2, col_a_d3, col_a_d4;
    reg [14:0] col_b_d0, col_b_d1, col_b_d2, col_b_d3, col_b_d4;

    always @(posedge i_clk) begin
        if (i_rst) begin
            {col_a_d0, col_a_d1, col_a_d2, col_a_d3, col_a_d4} <= 0;
            {col_b_d0, col_b_d1, col_b_d2, col_b_d3, col_b_d4} <= 0;
        end else begin
            // 移位流水线 A
            col_a_d0 <= i_col_sum_a;
            col_a_d1 <= col_a_d0;
            col_a_d2 <= col_a_d1;
            col_a_d3 <= col_a_d2;
            col_a_d4 <= col_a_d3;
            
            // 移位流水线 B
            col_b_d0 <= i_col_sum_b;
            col_b_d1 <= col_b_d0;
            col_b_d2 <= col_b_d1;
            col_b_d3 <= col_b_d2;
            col_b_d4 <= col_b_d3;
        end
    end
    
    // 2. 计算 5 个列和的总和
    // Stage 1
    reg [15:0] sum_a_s1_01, sum_a_s1_23; reg [14:0] sum_a_s1_4;
    reg [15:0] sum_b_s1_01, sum_b_s1_23; reg [14:0] sum_b_s1_4;
    
    always @(posedge i_clk) begin
        sum_a_s1_01 <= col_a_d0 + col_a_d1;
        sum_a_s1_23 <= col_a_d2 + col_a_d3;
        sum_a_s1_4  <= col_a_d4;
        
        sum_b_s1_01 <= col_b_d0 + col_b_d1;
        sum_b_s1_23 <= col_b_d2 + col_b_d3;
        sum_b_s1_4  <= col_b_d4;
    end

    // Stage 2
    reg [16:0] sum_a_s2_0123; reg [14:0] sum_a_s2_4;
    reg [16:0] sum_b_s2_0123; reg [14:0] sum_b_s2_4;
    
    always @(posedge i_clk) begin
        sum_a_s2_0123 <= sum_a_s1_01 + sum_a_s1_23;
        sum_a_s2_4    <= sum_a_s1_4;
        
        sum_b_s2_0123 <= sum_b_s1_01 + sum_b_s1_23;
        sum_b_s2_4    <= sum_b_s1_4;
    end

    // Stage 3 
    reg [17:0] window_sum_a; 
    reg [17:0] window_sum_b; 
    
    always @(posedge i_clk) begin
        window_sum_a <= sum_a_s2_0123 + sum_a_s2_4;
        window_sum_b <= sum_b_s2_0123 + sum_b_s2_4;
    end

    // 3. 计算均值 
    wire [30:0] mult_a;
    wire [30:0] mult_b;

    lpmmult_18_13 u_mult_a (
        .clock  (i_clk),             
        .dataa  (window_sum_a),      
        .datab  (13'd2621),          
        .result (mult_a)             
    );

    lpmmult_18_13 u_mult_b (
        .clock  (i_clk),             
        .dataa  (window_sum_b),      
        .datab  (13'd2621),          
        .result (mult_b)             
    );

    // 取高位作为定点数还原
    assign o_mean_a = mult_a[27:16];
    assign o_mean_b = mult_b[27:16];

    // ==========================================
    // 4. 延迟信号 (拓宽为 51 位，加入 RGB)
    // ==========================================
    reg [50:0] sync_d1, sync_d2, sync_d3, sync_d4, sync_d5, sync_d6, sync_d7;
    
    // 拼装顺序：HS(1) + VS(1) + DE(1) + YCbCr(24) + RGB(24) = 51位
    wire [50:0] sync_in = {i_hs, i_vs, i_de, i_center_ycbcr, i_rgb};

    always @(posedge i_clk) begin
        if (i_rst) begin
            {sync_d1, sync_d2, sync_d3, sync_d4, sync_d5, sync_d6, sync_d7} <= 0;
        end else begin
            sync_d1 <= sync_in;
            sync_d2 <= sync_d1;
            sync_d3 <= sync_d2;
            sync_d4 <= sync_d3;
            sync_d5 <= sync_d4;
            sync_d6 <= sync_d5;
            sync_d7 <= sync_d6; // 第 7 拍出站
        end
    end

    // 按照拼装顺序解包输出
    assign o_hs_sync    = sync_d7[50];
    assign o_vs_sync    = sync_d7[49];
    assign o_de_sync    = sync_d7[48];
    assign o_ycbcr_sync = sync_d7[47:24];
    assign o_rgb        = sync_d7[23:0];

endmodule