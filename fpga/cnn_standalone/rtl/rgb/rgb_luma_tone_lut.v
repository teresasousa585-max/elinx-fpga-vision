`timescale 1ns/1ps

module rgb_luma_tone_lut
#(
    parameter ENABLE = 1,
    parameter [3:0] PROFILE = 4'd1
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
        input signed [9:0] value;
        begin
            if (value < 10'sd0)
                clip_u8 = 8'd0;
            else if (value > 10'sd255)
                clip_u8 = 8'd255;
            else
                clip_u8 = value[7:0];
        end
    endfunction

    wire [7:0] in_r_w = in_rgb[23:16];
    wire [7:0] in_g_w = in_rgb[15:8];
    wire [7:0] in_b_w = in_rgb[7:0];
    reg             de_s1_r;
    reg             de_s2_r;
    reg             de_s3_r;
    reg             de_s4_r;
    reg             de_s5_r;
    reg             de_s6_r;
    (* synthesis, probe_port, keep, preserve, noprune, syn_preserve = 1, syn_keep = 1, altera_attribute = "-name AUTO_SHIFT_REGISTER_RECOGNITION OFF" *) reg     [23:0]  rgb_s1_r;
    (* synthesis, probe_port, keep, preserve, noprune, syn_preserve = 1, syn_keep = 1, altera_attribute = "-name AUTO_SHIFT_REGISTER_RECOGNITION OFF" *) reg     [23:0]  rgb_s2_r;
    (* synthesis, probe_port, keep, preserve, noprune, syn_preserve = 1, syn_keep = 1, altera_attribute = "-name AUTO_SHIFT_REGISTER_RECOGNITION OFF" *) reg     [23:0]  rgb_s3_r;
    (* synthesis, probe_port, keep, preserve, noprune, syn_preserve = 1, syn_keep = 1, altera_attribute = "-name AUTO_SHIFT_REGISTER_RECOGNITION OFF" *) reg     [23:0]  rgb_s4_r;
    (* synthesis, probe_port, keep, preserve, noprune, syn_preserve = 1, syn_keep = 1, altera_attribute = "-name AUTO_SHIFT_REGISTER_RECOGNITION OFF" *) reg     [23:0]  rgb_s5_r;
    reg     [23:0]  rgb_s6_r;
    reg     [15:0]  y_r_prod_s1_r;
    reg     [15:0]  y_g_prod_s1_r;
    reg     [15:0]  y_b_prod_s1_r;
    reg     [7:0]   y_s2_r;
    reg     [7:0]   y_s3_r;
    reg     [7:0]   y_s4_r;
    reg     [7:0]   tone_base_s3_r;
    reg     [7:0]   tone_diff_s3_r;
    reg     [5:0]   tone_slope_s3_r;
    reg             tone_shift4_s3_r;
    reg     [7:0]   tone_y_s4_r;
    reg signed [8:0] delta_s5_r;
    reg signed [9:0] out_r_s6_r;
    reg signed [9:0] out_g_s6_r;
    reg signed [9:0] out_b_s6_r;

    wire [15:0] y_sum_s2_w =
        y_r_prod_s1_r +
        y_g_prod_s1_r +
        y_b_prod_s1_r +
        16'd128;

    reg     [7:0] tone_base_w;
    reg     [7:0] tone_diff_w;
    reg     [5:0] tone_slope_w;
    reg           tone_shift4_w;

    always @* begin
        tone_base_w   = 8'd0;
        tone_diff_w   = y_s2_r;
        tone_slope_w  = 6'd1;
        tone_shift4_w = 1'b1;

        if (y_s2_r < 8'd16) begin
            tone_base_w   = 8'd20;
            tone_diff_w   = y_s2_r;
            tone_slope_w  = 6'd38;
            tone_shift4_w = 1'b1;
        end else if (y_s2_r < 8'd32) begin
            tone_base_w   = 8'd58;
            tone_diff_w   = y_s2_r - 8'd16;
            tone_slope_w  = 6'd21;
            tone_shift4_w = 1'b1;
        end else if (y_s2_r < 8'd64) begin
            tone_base_w   = 8'd79;
            tone_diff_w   = y_s2_r - 8'd32;
            tone_slope_w  = 6'd34;
            tone_shift4_w = 1'b0;
        end else if (y_s2_r < 8'd96) begin
            tone_base_w   = 8'd113;
            tone_diff_w   = y_s2_r - 8'd64;
            tone_slope_w  = 6'd29;
            tone_shift4_w = 1'b0;
        end else if (y_s2_r < 8'd128) begin
            tone_base_w   = 8'd142;
            tone_diff_w   = y_s2_r - 8'd96;
            tone_slope_w  = 6'd27;
            tone_shift4_w = 1'b0;
        end else if (y_s2_r < 8'd160) begin
            tone_base_w   = 8'd169;
            tone_diff_w   = y_s2_r - 8'd128;
            tone_slope_w  = 6'd23;
            tone_shift4_w = 1'b0;
        end else if (y_s2_r < 8'd192) begin
            tone_base_w   = 8'd192;
            tone_diff_w   = y_s2_r - 8'd160;
            tone_slope_w  = 6'd21;
            tone_shift4_w = 1'b0;
        end else if (y_s2_r < 8'd224) begin
            tone_base_w   = 8'd213;
            tone_diff_w   = y_s2_r - 8'd192;
            tone_slope_w  = 6'd19;
            tone_shift4_w = 1'b0;
        end else begin
            tone_base_w   = 8'd232;
            tone_diff_w   = y_s2_r - 8'd224;
            tone_slope_w  = 6'd16;
            tone_shift4_w = 1'b0;
        end
    end

    wire [15:0] tone_prod_w =
        {8'd0, tone_diff_s3_r} * {10'd0, tone_slope_s3_r};
    wire [15:0] tone_step_w =
        tone_shift4_s3_r ?
        ((tone_prod_w + 16'd8) >> 4) :
        ((tone_prod_w + 16'd16) >> 5);
    wire [15:0] tone_mapped_w = {8'd0, tone_base_s3_r} + tone_step_w;

    wire signed [8:0] tone_delta_s4_w =
        $signed({1'b0, tone_y_s4_r}) - $signed({1'b0, y_s4_r});
    wire signed [17:0] tone_delta_ext_s4_w =
        {{9{tone_delta_s4_w[8]}}, tone_delta_s4_w};
    wire signed [17:0] profile2_delta_prod_s5_w =
        tone_delta_ext_s4_w * 18'sd192;
    wire signed [8:0] profile2_delta_s5_w =
        $signed((profile2_delta_prod_s5_w + 18'sd128) >>> 8);
    wire signed [9:0] delta_ext_w = $signed({delta_s5_r[8], delta_s5_r});

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            de_s1_r          <= 1'b0;
            de_s2_r          <= 1'b0;
            de_s3_r          <= 1'b0;
            de_s4_r          <= 1'b0;
            de_s5_r          <= 1'b0;
            de_s6_r          <= 1'b0;
            rgb_s1_r         <= 24'd0;
            rgb_s2_r         <= 24'd0;
            rgb_s3_r         <= 24'd0;
            rgb_s4_r         <= 24'd0;
            rgb_s5_r         <= 24'd0;
            rgb_s6_r         <= 24'd0;
            y_r_prod_s1_r    <= 16'd0;
            y_g_prod_s1_r    <= 16'd0;
            y_b_prod_s1_r    <= 16'd0;
            y_s2_r           <= 8'd0;
            y_s3_r           <= 8'd0;
            y_s4_r           <= 8'd0;
            tone_base_s3_r   <= 8'd0;
            tone_diff_s3_r   <= 8'd0;
            tone_slope_s3_r  <= 6'd0;
            tone_shift4_s3_r <= 1'b0;
            tone_y_s4_r      <= 8'd0;
            delta_s5_r       <= 9'sd0;
            out_r_s6_r       <= 10'sd0;
            out_g_s6_r       <= 10'sd0;
            out_b_s6_r       <= 10'sd0;
            out_de           <= 1'b0;
            out_rgb          <= 24'd0;
        end else begin
            de_s1_r       <= in_de;
            rgb_s1_r      <= in_de ? in_rgb : 24'd0;
            y_r_prod_s1_r <= in_r_w * 8'd77;
            y_g_prod_s1_r <= in_g_w * 8'd150;
            y_b_prod_s1_r <= in_b_w * 8'd29;

            de_s2_r  <= de_s1_r;
            rgb_s2_r <= rgb_s1_r;
            y_s2_r   <= y_sum_s2_w[15:8];

            de_s3_r          <= de_s2_r;
            rgb_s3_r         <= rgb_s2_r;
            y_s3_r           <= y_s2_r;
            tone_base_s3_r   <= tone_base_w;
            tone_diff_s3_r   <= tone_diff_w;
            tone_slope_s3_r  <= tone_slope_w;
            tone_shift4_s3_r <= tone_shift4_w;

            de_s4_r     <= de_s3_r;
            rgb_s4_r    <= rgb_s3_r;
            y_s4_r      <= y_s3_r;
            tone_y_s4_r <= ((PROFILE == 4'd1) || (PROFILE == 4'd2)) ? tone_mapped_w[7:0] : y_s3_r;

            de_s5_r    <= de_s4_r;
            rgb_s5_r   <= rgb_s4_r;
            if (PROFILE == 4'd1)
                delta_s5_r <= tone_delta_s4_w;
            else if (PROFILE == 4'd2)
                delta_s5_r <= profile2_delta_s5_w;
            else
                delta_s5_r <= 9'sd0;

            de_s6_r    <= de_s5_r;
            rgb_s6_r   <= rgb_s5_r;
            out_r_s6_r <= $signed({2'b00, rgb_s5_r[23:16]}) + delta_ext_w;
            out_g_s6_r <= $signed({2'b00, rgb_s5_r[15:8]}) + delta_ext_w;
            out_b_s6_r <= $signed({2'b00, rgb_s5_r[7:0]}) + delta_ext_w;

            out_de <= de_s6_r;

            if (de_s6_r) begin
                if (ENABLE != 0) begin
                    out_rgb <= {
                        clip_u8(out_r_s6_r),
                        clip_u8(out_g_s6_r),
                        clip_u8(out_b_s6_r)
                    };
                end else begin
                    out_rgb <= rgb_s6_r;
                end
            end else begin
                out_rgb <= 24'd0;
            end
        end
    end

endmodule
