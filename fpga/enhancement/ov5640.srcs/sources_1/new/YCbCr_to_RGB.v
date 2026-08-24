// =============================================================================
// 文件名称：YCbCr_to_RGB.v
// 主要模块：YCbCr_to_RGB
// 功能说明：将 YCbCr 像素转换为 RGB 颜色空间。
// 维护说明：修改接口或时序时，请同步更新本文件注释和上层例化。
// =============================================================================

`timescale 1 ns/ 1 ps
module YCbCr_to_RGB (
    input  wire        i_clk,
    input  wire        i_rst,
    input  wire        i_hs,
    input  wire        i_vs,
    input  wire        i_data_en,
    input  wire [23:0] i_ycbcr,
    input  wire [23:0] i_rgb,          // ԭʼ RGB ��·����
    output wire        o_hs,
    output wire        o_vs,
    output wire        o_data_en,
    output wire [23:0] o_rgb,          // ת������� RGB
    output wire [23:0] o_original_rgb  // ���������ԭʼ RGB ��·���
);

    reg [7:0]  y_in, cb_in, cr_in;
    reg        hs1, vs1, de1;
    reg [23:0] rgb1;

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

    reg signed [9:0] y_s, cb_s, cr_s;
    reg        hs2, vs2, de2;
    reg [23:0] rgb2;

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

    wire signed [19:0] mult_r_cr, mult_g_cb, mult_g_cr, mult_b_cb;

    //LPM_MULT ����Ϊ 2 Clock Latency
    lpmmult_10x10_signed u_mult_r_cr (.clock(i_clk), .dataa(cr_s), .datab(10'sd351), .result(mult_r_cr));
    lpmmult_10x10_signed u_mult_g_cb (.clock(i_clk), .dataa(cb_s), .datab(10'sd86),  .result(mult_g_cb));
    lpmmult_10x10_signed u_mult_g_cr (.clock(i_clk), .dataa(cr_s), .datab(10'sd179), .result(mult_g_cr));
    lpmmult_10x10_signed u_mult_b_cb (.clock(i_clk), .dataa(cb_s), .datab(10'sd443), .result(mult_b_cb));

    reg signed [19:0] y_shifted;
    reg signed [19:0] y_shifted_r;
    reg hs3_r, vs3_r, de3_r;
    reg        hs3, vs3, de3;
    reg [23:0] rgb3;
    reg [23:0] rgb3_r;
    always @(posedge i_clk) begin
        y_shifted_r<= y_s * 20'sd256;
        y_shifted <= y_shifted_r;
        hs3_r <= hs2; vs3_r <= vs2; de3_r <= de2;
        hs3 <= hs3_r; vs3 <= vs3_r; de3 <= de3_r;
        rgb3_r <= rgb2;
        rgb3 <= rgb3_r;
    end

    reg signed [19:0] sum_r, sum_g, sum_b;
    reg        hs4, vs4, de4;
    reg [23:0] rgb4;

    always @(posedge i_clk) begin
        sum_r <= y_shifted + mult_r_cr;
        sum_g <= y_shifted - mult_g_cb - mult_g_cr;
        sum_b <= y_shifted + mult_b_cb;
        hs4 <= hs3; vs4 <= vs3; de4 <= de3;
        rgb4 <= rgb3;
    end

    reg signed [19:0] sum_r_r, sum_g_r, sum_b_r;
    reg        hs5, vs5, de5;
    reg [23:0] rgb5;

    always @(posedge i_clk) begin
        sum_r_r <= sum_r;
        sum_g_r <= sum_g;
        sum_b_r <= sum_b;
        hs5 <= hs4; vs5 <= vs4; de5 <= de4;
        rgb5 <= rgb4;
    end

    reg [23:0] orgb;
    reg [23:0] orig_rgb_out;
    reg ohs, ovs, ode;

    always @(posedge i_clk) begin
        if (i_rst) begin
            orgb <= 0; orig_rgb_out <= 0; {ohs, ovs, ode} <= 0;
        end else begin
            orig_rgb_out <= rgb5;
            if (de5 == 1'b0) begin 
                orgb <= 24'd0;
            end else begin
                // R ǯλ
                if (sum_r_r[19]) orgb[23:16] <= 8'd0;
                else if (sum_r_r[19:8] > 12'sd255) orgb[23:16] <= 8'd255;
                else orgb[23:16] <= sum_r_r[15:8];

                // G ǯλ
                if (sum_g_r[19]) orgb[15:8] <= 8'd0;
                else if (sum_g_r[19:8] > 12'sd255) orgb[15:8] <= 8'd255;
                else orgb[15:8] <= sum_g_r[15:8];

                // B ǯλ
                if (sum_b_r[19]) orgb[7:0] <= 8'd0;
                else if (sum_b_r[19:8] > 12'sd255) orgb[7:0] <= 8'd255;
                else orgb[7:0] <= sum_b_r[15:8];
            end
            ohs <= hs5;
            ovs <= vs5;
            ode <= de5;
        end
    end

    assign o_rgb          = orgb;
    assign o_original_rgb = orig_rgb_out;
    assign o_hs           = ohs;
    assign o_vs           = ovs;
    assign o_data_en      = ode;

endmodule