// =============================================================================
// 项目名称：2026 年全国大学生集成电路创新创业大赛国奖项目
// 工程分区：图像增强工程（enhancement）
// 文件名称：anguang_enhance_apply.v
// 主要模块：anguang_enhance_apply
// 功能分类：暗光增强算法
// 功能说明：根据估计照度计算像素增益，完成暗部提升、亮部保护与输出限幅。
// 输入概述：像素数据及 HS/VS/DE 视频同步信号；控制参数由模式或模块参数给出。
// 输出概述：处理后的像素流，以及与流水线延迟严格匹配的 HS/VS/DE 信号。
// 时序约束：像素数据在视频像素时钟上升沿处理；复位极性以模块端口定义为准。
// 关联文件：anguang_guided.v、anguang_tohdmi.v、anguang_gain IP
// 维护要求：修改端口、位宽、流水线延迟或模式编码时，必须同步更新上层例化与项目文档。
// =============================================================================
`timescale 1 ns/ 1 ps
module anguang_enhance_apply(

    input  wire        i_clk,
    input  wire        i_rst,
    
    input  wire [7:0]  i_y_guided,    // 引导滤波算出来的环境光
    input  wire [23:0] i_rgb_aligned, // 准确对齐的原始 RGB 旁路
    input  wire        i_hs,
    input  wire        i_vs,
    input  wire        i_de,
    
    output wire [23:0] o_rgb_original,
    output wire [23:0] o_rgb_final,
    output wire        o_hs,
    output wire        o_vs,
    output wire        o_de
);

    wire [23:0] rom_data_out;

    anguang_gain u_gain_lut (
    .address(i_y_guided)                ,//input [7:0] address
    .clock(i_clk)                   ,//input clock
    .q(rom_data_out)                            //output [23:0] q
    );


    reg [23:0] rgb_d1;
    reg [7:0]  y_guided_d1;
    reg        hs_d1, vs_d1, de_d1;

    always @(posedge i_clk) begin
        rgb_d1      <= i_rgb_aligned;
        y_guided_d1 <= i_y_guided;
        hs_d1       <= i_hs;
        vs_d1       <= i_vs;
        de_d1       <= i_de;
    end

    // Stage 2: 提取增益
    wire [11:0] gain_y = rom_data_out[23:12]; // 亮度增益 (定点数，256代表1倍)
    wire [11:0] gain_s = rom_data_out[11:0];  // 饱和度增益 (定点数，256代表1倍)
    // 分离 R, G, B
    wire [7:0] r_in = rgb_d1[23:16];
    wire [7:0] g_in = rgb_d1[15:8];
    wire [7:0] b_in = rgb_d1[7:0];

   
    reg [23:0] rgb_original_d1;
    wire [19:0] r_boost_mult, g_boost_mult, b_boost_mult;
    wire [19:0] y_boost_mult;
    
    reg [11:0] gain_s_d2;
    reg        hs_d2, vs_d2, de_d2;

    lpmmult_12_8 u_r_boost_mult(
    .clock(i_clk)               ,//input clock
    .dataa(gain_y)              ,//input [11:0] dataa
    .datab(r_in)                ,//input [7:0] datab
    .result(r_boost_mult)               //output [19:0] result
    );
    lpmmult_12_8 u_g_boost_mult(
        .clock(i_clk)               ,//input clock
        .dataa(gain_y)              ,//input [11:0] dataa
        .datab(g_in)                ,//input [7:0] datab
        .result(g_boost_mult)               //output [19:0] result
    );
    lpmmult_12_8 u_b_boost_mult(
        .clock(i_clk)               ,//input clock
        .dataa(gain_y)              ,//input [11:0] dataa
        .datab(b_in)                ,//input [7:0] datab
        .result(b_boost_mult)               //output [19:0] result
    );
    lpmmult_12_8 u_y_boost_mult(
        .clock(i_clk),
        .dataa(gain_y),
        .datab(y_guided_d1),
        .result(y_boost_mult)
        );

    always @(posedge i_clk) begin
        
        gain_s_d2    <= gain_s; // 饱和度系数打拍陪跑
        rgb_original_d1 <= rgb_d1;

        hs_d2 <= hs_d1; vs_d2 <= vs_d1; de_d2 <= de_d1;
    end

    // 移位还原定点数 (>> 8)
    reg [11:0] r_boost,g_boost,b_boost,y_boost;
    reg [11:0] gain_s_d3;
    reg        hs_d3, vs_d3, de_d3; 
    reg [23:0] rgb_original_d2;
    always @(posedge i_clk) begin
        rgb_original_d2 <= rgb_original_d1;
        gain_s_d3 <= gain_s_d2;
        hs_d3 <= hs_d2; vs_d3 <= vs_d2; de_d3 <= de_d2;
        r_boost <= r_boost_mult[19:8];
        g_boost <= g_boost_mult[19:8];
        b_boost <= b_boost_mult[19:8];
        y_boost <= y_boost_mult[19:8];
    end

    // Stage 3: 计算饱和度色差 (R/G/B_boost - Y_boost)
    reg signed [12:0] r_diff, g_diff, b_diff;
    reg [11:0]        y_boost_d3;
    reg [11:0]        gain_s_d4;
    reg               hs_d4, vs_d4, de_d4;
    reg [23:0] rgb_original_d3;
    
    wire signed [12:0] r_boost_s = {1'b0, r_boost};
    wire signed [12:0] g_boost_s = {1'b0, g_boost};
    wire signed [12:0] b_boost_s = {1'b0, b_boost};
    wire signed [12:0] y_boost_s = {1'b0, y_boost};

    always @(posedge i_clk) begin
        r_diff <= r_boost_s - y_boost_s;
        g_diff <= g_boost_s - y_boost_s;
        b_diff <= b_boost_s - y_boost_s;
        
        y_boost_d3 <= y_boost;
        gain_s_d4  <= gain_s_d3;
        rgb_original_d3 <= rgb_original_d2;
        hs_d4 <= hs_d3; vs_d4 <= vs_d3; de_d4 <= de_d3;
    end

    // Stage 4: 补偿乘法并加回亮度
    reg signed [25:0] r_comp_mult, g_comp_mult, b_comp_mult;
    reg [11:0]        y_boost_d4;
    reg [11:0]        y_boost_d5;
    reg               hs_d5, vs_d5, de_d5;
    reg               hs_d6, vs_d6, de_d6;
    reg [23:0] rgb_original_d4;
    reg [23:0] rgb_original_d5;
    
    //确保与有符号数 (diff) 乘法的操作数也是有符号的
    wire signed [12:0] gain_s_signed = {1'b0, gain_s_d3};
    //乘法器打两拍
lpmmult_13_13_signed u_r_comp_mult (
    .clock(i_clk)               ,//input clock
    .dataa(r_diff)              ,//input [12:0] dataa
    .datab(gain_s_signed)               ,//input [12:0] datab
    .result(r_comp_mult)                //output [25:0] result
);
lpmmult_13_13_signed u_g_comp_mult (
    .clock(i_clk)               ,//input clock
    .dataa(g_diff)              ,//input [12:0] dataa
    .datab(gain_s_signed)               ,//input [12:0] datab
    .result(g_comp_mult)                //output [25:0] result
);
lpmmult_13_13_signed u_b_comp_mult (
    .clock(i_clk)               ,//input clock
    .dataa(b_diff)              ,//input [12:0] dataa
    .datab(gain_s_signed)               ,//input [12:0] datab
    .result(b_comp_mult)                //output [25:0] result
);
    always @(posedge i_clk) begin
        y_boost_d4 <= y_boost_d3;
        y_boost_d5 <= y_boost_d4;
        rgb_original_d4 <= rgb_original_d3;
        rgb_original_d5 <= rgb_original_d4;
        hs_d5 <= hs_d4; vs_d5 <= vs_d4; de_d5 <= de_d4;
        hs_d6 <= hs_d5; vs_d6 <= vs_d5; de_d6 <= de_d5;
    end

    // Stage 5: 最终加和计算
    reg       hs_d7, vs_d7, de_d7;
    reg [23:0] rgb_original_d6;
    reg       hs_d8, vs_d8, de_d8;
    reg [23:0] rgb_original_d7;
    reg signed [15:0] final_r_calc;
    reg signed [15:0] final_g_calc;
    reg signed [15:0] final_b_calc;
    reg signed [15:0] final_r_calc_r;
    reg signed [15:0] final_g_calc_r;
    reg signed [15:0] final_b_calc_r;

    wire signed [15:0] y_boost_d5_s = {4'd0, y_boost_d5};
    wire signed [15:0] r_comp_slice = r_comp_mult[23:8];
    wire signed [15:0] g_comp_slice = g_comp_mult[23:8];
    wire signed [15:0] b_comp_slice = b_comp_mult[23:8];

    always @(posedge i_clk) begin
       final_r_calc_r <= y_boost_d5_s + r_comp_slice;
       final_g_calc_r <= y_boost_d5_s + g_comp_slice;
       final_b_calc_r <= y_boost_d5_s + b_comp_slice;
       final_r_calc <= final_r_calc_r;
       final_g_calc <= final_g_calc_r;
       final_b_calc <= final_b_calc_r;

       rgb_original_d6 <= rgb_original_d5;
       rgb_original_d7 <= rgb_original_d6;
       hs_d7 <= hs_d6;
       vs_d7 <= vs_d6;
       de_d7 <= de_d6;
       hs_d8 <= hs_d7;
       vs_d8 <= vs_d7;
       de_d8 <= de_d7;
    end

    // ==========================================
    // 时序优化：将防爆钳位操作拆分为两拍 (Pipeline)
    // ==========================================
    
    // 【拆分第 1 拍】：仅判断下限 (< 0)
    reg signed [15:0] r_clamp_low, g_clamp_low, b_clamp_low;
    reg        hs_d9, vs_d9, de_d9;
    reg [23:0] rgb_original_d8;
    
    always @(posedge i_clk) begin
        // 下限防爆：如果小于 0 则归零，否则保留原 16位 有符号数以便下一步判定
        r_clamp_low <= (final_r_calc < 0) ? 16'd0 : final_r_calc;
        g_clamp_low <= (final_g_calc < 0) ? 16'd0 : final_g_calc;
        b_clamp_low <= (final_b_calc < 0) ? 16'd0 : final_b_calc;
        
        // 同步打拍
        rgb_original_d8 <= rgb_original_d7;
        hs_d9 <= hs_d8;
        vs_d9 <= vs_d8;
        de_d9 <= de_d8;
    end

    // 【拆分第 2 拍】：仅判断上限 (> 255)
    reg [7:0]  r_final, g_final, b_final;
    reg        hs_d10, vs_d10, de_d10;
    reg [23:0] rgb_original_d9;

    always @(posedge i_clk) begin
        // 上限防爆：如果大于 255 则封顶，否则截取低 8 位安全输出
        r_final <= (r_clamp_low > 255) ? 8'd255 : r_clamp_low[7:0];
        g_final <= (g_clamp_low > 255) ? 8'd255 : g_clamp_low[7:0];
        b_final <= (b_clamp_low > 255) ? 8'd255 : b_clamp_low[7:0];
        
        // 同步打拍
        rgb_original_d9 <= rgb_original_d8;
        hs_d10 <= hs_d9;
        vs_d10 <= vs_d9;
        de_d10 <= de_d9;
    end

    // 【最终输出缓冲排】：保持你原有的最末端寄存器习惯
    reg        hs_d11, vs_d11, de_d11;
    reg [23:0] rgb_original_d10;
    reg [7:0]  r_final_r, g_final_r, b_final_r;
    
    always @(posedge i_clk) begin
        r_final_r <= r_final;
        g_final_r <= g_final;
        b_final_r <= b_final;
        
        // 同步打拍
        rgb_original_d10 <= rgb_original_d9;
        hs_d11 <= hs_d10;
        vs_d11 <= vs_d10;
        de_d11 <= de_d10;
    end

    // 赋值输出端，对应顺延后的寄存器
    assign o_rgb_final = {r_final_r, g_final_r, b_final_r};
    assign o_hs        = hs_d11;
    assign o_vs        = vs_d11;
    assign o_de        = de_d11;
    assign o_rgb_original  = rgb_original_d10;

endmodule