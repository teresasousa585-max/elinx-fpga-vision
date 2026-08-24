// =============================================================================
// 文件名称：bilateral_filtering_Line_buffer.v
// 主要模块：bilateral_filtering_Line_buffer
// 功能说明：缓存双边滤波所需的邻域像素行。
// 维护说明：修改接口或时序时，请同步更新本文件注释和上层例化。
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
    reg [10:0] s_cnt_d1; // ר�Ÿ� LB1 д����׼�����ӳٵ�ַ

    always @(posedge i_clk) begin
        if (i_rst) begin
            s_cnt    <= 0;
            s_cnt_d1 <= 0;
        end else begin
            s_cnt    <= (s_cnt == H_TOTAL - 1) ? 0 : s_cnt + 1;
            s_cnt_d1 <= s_cnt; 
        end
    end

    // ������ͬ���źŴ�� 
    wire [31:0] pack_in = {5'd0, i_hs, i_vs, i_data_en, i_rgb_data};
    wire [31:0] q1_32, q2_32;

    // LB2: ���м���
    // ��д��ַͬ������ǰ�н�����һ��ͬ�г�
    m4k_sync u_lb2 (
        .clock     (i_clk),
        .wren      (1'b1),               
        .wraddress (s_cnt),
        .rdaddress (s_cnt),
        .data      (pack_in),
        .q         (q2_32)
    );

    // LB1: ��������
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

    wire [23:0] row1_rgb = q1_32[23:0];      // ������ (��)
    wire [23:0] row2_rgb = q2_32[23:0];      // �м��� (��)
    wire [23:0] row3_rgb = pack_in_d1[23:0]; // ��ǰ�� (��)

    wire [2:0] row2_sync = q2_32[26:24];     

    // 3x3 ������λ
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