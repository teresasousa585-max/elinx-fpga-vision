module rgb_ccm_3x3
#(
    parameter signed [11:0] M_RR = 12'sd256,
    parameter signed [11:0] M_RG = 12'sd0,
    parameter signed [11:0] M_RB = 12'sd0,
    parameter signed [11:0] M_GR = 12'sd0,
    parameter signed [11:0] M_GG = 12'sd256,
    parameter signed [11:0] M_GB = 12'sd0,
    parameter signed [11:0] M_BR = 12'sd0,
    parameter signed [11:0] M_BG = 12'sd0,
    parameter signed [11:0] M_BB = 12'sd256
)
(
    input   wire            clk,
    input   wire            rst_n,
    input   wire            in_de,
    input   wire    [23:0]  in_rgb,

    output  reg             out_de,
    output  reg     [23:0]  out_rgb
);

    function [7:0] clip_ccm_u8;
        input signed [23:0] value;
        begin
            if (value < 24'sd0)
                clip_ccm_u8 = 8'd0;
            else if (value > 24'sd255)
                clip_ccm_u8 = 8'd255;
            else
                clip_ccm_u8 = value[7:0];
        end
    endfunction

    reg                     de_d1_r;
    reg signed [20:0]       rr_mul_r;
    reg signed [20:0]       rg_mul_r;
    reg signed [20:0]       rb_mul_r;
    reg signed [20:0]       gr_mul_r;
    reg signed [20:0]       gg_mul_r;
    reg signed [20:0]       gb_mul_r;
    reg signed [20:0]       br_mul_r;
    reg signed [20:0]       bg_mul_r;
    reg signed [20:0]       bb_mul_r;

    wire signed [23:0]      r_sum_w;
    wire signed [23:0]      g_sum_w;
    wire signed [23:0]      b_sum_w;

    assign r_sum_w = $signed({rr_mul_r[20], rr_mul_r}) +
                     $signed({rg_mul_r[20], rg_mul_r}) +
                     $signed({rb_mul_r[20], rb_mul_r}) + 24'sd128;
    assign g_sum_w = $signed({gr_mul_r[20], gr_mul_r}) +
                     $signed({gg_mul_r[20], gg_mul_r}) +
                     $signed({gb_mul_r[20], gb_mul_r}) + 24'sd128;
    assign b_sum_w = $signed({br_mul_r[20], br_mul_r}) +
                     $signed({bg_mul_r[20], bg_mul_r}) +
                     $signed({bb_mul_r[20], bb_mul_r}) + 24'sd128;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            de_d1_r <= 1'b0;
            rr_mul_r <= 21'sd0;
            rg_mul_r <= 21'sd0;
            rb_mul_r <= 21'sd0;
            gr_mul_r <= 21'sd0;
            gg_mul_r <= 21'sd0;
            gb_mul_r <= 21'sd0;
            br_mul_r <= 21'sd0;
            bg_mul_r <= 21'sd0;
            bb_mul_r <= 21'sd0;
        end else begin
            de_d1_r <= in_de;

            rr_mul_r <= $signed({1'b0, in_rgb[23:16]}) * M_RR;
            rg_mul_r <= $signed({1'b0, in_rgb[15:8]})  * M_RG;
            rb_mul_r <= $signed({1'b0, in_rgb[7:0]})   * M_RB;
            gr_mul_r <= $signed({1'b0, in_rgb[23:16]}) * M_GR;
            gg_mul_r <= $signed({1'b0, in_rgb[15:8]})  * M_GG;
            gb_mul_r <= $signed({1'b0, in_rgb[7:0]})   * M_GB;
            br_mul_r <= $signed({1'b0, in_rgb[23:16]}) * M_BR;
            bg_mul_r <= $signed({1'b0, in_rgb[15:8]})  * M_BG;
            bb_mul_r <= $signed({1'b0, in_rgb[7:0]})   * M_BB;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_de  <= 1'b0;
            out_rgb <= 24'd0;
        end else begin
            out_de <= de_d1_r;

            if (de_d1_r) begin
                out_rgb <= {
                    clip_ccm_u8(r_sum_w >>> 8),
                    clip_ccm_u8(g_sum_w >>> 8),
                    clip_ccm_u8(b_sum_w >>> 8)
                };
            end else begin
                out_rgb <= 24'd0;
            end
        end
    end

endmodule
