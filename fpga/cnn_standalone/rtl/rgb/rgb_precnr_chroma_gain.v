module rgb_precnr_chroma_gain
#(
    parameter ENABLE = 1,
    parameter [9:0] GAIN_Q8 = 10'd297
)
(
    input   wire            clk,
    input   wire            rst_n,
    input   wire            in_de,
    input   wire    [23:0]  in_rgb,

    output  reg             out_de,
    output  reg     [23:0]  out_rgb
);

    function [7:0] clip_u8;
        input signed [15:0] value;
        begin
            if (value < 16'sd0)
                clip_u8 = 8'd0;
            else if (value > 16'sd255)
                clip_u8 = 8'd255;
            else
                clip_u8 = value[7:0];
        end
    endfunction

    function signed [11:0] round_shift_q8;
        input signed [22:0] value;
        begin
            if (value >= 23'sd0)
                round_shift_q8 = (value + 23'sd128) >>> 8;
            else
                round_shift_q8 = (value - 23'sd128) >>> 8;
        end
    endfunction

    wire [7:0] in_r_w = in_rgb[23:16];
    wire [7:0] in_g_w = in_rgb[15:8];
    wire [7:0] in_b_w = in_rgb[7:0];

    wire signed [18:0] y_sum_w =
        ($signed({1'b0, in_r_w}) * 19'sd77) +
        ($signed({1'b0, in_g_w}) * 19'sd150) +
        ($signed({1'b0, in_b_w}) * 19'sd29) +
        19'sd128;
    wire signed [18:0] cb_sum_w =
        -($signed({1'b0, in_r_w}) * 19'sd43) -
        ($signed({1'b0, in_g_w}) * 19'sd85) +
        ($signed({1'b0, in_b_w}) * 19'sd128) +
        19'sd128;
    wire signed [18:0] cr_sum_w =
        ($signed({1'b0, in_r_w}) * 19'sd128) -
        ($signed({1'b0, in_g_w}) * 19'sd107) -
        ($signed({1'b0, in_b_w}) * 19'sd21) +
        19'sd128;

    reg             de_s1_r;
    reg             de_s2_r;
    reg     [23:0]  rgb_s1_r;
    reg     [23:0]  rgb_s2_r;
    reg signed [10:0] y_s1_r;
    reg signed [10:0] y_s2_r;
    reg signed [11:0] cb_delta_s1_r;
    reg signed [11:0] cr_delta_s1_r;
    reg signed [11:0] cb_gain_s2_r;
    reg signed [11:0] cr_gain_s2_r;

    wire signed [22:0] cb_gain_mul_w = cb_delta_s1_r * $signed({1'b0, GAIN_Q8});
    wire signed [22:0] cr_gain_mul_w = cr_delta_s1_r * $signed({1'b0, GAIN_Q8});

    wire signed [20:0] r_delta_w = (cr_gain_s2_r * 21'sd359) + 21'sd128;
    wire signed [20:0] g_delta_w = (cb_gain_s2_r * 21'sd88) + (cr_gain_s2_r * 21'sd183) + 21'sd128;
    wire signed [20:0] b_delta_w = (cb_gain_s2_r * 21'sd454) + 21'sd128;

    wire signed [15:0] out_r_w = y_s2_r + (r_delta_w >>> 8);
    wire signed [15:0] out_g_w = y_s2_r - (g_delta_w >>> 8);
    wire signed [15:0] out_b_w = y_s2_r + (b_delta_w >>> 8);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_de <= 1'b0;
            out_rgb <= 24'd0;
            de_s1_r <= 1'b0;
            de_s2_r <= 1'b0;
            rgb_s1_r <= 24'd0;
            rgb_s2_r <= 24'd0;
            y_s1_r <= 11'sd0;
            y_s2_r <= 11'sd0;
            cb_delta_s1_r <= 12'sd0;
            cr_delta_s1_r <= 12'sd0;
            cb_gain_s2_r <= 12'sd0;
            cr_gain_s2_r <= 12'sd0;
        end else begin
            de_s1_r <= in_de;
            de_s2_r <= de_s1_r;
            out_de <= de_s2_r;

            rgb_s1_r <= in_rgb;
            rgb_s2_r <= rgb_s1_r;

            y_s1_r <= y_sum_w[18:8];
            y_s2_r <= y_s1_r;
            cb_delta_s1_r <= cb_sum_w >>> 8;
            cr_delta_s1_r <= cr_sum_w >>> 8;
            cb_gain_s2_r <= round_shift_q8(cb_gain_mul_w);
            cr_gain_s2_r <= round_shift_q8(cr_gain_mul_w);

            if (de_s2_r) begin
                if (ENABLE != 0) begin
                    out_rgb <= {
                        clip_u8(out_r_w),
                        clip_u8(out_g_w),
                        clip_u8(out_b_w)
                    };
                end else begin
                    out_rgb <= rgb_s2_r;
                end
            end else begin
                out_rgb <= 24'd0;
            end
        end
    end

endmodule
