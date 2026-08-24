// =============================================================================
// 项目名称：2026 年全国大学生集成电路创新创业大赛国奖项目
// 工程分区：图像增强工程（enhancement）
// 文件名称：meiyan_rebuild.v
// 主要模块：meiyan_rebuild
// 功能分类：磨皮美颜算法
// 功能说明：融合原始像素与双边平滑结果，抑制皮肤纹理噪声并保留主要边缘。
// 输入概述：像素数据及 HS/VS/DE 视频同步信号；控制参数由模式或模块参数给出。
// 输出概述：处理后的像素流，以及与流水线延迟严格匹配的 HS/VS/DE 信号。
// 时序约束：像素数据在视频像素时钟上升沿处理；复位极性以模块端口定义为准。
// 关联文件：meiyan_bilateral_core.v、meiyan_rom_scurve IP
// 维护要求：修改端口、位宽、流水线延迟或模式编码时，必须同步更新上层例化与项目文档。
// =============================================================================
`timescale 1 ns/ 1 ps
// Line Buffer 驱动 2D形态学 + 双边滤波 + S曲线高端美白 (全IP优化版)

module meiyan_rebuild#(
    parameter cb_l=8'd75, cb_h=8'd135, cr_l=8'd130, cr_h=8'd177, y_l=8'd10,
    parameter H_TOTAL = 11'd1344,
    parameter MEIBAI = 5
)(
    input  wire        i_clk,
    input  wire        i_rst,
    input  wire [11:0] i_mean_a,
    input  wire [11:0] i_mean_b,
    input  wire [23:0] i_ycbcr_sync, 
    input  wire        i_hs,
    input  wire        i_vs,
    input  wire        i_de,

    output wire [23:0] o_final_ycbcr,
    output wire        o_hs_out,
    output wire        o_vs_out,
    output wire        o_de_out
);
    // T1: 引导滤波重建与肤色提取
    reg [11:0] in_mean_a_r; 
    reg [11:0] in_mean_b_r; 
    reg [23:0] in_ycbcr_r;
    reg        in_hs_r, in_vs_r, in_de_r;
    always @(posedge i_clk) begin
        in_mean_a_r <= i_mean_a; 
        in_mean_b_r <= i_mean_b; 
        in_ycbcr_r  <= i_ycbcr_sync;
        in_hs_r <= i_hs; 
        in_vs_r <= i_vs; 
        in_de_r <= i_de;
    end

    wire [7:0] y_raw = in_ycbcr_r[23:16];
    
    // T2
    wire [19:0] mult_a_y; 
    reg [12:0] mean_b_plus_8;
    reg [23:0] ycbcr_d1;
    reg hs_d1, vs_d1, de_d1, is_skin_d1;
    
    lpmmult_12_8 u_mult_a_y(
        .clock(i_clk),                 //input clock
        .dataa(in_mean_a_r),           //input [11:0] dataa
        .datab(y_raw),                 //input [7:0] datab
        .result(mult_a_y)              //output [19:0] result
    );
    
    always @(posedge i_clk) begin
        mean_b_plus_8 <= in_mean_b_r + 13'd8;
        if (in_ycbcr_r[15:8] >= cb_l && in_ycbcr_r[15:8] <= cb_h &&
            in_ycbcr_r[7:0]  >= cr_l && in_ycbcr_r[7:0] <= cr_h 
            && in_ycbcr_r[23:16] >= y_l)
            is_skin_d1 <= 1'b1; 
        else  
            is_skin_d1 <= 1'b0;
            
        ycbcr_d1 <= in_ycbcr_r; 
        hs_d1 <= in_hs_r;
        vs_d1 <= in_vs_r; 
        de_d1 <= in_de_r;
    end
    
    // T3
    reg [12:0] add_q;
    reg [23:0] ycbcr_d2;
    reg hs_d2, vs_d2, de_d2, is_skin_d2;
    
    always @(posedge i_clk) begin
        add_q <= mult_a_y[19:8] + mean_b_plus_8;
        ycbcr_d2 <= ycbcr_d1;
        hs_d2 <= hs_d1; 
        vs_d2 <= vs_d1; 
        de_d2 <= de_d1; 
        is_skin_d2 <= is_skin_d1;
    end

    // T4
    reg [7:0] y_guided;
    reg [23:0] ycbcr_d3; 
    reg hs_d3, vs_d3, de_d3, is_skin_d3;
    
    always @(posedge i_clk) begin
        if(add_q[12:4] > 9'd255) 
            y_guided <= 8'd255; 
        else 
            y_guided <= add_q[11:4];
            
        ycbcr_d3 <= ycbcr_d2;
        hs_d3 <= hs_d2; 
        vs_d3 <= vs_d2;
        de_d3 <= de_d2; 
        is_skin_d3 <= is_skin_d2;
    end

    // 产生 3x3 压缩矩阵与 3行皮肤检测标志
    wire [23:0] packed_rgb = {ycbcr_d3[23:16], ycbcr_d3[15:10], ycbcr_d3[7:2], y_guided[7:4]};
    wire [4:0]  packed_usr = {y_guided[3:0], is_skin_d3};

    wire [23:0] lb_p11, lb_p12, lb_p13;
    wire [23:0] lb_p21, lb_p22, lb_p23;
    wire [23:0] lb_p31, lb_p32, lb_p33;
    wire [4:0]  u_r1, u_r2, u_r3;
    wire lb_hs, lb_vs, lb_de;

    // 实例化 Line Buffer
    bilateral_filtering_Line_buffer_1 #(.H_TOTAL(H_TOTAL)) 
    u_shared_lb (
        .i_clk(i_clk),
        .i_rst(i_rst), 
        .i_hs(hs_d3),
        .i_vs(vs_d3), 
        .i_data_en(de_d3),
        .i_rgb_data(packed_rgb), 
        .i_user_data(packed_usr),
        .o_p11(lb_p11), .o_p12(lb_p12), .o_p13(lb_p13),
        .o_p21(lb_p21), .o_p22(lb_p22), .o_p23(lb_p23),
        .o_p31(lb_p31), .o_p32(lb_p32), .o_p33(lb_p33),
        .o_user_r1(u_r1),
        .o_user_r2(u_r2), 
        .o_user_r3(u_r3),
        .o_hs(lb_hs), 
        .o_vs(lb_vs), 
        .o_data_en(lb_de)
    );

    // 2D 形态学开运算
    reg [14:0] sr_r1, sr_r2, sr_r3;
    always @(posedge i_clk) begin
        sr_r1 <= {sr_r1[13:0], u_r1[0]};
        sr_r2 <= {sr_r2[13:0], u_r2[0]};
        sr_r3 <= {sr_r3[13:0], u_r3[0]};
    end

    wire [14:0] col_and = sr_r1 & sr_r2 & sr_r3;
    wire e1 = col_and[1] & col_and[2] & col_and[3] & col_and[4] & col_and[5];
    wire e3 = col_and[3] & col_and[4] & col_and[5] & col_and[6] & col_and[7];
    wire e5 = col_and[5] & col_and[6] & col_and[7] & col_and[8] & col_and[9];
    wire e7 = col_and[7] & col_and[8] & col_and[9] & col_and[10]& col_and[11];
    wire e9 = col_and[9] & col_and[10]& col_and[11]& col_and[12]& col_and[13];
    
    wire skin_dilated_2d = e1 | e3 | e5 | e7 | e9;

    // 匹配形态学的 8 拍延迟 
    
    wire [255:0] packed_delay_in = {
        32'd0,                   // 补位 32 bits
        lb_p11, lb_p12, lb_p13,  // 72 bits
        lb_p21, lb_p22, lb_p23,  // 72 bits
        lb_p31, lb_p32, lb_p33,  // 72 bits
        u_r2,                    // 5 bits
        lb_hs, lb_vs, lb_de      // 3 bits
    };                           // 总计 256 bits

    wire [255:0] packed_delay_out;

    // 2. 实例化 256 位 RAM 移位寄存器 IP (延迟设为 8 拍)
    shift_delay_256w_8d u_8_cycles_delay (
        .clock    (i_clk),            // input clock
        .shiftin  (packed_delay_in),  // input [255:0] shiftin
        .shiftout (packed_delay_out), // 输出与磨皮滤波流水线对齐的 256 位旁路数据。
        .taps     ()                  // output [255:0] taps (不需要中间抽头，直接悬空不接！)
    );

    // 3. 数据解包 (直接提取低 224 位有效数据)
    wire [23:0] p11_d8, p12_d8, p13_d8;
    wire [23:0] p21_d8, p22_d8, p23_d8;
    wire [23:0] p31_d8, p32_d8, p33_d8;
    wire [4:0]  ur2_d8;
    wire hs_d8, vs_d8, de_d8;

    assign {
        p11_d8, p12_d8, p13_d8,
        p21_d8, p22_d8, p23_d8,
        p31_d8, p32_d8, p33_d8,
        ur2_d8,
        hs_d8, vs_d8, de_d8
    } = packed_delay_out[223:0]; 

    wire [7:0] raw_y_22  = p22_d8[23:16];
    wire [7:0] raw_cb_22 = {p22_d8[15:10], 2'b10}; 
    wire [7:0] raw_cr_22 = {p22_d8[9:4], 2'b10};
    wire [7:0] y_guide_22= {p22_d8[3:0], ur2_d8[4:1]};

    // MEIBAI 参数，用于 Cb 通道线性调色
    wire [8:0] calc_cb_w = raw_cb_22 + (((8'd128 - raw_cb_22)*3'd5) >> MEIBAI);

    // S 曲线 ROM 查表美白 
    wire [7:0] curve_y_out;
    meiyan_rom_scurve u_whitening_curve (
        .address (y_guide_22), 
        .clock   (i_clk),
        .q       (curve_y_out) 
    );

    // T8: 流水线打拍 
    reg [8:0] calc_cb_r;
    reg       skin_r;
    reg [7:0] raw_y_22_r, raw_cb_22_r, raw_cr_22_r;

    reg [23:0] pre_p11, pre_p12, pre_p13;
    reg [23:0] pre_p21,          pre_p23;
    reg [23:0] pre_p31, pre_p32, pre_p33;
    reg pre_hs, pre_vs, pre_de;

    always @(posedge i_clk) begin
        calc_cb_r <= calc_cb_w;
        skin_r    <= skin_dilated_2d;
        
        raw_y_22_r  <= raw_y_22;
        raw_cb_22_r <= raw_cb_22;
        raw_cr_22_r <= raw_cr_22;

        // 边缘 8 像素提取
        pre_p11 <= {p11_d8[23:16], p11_d8[15:10], 2'b10, p11_d8[9:4], 2'b10};
        pre_p12 <= {p12_d8[23:16], p12_d8[15:10], 2'b10, p12_d8[9:4], 2'b10};
        pre_p13 <= {p13_d8[23:16], p13_d8[15:10], 2'b10, p13_d8[9:4], 2'b10};
        
        pre_p21 <= {p21_d8[23:16], p21_d8[15:10], 2'b10, p21_d8[9:4], 2'b10};
        pre_p23 <= {p23_d8[23:16], p23_d8[15:10], 2'b10, p23_d8[9:4], 2'b10};
        
        pre_p31 <= {p31_d8[23:16], p31_d8[15:10], 2'b10, p31_d8[9:4], 2'b10};
        pre_p32 <= {p32_d8[23:16], p32_d8[15:10], 2'b10, p32_d8[9:4], 2'b10};
        pre_p33 <= {p33_d8[23:16], p33_d8[15:10], 2'b10, p33_d8[9:4], 2'b10};

        pre_hs <= hs_d8; 
        pre_vs <= vs_d8; 
        pre_de <= de_d8;
    end

    // T9: 拼装，送入双边滤波
    reg [23:0] bf_p11, bf_p12, bf_p13;
    reg [23:0] bf_p21, bf_p22, bf_p23;
    reg [23:0] bf_p31, bf_p32, bf_p33;
    reg bf_hs, bf_vs, bf_de;

    always @(posedge i_clk) begin
        bf_p11 <= pre_p11; bf_p12 <= pre_p12; bf_p13 <= pre_p13;
        bf_p21 <= pre_p21;                    bf_p23 <= pre_p23;
        bf_p31 <= pre_p31; bf_p32 <= pre_p32; bf_p33 <= pre_p33;

        bf_p22 <= {
            (skin_r ? curve_y_out : raw_y_22_r), 
            (skin_r ? ((raw_cb_22_r < 8'd128) ? calc_cb_r[7:1] : 7'd64) : raw_cb_22_r[7:1]), 
            (skin_r), 
            raw_cr_22_r
        };
        
        bf_hs <= pre_hs; bf_vs <= pre_vs; bf_de <= pre_de;
    end

    // 双边滤波 Core
    meiyan_bilateral_core u_bilateral_core_final (
        .i_clk(i_clk), .i_rst(i_rst), 
        .i_hs(bf_hs), .i_vs(bf_vs), .i_data_en(bf_de),
        
        .i_p11(bf_p11), .i_p12(bf_p12), .i_p13(bf_p13),
        .i_p21(bf_p21), .i_p22(bf_p22), .i_p23(bf_p23),
        .i_p31(bf_p31), .i_p32(bf_p32), .i_p33(bf_p33),
        
        .o_hs(o_hs_out), .o_vs(o_vs_out), .o_data_en(o_de_out),
        .o_ycbcr_filtered(o_final_ycbcr) 
    );

endmodule
