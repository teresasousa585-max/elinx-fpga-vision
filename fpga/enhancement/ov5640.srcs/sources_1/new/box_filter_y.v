// =============================================================================
// 项目名称：2026 年全国大学生集成电路创新创业大赛国奖项目
// 工程分区：图像增强工程（enhancement）
// 文件名称：box_filter_y.v
// 主要模块：box_filter_y
// 功能分类：引导滤波算法
// 功能说明：对引导图窗口执行盒式滤波，得到局部亮度均值及相关统计量。
// 输入概述：像素数据及 HS/VS/DE 视频同步信号；控制参数由模式或模块参数给出。
// 输出概述：处理后的像素流，以及与流水线延迟严格匹配的 HS/VS/DE 信号。
// 时序约束：像素数据在视频像素时钟上升沿处理；复位极性以模块端口定义为准。
// 关联文件：guided_line_buffer.v、guided_var_a_b.v
// 维护要求：修改端口、位宽、流水线延迟或模式编码时，必须同步更新上层例化与项目文档。
// =============================================================================
`timescale 1 ns/ 1 ps
module box_filter_y(
    input  wire        i_clk,
    input  wire        i_rst,
    
    // 来自上一个模块 (Line Buffer) 的列求和数据与中心信号
    input  wire [10:0] i_col_sum_Y,   
    input  wire [18:0] i_col_sum_Y2,  
    input  wire [23:0] i_center_ycbcr,
    input  wire [23:0] i_rgb,         // 原数据旁路输入
    input  wire        i_hs,
    input  wire        i_vs,
    input  wire        i_de,
    
    // 输出：最终的 5x5 窗口均值
    output wire [11:0]  o_mean_Y,      // I 的均值 (12-bit: 8整数+4小数)
    output wire [23:0]  o_mean_Y2,     // I^2 的均值 (24-bit: 16整数+8小数)
    
    // 输出：再次对齐延迟后的中心像素 
    output wire [23:0] o_ycbcr_sync,
    output wire [23:0] o_rgb,         // 原数据旁路输出
    output wire        o_hs_sync,
    output wire        o_vs_sync,
    output wire        o_de_sync
    );

    // 1. 缓存最近 5 列的和 
    reg [10:0] col_y_d0, col_y_d1, col_y_d2, col_y_d3, col_y_d4;
    reg [18:0] col_y2_d0, col_y2_d1, col_y2_d2, col_y2_d3, col_y2_d4;

    always @(posedge i_clk) begin
        if (i_rst) begin
            {col_y_d0, col_y_d1, col_y_d2, col_y_d3, col_y_d4} <= 0;
            {col_y2_d0, col_y2_d1, col_y2_d2, col_y2_d3, col_y2_d4} <= 0;
        end else begin
            // Y 均值移位流水线
            col_y_d0 <= i_col_sum_Y;
            col_y_d1 <= col_y_d0;
            col_y_d2 <= col_y_d1;
            col_y_d3 <= col_y_d2;
            col_y_d4 <= col_y_d3;
            
            // Y^2 均值移位流水线
            col_y2_d0 <= i_col_sum_Y2;
            col_y2_d1 <= col_y2_d0;
            col_y2_d2 <= col_y2_d1;
            col_y2_d3 <= col_y2_d2;
            col_y2_d4 <= col_y2_d3;
        end
    end
    
    // 2. 计算 5 个列和的总和
    // Stage 1
    reg [11:0] sum_y_s1_01, sum_y_s1_23; reg [10:0] sum_y_s1_4;
    reg [19:0] sum_y2_s1_01, sum_y2_s1_23; reg [18:0] sum_y2_s1_4;
    
    always @(posedge i_clk) begin
        sum_y_s1_01 <= col_y_d0 + col_y_d1;
        sum_y_s1_23 <= col_y_d2 + col_y_d3;
        sum_y_s1_4  <= col_y_d4;
        
        sum_y2_s1_01 <= col_y2_d0 + col_y2_d1;
        sum_y2_s1_23 <= col_y2_d2 + col_y2_d3;
        sum_y2_s1_4  <= col_y2_d4;
    end

    // Stage 2
    reg [12:0] sum_y_s2_0123; reg [10:0] sum_y_s2_4;
    reg [20:0] sum_y2_s2_0123; reg [18:0] sum_y2_s2_4;
    
    always @(posedge i_clk) begin
        sum_y_s2_0123 <= sum_y_s1_01 + sum_y_s1_23;
        sum_y_s2_4    <= sum_y_s1_4;
        
        sum_y2_s2_0123 <= sum_y2_s1_01 + sum_y2_s1_23;
        sum_y2_s2_4    <= sum_y2_s1_4;
    end

    // Stage 3 
    // 25个像素亮度总和最大: 25 * 255 = 6375 (13-bit)
    reg [13:0] window_sum_Y; 
    // 25个平方总和最大: 25 * 65025 = 1625625 (21-bit)
    reg [21:0] window_sum_Y2; 
    
    always @(posedge i_clk) begin
        window_sum_Y  <= sum_y_s2_0123 + sum_y_s2_4;
        window_sum_Y2 <= sum_y2_s2_0123 + sum_y2_s2_4;
    end

    // 乘以 2621，然后右移 16 位，约等于除以 25
    wire [26:0] mult_Y;
    wire [34:0] mult_Y2;
    
    lpmmult_14_13 u_mult_Y (
        .clock  (i_clk),            
        .dataa  (window_sum_Y),     
        .datab  (13'd2621),         
        .result (mult_Y)            
    );
    
    lpmmult_22_13 u_mult_Y2 (
        .clock  (i_clk),            
        .dataa  (window_sum_Y2),    
        .datab  (13'd2621),         
        .result (mult_Y2)           
    );
    
    // 取高位
    assign o_mean_Y  = mult_Y[23:12];
    assign o_mean_Y2 = mult_Y2[31:8];
    
    // ==========================================
    // 4. 中心点对齐保护 (拓宽为 51 位，加入 RGB)
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
            sync_d7 <= sync_d6; 
        end
    end
    
    // 按照拼装顺序解包输出
    assign o_hs_sync    = sync_d7[50];
    assign o_vs_sync    = sync_d7[49];
    assign o_de_sync    = sync_d7[48];
    assign o_ycbcr_sync = sync_d7[47:24];
    assign o_rgb        = sync_d7[23:0];

endmodule