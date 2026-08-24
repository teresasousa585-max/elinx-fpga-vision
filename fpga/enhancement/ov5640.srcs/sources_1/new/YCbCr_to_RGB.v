// =============================================================================
// 项目名称：2026 年全国大学生集成电路创新创业大赛国奖项目
// 作者：Ethereal
// 工程分区：图像增强工程（enhancement）
// 文件名称：YCbCr_to_RGB.v
// 主要模块：YCbCr_to_RGB
// 功能分类：颜色空间转换
// 功能说明：将处理后的 YCbCr 像素恢复为 RGB888，并对齐原始旁路数据与视频同步信号。
// 输入概述：像素数据及 HS/VS/DE 视频同步信号；控制参数由模式或模块参数给出。
// 输出概述：处理后的像素流，以及与流水线延迟严格匹配的 HS/VS/DE 信号。
// 时序约束：像素数据在视频像素时钟上升沿处理；复位极性以模块端口定义为准。
// 关联文件：RGB_to_YCbCr.v、rgb2ycbcr.v
// 维护要求：修改端口、位宽、流水线延迟或模式编码时，必须同步更新上层例化与项目文档。
// =============================================================================
`timescale 1 ns/ 1 ps
// -----------------------------------------------------------------------------
// 正文导读：将处理后的 YCbCr 像素恢复为 RGB888，并对齐原始旁路数据与视频同步信号。
// 阅读顺序：先确认参数和端口，再沿内部信号、时序过程及子模块例化追踪数据流。
// 修改约束：像素数据、有效信号和 HS/VS 必须保持同拍；跨时钟数据必须使用 FIFO 或握手。
// -----------------------------------------------------------------------------
// 模块 YCbCr_to_RGB：以下接口构成综合边界，上层通过端口连接数据流、控制流和状态信号。
module YCbCr_to_RGB (
    // 接口信号：input 接收上游数据/控制，output 返回处理结果/状态，inout 连接双向器件总线。
    input  wire        i_clk,
    input  wire        i_rst,
    input  wire        i_hs,
    input  wire        i_vs,
    input  wire        i_data_en,
    input  wire [23:0] i_ycbcr,
    input  wire [23:0] i_rgb,          // 原始 RGB 旁路输入
    output wire        o_hs,
    output wire        o_vs,
    output wire        o_data_en,
    output wire [23:0] o_rgb,          // 转换后的新 RGB
    output wire [23:0] o_original_rgb  // 准确对齐的原始 RGB 旁路输出
);

    // 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
    reg [7:0]  y_in, cb_in, cr_in;
    reg        hs1, vs1, de1;
    reg [23:0] rgb1;

    // 时序过程 1：由 i_clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
    always @(posedge i_clk) begin
        if (i_rst) begin
            {y_in, cb_in, cr_in} <= 0;
            {hs1, vs1, de1} <= 0;
            rgb1 <= 0;
        end else begin
            y_in  <= i_ycbcr[23:16];
            cb_in <= i_ycbcr[15:8];
            cr_in <= i_ycbcr[7:0];
            hs1   <= i_hs;
            vs1   <= i_vs;
            de1   <= i_data_en;
            rgb1  <= i_rgb;
        end
    end

    // 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
    reg signed [9:0] y_s, cb_s, cr_s;
    reg        hs2, vs2, de2;
    reg [23:0] rgb2;

    // 时序过程 2：由 i_clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
    always @(posedge i_clk) begin
        if (i_rst) begin
            {y_s, cb_s, cr_s} <= 0;
            {hs2, vs2, de2} <= 0;
            rgb2 <= 0;
        end else begin
            y_s  <= {2'b00, y_in};
            cb_s <= {2'b00, cb_in} - 10'sd128;
            cr_s <= {2'b00, cr_in} - 10'sd128;
            hs2  <= hs1;
            vs2  <= vs1;
            de2  <= de1;
            rgb2 <= rgb1;
        end
    end

    // 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
    wire signed [19:0] mult_r_cr, mult_g_cb, mult_g_cr, mult_b_cb;

    //LPM_MULT 设置为 2 Clock Latency
    // 子模块例化 1（lpmmult_10x10_signed）：封装定点乘法器 IP，完成算法流水线中的乘法运算。
    lpmmult_10x10_signed u_mult_r_cr (.clock(i_clk), .dataa(cr_s), .datab(10'sd351), .result(mult_r_cr));
    // 子模块例化 2（lpmmult_10x10_signed）：封装定点乘法器 IP，完成算法流水线中的乘法运算。
    lpmmult_10x10_signed u_mult_g_cb (.clock(i_clk), .dataa(cb_s), .datab(10'sd86),  .result(mult_g_cb));
    // 子模块例化 3（lpmmult_10x10_signed）：封装定点乘法器 IP，完成算法流水线中的乘法运算。
    lpmmult_10x10_signed u_mult_g_cr (.clock(i_clk), .dataa(cr_s), .datab(10'sd179), .result(mult_g_cr));
    // 子模块例化 4（lpmmult_10x10_signed）：封装定点乘法器 IP，完成算法流水线中的乘法运算。
    lpmmult_10x10_signed u_mult_b_cb (.clock(i_clk), .dataa(cb_s), .datab(10'sd443), .result(mult_b_cb));

    // 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
    reg signed [19:0] y_shifted;
    reg signed [19:0] y_shifted_r;
    reg hs3_r, vs3_r, de3_r;
    reg        hs3, vs3, de3;
    reg [23:0] rgb3;
    reg [23:0] rgb3_r;
    // 时序过程 3：由 i_clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
    always @(posedge i_clk) begin
        y_shifted_r<= y_s * 20'sd256;
        y_shifted <= y_shifted_r;
        hs3_r <= hs2; vs3_r <= vs2; de3_r <= de2;
        hs3 <= hs3_r; vs3 <= vs3_r; de3 <= de3_r;
        rgb3_r <= rgb2;
        rgb3 <= rgb3_r;
    end

    // 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
    reg signed [19:0] sum_r, sum_g, sum_b;
    reg        hs4, vs4, de4;
    reg [23:0] rgb4;

    // 时序过程 4：由 i_clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
    always @(posedge i_clk) begin
        sum_r <= y_shifted + mult_r_cr;
        sum_g <= y_shifted - mult_g_cb - mult_g_cr;
        sum_b <= y_shifted + mult_b_cb;
        hs4 <= hs3; vs4 <= vs3; de4 <= de3;
        rgb4 <= rgb3;
    end

    // 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
    reg signed [19:0] sum_r_r, sum_g_r, sum_b_r;
    reg        hs5, vs5, de5;
    reg [23:0] rgb5;

    // 时序过程 5：由 i_clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
    always @(posedge i_clk) begin
        sum_r_r <= sum_r;
        sum_g_r <= sum_g;
        sum_b_r <= sum_b;
        hs5 <= hs4; vs5 <= vs4; de5 <= de4;
        rgb5 <= rgb4;
    end

    // 内部信号：用于流水级对齐、状态保存或子模块互连；位宽必须覆盖最坏计算范围。
    reg [23:0] orgb;
    reg [23:0] orig_rgb_out;
    reg ohs, ovs, ode;

    // 时序过程 6：由 i_clk posedge 触发，用于寄存数据、推进状态或对齐流水线；复位优先级不可随意调整。
    always @(posedge i_clk) begin
        if (i_rst) begin
            orgb <= 0; orig_rgb_out <= 0; {ohs, ovs, ode} <= 0;
        end else begin
            orig_rgb_out <= rgb5;
            if (de5 == 1'b0) begin 
                orgb <= 24'd0;
            end else begin
                // R 钳位
                if (sum_r_r[19]) orgb[23:16] <= 8'd0;
                else if (sum_r_r[19:8] > 12'sd255) orgb[23:16] <= 8'd255;
                else orgb[23:16] <= sum_r_r[15:8];

                // G 钳位
                if (sum_g_r[19]) orgb[15:8] <= 8'd0;
                else if (sum_g_r[19:8] > 12'sd255) orgb[15:8] <= 8'd255;
                else orgb[15:8] <= sum_g_r[15:8];

                // B 钳位
                if (sum_b_r[19]) orgb[7:0] <= 8'd0;
                else if (sum_b_r[19:8] > 12'sd255) orgb[7:0] <= 8'd255;
                else orgb[7:0] <= sum_b_r[15:8];
            end
            ohs <= hs5;
            ovs <= vs5;
            ode <= de5;
        end
    end

    // 组合连线组 1：从 o_rgb 开始的连续赋值随右值立即更新，不增加寄存器延迟。
    assign o_rgb          = orgb;
    assign o_original_rgb = orig_rgb_out;
    assign o_hs           = ohs;
    assign o_vs           = ovs;
    assign o_data_en      = ode;

endmodule