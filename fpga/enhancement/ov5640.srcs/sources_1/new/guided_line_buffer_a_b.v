// =============================================================================
// 项目名称：2026 年全国大学生集成电路创新创业大赛国奖项目
// 工程分区：图像增强工程（enhancement）
// 文件名称：guided_line_buffer_a_b.v
// 主要模块：guided_line_buffer_a_b
// 功能分类：引导滤波算法
// 功能说明：缓存系数 a、b 并构造其局部窗口，为系数均值计算提供数据。
// 输入概述：像素数据及 HS/VS/DE 视频同步信号；控制参数由模式或模块参数给出。
// 输出概述：处理后的像素流，以及与流水线延迟严格匹配的 HS/VS/DE 信号。
// 时序约束：像素数据在视频像素时钟上升沿处理；复位极性以模块端口定义为准。
// 关联文件：box_filter_ab.v、guided_final_rebuild.v
// 维护要求：修改端口、位宽、流水线延迟或模式编码时，必须同步更新上层例化与项目文档。
// =============================================================================
`timescale 1 ns/ 1 ps
module guided_line_buffer_a_b#(
    parameter H_TOTAL = 11'd1344
)(
    input  wire        i_clk,
    input  wire        i_rst,

    // ---------------- 输入 ----------------
    input  wire        i_hs,
    input  wire        i_vs,
    input  wire        i_de,
    input  wire [23:0] i_ycbcr_delayed, // 带着 CbCr 一起进来的完整像素
    input  wire [23:0] i_rgb,           // 原数据旁路
    input  wire [11:0] i_a,             // 算好的系数 a
    input  wire [11:0] i_b,             // 算好的系数 b

    // ---------------- 输出 ----------------
    // 当前列的 a 和 b 的垂直求和
    output wire [14:0] o_col_sum_a,  
    output wire [14:0] o_col_sum_b,  

    // 绝对中心对齐的完整 YCbCr、RGB 与同步信号
    output wire [23:0] o_center_ycbcr,
    output wire [23:0] o_rgb,           
    output wire        o_hs_center,
    output wire        o_vs_center,
    output wire        o_de_center
);
    // 1. 数据打包打拍
    reg        hs_d1, vs_d1, de_d1;
    reg [23:0] ycbcr_d1;
    reg [23:0] rgb_d1;
    reg [11:0] a_d1, b_d1;

    always @(posedge i_clk) begin
        hs_d1 <= i_hs; vs_d1 <= i_vs; de_d1 <= i_de;
        ycbcr_d1 <= i_ycbcr_delayed;
        rgb_d1   <= i_rgb;
        a_d1 <= i_a; b_d1 <= i_b;
    end

    // 【修改】打包内容：{33'b0, HS(1), VS(1), DE(1), YCbCr(24), RGB(24), a(12), b(12)} = 108 bit
    wire [107:0] pack_in = {33'd0, hs_d1, vs_d1, de_d1, ycbcr_d1, rgb_d1, a_d1, b_d1};

    // 全局列计数器
    reg [10:0] s_cnt;
    always @(posedge i_clk) begin
        if (i_rst) s_cnt <= 0;
        else s_cnt <= (s_cnt == H_TOTAL - 1) ? 0 : s_cnt + 1;
    end

    // 行索引：0-4，循环5行
    reg [2:0] row_idx;
    always @(posedge i_clk) begin
        if (i_rst) row_idx <= 0;
        else if (s_cnt == H_TOTAL - 1) row_idx <= (row_idx == 4) ? 0 : row_idx + 1;
    end

    reg [10:0] s_cnt_r[0:4];
    integer i;
    always @(posedge i_clk) begin
        for (i=0; i<5; i=i+1) s_cnt_r[i] <= s_cnt;
    end

    // 2. 例化 5 根 Line Buffer (请调用刚刚生成的 m4k_sync_108b)
    wire [107:0] q[0:4];
    wire wren[0:4];
    assign wren[0] = (row_idx == 0);
    assign wren[1] = (row_idx == 1);
    assign wren[2] = (row_idx == 2);
    assign wren[3] = (row_idx == 3);
    assign wren[4] = (row_idx == 4);

    m4k_sync_108b u_lb0 (.clock(i_clk), .data(pack_in), .rdaddress(s_cnt_r[0]), .wraddress(s_cnt_r[0]), .wren(wren[0]), .q(q[0]));
    m4k_sync_108b u_lb1 (.clock(i_clk), .data(pack_in), .rdaddress(s_cnt_r[1]), .wraddress(s_cnt_r[1]), .wren(wren[1]), .q(q[1]));
    m4k_sync_108b u_lb2 (.clock(i_clk), .data(pack_in), .rdaddress(s_cnt_r[2]), .wraddress(s_cnt_r[2]), .wren(wren[2]), .q(q[2]));
    m4k_sync_108b u_lb3 (.clock(i_clk), .data(pack_in), .rdaddress(s_cnt_r[3]), .wraddress(s_cnt_r[3]), .wren(wren[3]), .q(q[3]));
    m4k_sync_108b u_lb4 (.clock(i_clk), .data(pack_in), .rdaddress(s_cnt_r[4]), .wraddress(s_cnt_r[4]), .wren(wren[4]), .q(q[4]));

    // 3. 提取 5 行的 a 和 b 数据 (索引完全不变！)
    // a 在 [23:12], b 在 [11:0]
    wire [11:0] r1_a = q[(row_idx + 1) % 5][23:12]; wire [11:0] r1_b = q[(row_idx + 1) % 5][11:0];
    wire [11:0] r2_a = q[(row_idx + 2) % 5][23:12]; wire [11:0] r2_b = q[(row_idx + 2) % 5][11:0];
    wire [11:0] r3_a = q[(row_idx + 3) % 5][23:12]; wire [11:0] r3_b = q[(row_idx + 3) % 5][11:0];
    wire [11:0] r4_a = q[(row_idx + 4) % 5][23:12]; wire [11:0] r4_b = q[(row_idx + 4) % 5][11:0];
    wire [11:0] r5_a = q[row_idx][23:12];           wire [11:0] r5_b = q[row_idx][11:0];

    // 4. 列垂直求和 
    reg [13:0] sum_a_l1_1, sum_a_l1_2; reg [11:0] sum_a_l1_3;
    reg [13:0] sum_b_l1_1, sum_b_l1_2; reg [11:0] sum_b_l1_3;

    reg [14:0] final_col_sum_a;
    reg [14:0] final_col_sum_b;

    always @(posedge i_clk) begin
        sum_a_l1_1 <= r1_a + r2_a; sum_a_l1_2 <= r3_a + r4_a; sum_a_l1_3 <= r5_a;
        sum_b_l1_1 <= r1_b + r2_b; sum_b_l1_2 <= r3_b + r4_b; sum_b_l1_3 <= r5_b;

        final_col_sum_a <= sum_a_l1_1 + sum_a_l1_2 + sum_a_l1_3;
        final_col_sum_b <= sum_b_l1_1 + sum_b_l1_2 + sum_b_l1_3;
    end
    
    // 5. 中心像素完整 YCbCr、RGB 与同步信号双重提取 (Row 3)
    reg [23:0] center_ycbcr_d1, center_ycbcr_d2;
    reg [23:0] center_rgb_d1, center_rgb_d2;
    reg        center_hs_d1, center_hs_d2;
    reg        center_vs_d1, center_vs_d2;
    reg        center_de_d1, center_de_d2;

    always @(posedge i_clk) begin
        // 解包 q3: 提取索引同样一字不差！
        center_rgb_d1   <= q[(row_idx + 3) % 5][47:24];
        center_ycbcr_d1 <= q[(row_idx + 3) % 5][71:48];
        
        center_de_d1    <= q[(row_idx + 3) % 5][72];
        center_vs_d1    <= q[(row_idx + 3) % 5][73];
        center_hs_d1    <= q[(row_idx + 3) % 5][74];

        center_rgb_d2   <= center_rgb_d1;
        center_ycbcr_d2 <= center_ycbcr_d1;
        
        center_hs_d2    <= center_hs_d1;
        center_vs_d2    <= center_vs_d1;
        center_de_d2    <= center_de_d1;
    end
    
    // 输出赋值
    assign o_col_sum_a = final_col_sum_a;
    assign o_col_sum_b = final_col_sum_b;

    assign o_center_ycbcr = center_ycbcr_d2;
    assign o_rgb          = center_rgb_d2;
    assign o_hs_center    = center_hs_d2;
    assign o_vs_center    = center_vs_d2;
    assign o_de_center    = center_de_d2;
endmodule