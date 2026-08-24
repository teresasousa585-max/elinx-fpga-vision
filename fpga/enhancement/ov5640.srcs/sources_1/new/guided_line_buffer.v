// =============================================================================
// 项目名称：2026 年全国大学生集成电路创新创业大赛国奖项目
// 工程分区：图像增强工程（enhancement）
// 文件名称：guided_line_buffer.v
// 主要模块：guided_line_buffer
// 功能分类：引导滤波算法
// 功能说明：构造引导图的局部窗口，输出均值与方差计算所需的邻域数据。
// 输入概述：像素数据及 HS/VS/DE 视频同步信号；控制参数由模式或模块参数给出。
// 输出概述：处理后的像素流，以及与流水线延迟严格匹配的 HS/VS/DE 信号。
// 时序约束：像素数据在视频像素时钟上升沿处理；复位极性以模块端口定义为准。
// 关联文件：guided_var_a_b.v、box_filter_y.v
// 维护要求：修改端口、位宽、流水线延迟或模式编码时，必须同步更新上层例化与项目文档。
// =============================================================================
`timescale 1 ns/ 1 ps
module guided_line_buffer #(
    parameter H_TOTAL = 11'd1344
)(
    input  wire        i_clk,
    input  wire        i_rst,
    
    // 输入视频流及同步信号
    input  wire        i_hs,
    input  wire        i_vs,
    input  wire        i_data_en,
    input  wire [23:0] i_ycbcr, // 供美颜和计算用的 YCbCr
    input  wire [23:0] i_rgb,   // 供暗光处理用的原始 RGB
    
    // 输出：当前列的 Y 与 Y^2 的垂直求和
    output wire [10:0] o_col_sum_Y,   
    output wire [18:0] o_col_sum_Y2,  
    
    // 输出：绝对中心对齐的全套原图与同步信号
    output wire [23:0] o_center_ycbcr, // 美颜专用
    output wire [23:0] o_center_rgb,   // 暗光专用
    output wire        o_hs_center,
    output wire        o_vs_center,
    output wire        o_de_center
);
    // 1. 拆解 Y 分量并计算平方 (从 YCbCr 中提取 Y)
    wire [7:0] y_in = i_ycbcr[23:16];
    reg [15:0] y_sq_in;

    always @(posedge i_clk) begin
        y_sq_in <= y_in * y_in;
    end

    reg        hs_d1, vs_d1, de_d1;
    reg [23:0] ycbcr_d1;
    reg [23:0] rgb_d1;
    always @(posedge i_clk) begin
        hs_d1 <= i_hs; vs_d1 <= i_vs; de_d1 <= i_data_en;
        ycbcr_d1 <= i_ycbcr;
        rgb_d1   <= i_rgb;
    end
    
    // 2. 打包送入 72-bit Line Buffer
    // [15:0]  = Y^2   (16位)
    // [39:16] = RGB   (24位)
    // [63:40] = YCbCr (24位) -> 其中 Y 在 [63:56]
    // [64]    = DE    (1位)
    // [65]    = VS    (1位)
    // [66]    = HS    (1位)
    // [71:67] = 填零  (5位) 
    wire [71:0] pack_in = {5'd0, hs_d1, vs_d1, de_d1, ycbcr_d1, rgb_d1, y_sq_in};
    
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

    // 3. 例化 5 根 Line Buffer 
    wire [71:0] q[0:4];
    wire wren[0:4];
    assign wren[0] = (row_idx == 0); assign wren[1] = (row_idx == 1);
    assign wren[2] = (row_idx == 2); assign wren[3] = (row_idx == 3);
    assign wren[4] = (row_idx == 4);
    //这里是72bit
    m4k_sync_72b u_lb0 (.clock(i_clk), .data(pack_in), .rdaddress(s_cnt_r[0]), .wraddress(s_cnt_r[0]), .wren(wren[0]), .q(q[0]));
    m4k_sync_72b u_lb1 (.clock(i_clk), .data(pack_in), .rdaddress(s_cnt_r[1]), .wraddress(s_cnt_r[1]), .wren(wren[1]), .q(q[1]));
    m4k_sync_72b u_lb2 (.clock(i_clk), .data(pack_in), .rdaddress(s_cnt_r[2]), .wraddress(s_cnt_r[2]), .wren(wren[2]), .q(q[2]));
    m4k_sync_72b u_lb3 (.clock(i_clk), .data(pack_in), .rdaddress(s_cnt_r[3]), .wraddress(s_cnt_r[3]), .wren(wren[3]), .q(q[3]));
    m4k_sync_72b u_lb4 (.clock(i_clk), .data(pack_in), .rdaddress(s_cnt_r[4]), .wraddress(s_cnt_r[4]), .wren(wren[4]), .q(q[4]));

    // 4. 提取 5 行的 Y 和 Y^2 数据 (Y在[63:56], Y^2在[15:0])
    wire [7:0] r1_y = q[(row_idx + 1) % 5][63:56]; wire [15:0] r1_y2 = q[(row_idx + 1) % 5][15:0];
    wire [7:0] r2_y = q[(row_idx + 2) % 5][63:56]; wire [15:0] r2_y2 = q[(row_idx + 2) % 5][15:0];
    wire [7:0] r3_y = q[(row_idx + 3) % 5][63:56]; wire [15:0] r3_y2 = q[(row_idx + 3) % 5][15:0];
    wire [7:0] r4_y = q[(row_idx + 4) % 5][63:56]; wire [15:0] r4_y2 = q[(row_idx + 4) % 5][15:0];
    wire [7:0] r5_y = q[row_idx][63:56];           wire [15:0] r5_y2 = q[row_idx][15:0];

    // 5. 列垂直求和 
    reg [9:0]  sum_y_l1_1, sum_y_l1_2;
    reg [7:0]  sum_y_l1_3;
    reg [17:0] sum_y2_l1_1, sum_y2_l1_2;
    reg [15:0] sum_y2_l1_3;

    reg [10:0] final_col_sum_Y;
    reg [18:0] final_col_sum_Y2;

    always @(posedge i_clk) begin
        sum_y_l1_1 <= r1_y + r2_y; sum_y_l1_2 <= r3_y + r4_y; sum_y_l1_3 <= r5_y;
        sum_y2_l1_1 <= r1_y2 + r2_y2; sum_y2_l1_2 <= r3_y2 + r4_y2; sum_y2_l1_3 <= r5_y2;

        final_col_sum_Y  <= sum_y_l1_1 + sum_y_l1_2 + sum_y_l1_3;
        final_col_sum_Y2 <= sum_y2_l1_1 + sum_y2_l1_2 + sum_y2_l1_3;
    end
    
    // 6. 中心像素 (Row 3) 的 RGB、YCbCr 双旁路与同步信号提取
    reg [23:0] center_ycbcr_d1, center_ycbcr_d2;
    reg [23:0] center_rgb_d1, center_rgb_d2;
    reg        center_hs_d1, center_hs_d2;
    reg        center_vs_d1, center_vs_d2;
    reg        center_de_d1, center_de_d2;

    always @(posedge i_clk) begin
        // 打第 1 拍 (从 q3 中精确双重解包)
        center_ycbcr_d1 <= q[(row_idx + 3) % 5][63:40]; // YCbCr [63:40]
        center_rgb_d1   <= q[(row_idx + 3) % 5][39:16]; // RGB   [39:16]
        
        center_de_d1    <= q[(row_idx + 3) % 5][64];
        center_vs_d1    <= q[(row_idx + 3) % 5][65];
        center_hs_d1    <= q[(row_idx + 3) % 5][66];
        
        // 打第 2 拍，对齐计算
        center_ycbcr_d2 <= center_ycbcr_d1;
        center_rgb_d2   <= center_rgb_d1;
        
        center_hs_d2    <= center_hs_d1;
        center_vs_d2    <= center_vs_d1;
        center_de_d2    <= center_de_d1;
    end

    // 最终输出赋值
    assign o_col_sum_Y  = final_col_sum_Y;
    assign o_col_sum_Y2 = final_col_sum_Y2;
    
    assign o_center_ycbcr = center_ycbcr_d2;
    assign o_center_rgb   = center_rgb_d2;
    
    assign o_hs_center  = center_hs_d2;
    assign o_vs_center  = center_vs_d2;
    assign o_de_center  = center_de_d2;
endmodule