// =============================================================================
// 项目名称：2026 年全国大学生集成电路创新创业大赛国奖项目
// 工程分区：图像增强工程（enhancement）
// 文件名称：bilateral_filtering_Line_buffer.v
// 主要模块：bilateral_filtering_Line_buffer
// 功能分类：双边滤波算法
// 功能说明：使用行存储构造连续 3×3 像素窗口，并将窗口数据与 HS/VS/DE 信号对齐。
// 输入概述：像素数据及 HS/VS/DE 视频同步信号；控制参数由模式或模块参数给出。
// 输出概述：处理后的像素流，以及与流水线延迟严格匹配的 HS/VS/DE 信号。
// 时序约束：像素数据在视频像素时钟上升沿处理；复位极性以模块端口定义为准。
// 关联文件：bilateral_core.v、bilateral_filtering_proc_to_hdmi.v
// 维护要求：修改端口、位宽、流水线延迟或模式编码时，必须同步更新上层例化与项目文档。
// =============================================================================
`timescale 1ns / 1ps

module bilateral_filtering_Line_buffer #(
    parameter H_TOTAL        = 11'd1344 
)(
    input wire i_clk,
    input wire i_rst,
    input wire i_hs,
    input wire i_vs,
    input wire i_data_en,
    input wire [23:0] i_rgb_data,

    output wire [23:0] o_p11, o_p12, o_p13,
    output wire [23:0] o_p21, o_p22, o_p23,
    output wire [23:0] o_p31, o_p32, o_p33,
    output wire o_hs,
    output wire o_vs,
    output wire o_data_en
);

    reg [10:0] s_cnt;
    reg [10:0] s_cnt_d1; // 专门给 LB1 写操作准备的延迟地址

    always @(posedge i_clk) begin
        if (i_rst) begin
            s_cnt    <= 0;
            s_cnt_d1 <= 0;
        end else begin
            s_cnt    <= (s_cnt == H_TOTAL - 1) ? 0 : s_cnt + 1;
            s_cnt_d1 <= s_cnt; 
        end
    end

    // 数据与同步信号打包
    wire [31:0] pack_in = {5'd0, i_hs, i_vs, i_data_en, i_rgb_data};
    wire [31:0] q1_32, q2_32;

    // LB2: 存中间行
    // 读写地址同步：当前列进，上一行同列出
    m4k_sync u_lb2 (
        .clock     (i_clk),
        .wren      (1'b1),               
        .wraddress (s_cnt),
        .rdaddress (s_cnt),
        .data      (pack_in),
        .q         (q2_32)
    );

    // LB1: 存最老行
    m4k_sync u_lb1 (
        .clock     (i_clk),
        .wren      (1'b1),              
        .wraddress (s_cnt_d1), 
        .rdaddress (s_cnt),    
        .data      (q2_32),              
        .q         (q1_32)
    );

    reg [31:0] pack_in_d1;
    always @(posedge i_clk) begin
        pack_in_d1 <= pack_in;
    end

    wire [23:0] row1_rgb = q1_32[23:0];      // 最老行 (上)
    wire [23:0] row2_rgb = q2_32[23:0];      // 中间行 (中)
    wire [23:0] row3_rgb = pack_in_d1[23:0]; // 当前行 (下)

    wire [2:0] row2_sync = q2_32[26:24];     

    // 3x3 窗口移位
    reg [23:0] w11,w12,w13, w21,w22,w23, w31,w32,w33;
    reg [2:0]  sync_shift [0:2];

    always @(posedge i_clk) begin
        if (i_rst) begin
            {w11,w12,w13, w21,w22,w23, w31,w32,w33} <= 0;
            sync_shift[0] <= 0; sync_shift[1] <= 0; sync_shift[2] <= 0;
        end else begin
            w13 <= row1_rgb; w12 <= w13; w11 <= w12;
            w23 <= row2_rgb; w22 <= w23; w21 <= w22;
            w33 <= row3_rgb; w32 <= w33; w31 <= w32;

            sync_shift[0] <= row2_sync;
            sync_shift[1] <= sync_shift[0];
            sync_shift[2] <= sync_shift[1];
        end
    end

    reg [23:0] op11,op12,op13, op21,op22,op23, op31,op32,op33;
    reg ohs, ovs, ode;

    always @(posedge i_clk) begin
        if (i_rst) begin
            {op11,op12,op13, op21,op22,op23, op31,op32,op33} <= 0;
            {ohs, ovs, ode} <= 0;
        end else begin
            if (sync_shift[1][0] == 1'b0) begin 
                {op11,op12,op13, op21,op22,op23, op31,op32,op33} <= 0;
            end else begin
                {op11,op12,op13} <= {w11,w12,w13};
                {op21,op22,op23} <= {w21,w22,w23};
                {op31,op32,op33} <= {w31,w32,w33};
            end
            ohs <= sync_shift[1][2];
            ovs <= sync_shift[1][1];
            ode <= sync_shift[1][0];
        end
    end

    assign {o_p11,o_p12,o_p13} = {op11,op12,op13};
    assign {o_p21,o_p22,o_p23} = {op21,op22,op23};
    assign {o_p31,o_p32,o_p33} = {op31,op32,op33};
    assign o_hs = ohs;
    assign o_vs = ovs;
    assign o_data_en = ode;

endmodule
