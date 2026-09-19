`timescale 1ns/1ps

module rgb_gamma_lut
#(
    parameter ENABLE = 1,
    // 0: legacy per-channel gamma. 1: luma gamma plus common RGB delta.
    // 2: luma-delta for low-chroma pixels, per-channel gamma otherwise.
    parameter integer MODE = 1,
    parameter [7:0] LOW_CHROMA_TH = 8'd12
)
(
    input   wire            clk,
    input   wire            rst_n,
    input   wire            in_de,
    input   wire    [23:0]  in_rgb,

    output  reg             out_de,
    output  reg     [23:0]  out_rgb
);

    function [8:0] gamma_classify_u8;
        input [7:0] value;
        reg [7:0] delta;
        begin
            // Static-function temporaries need a total assignment for eLinx
            // synthesis even when the selected branch does not consume them.
            delta = 8'd0;
            if (value < 8'd32)
                gamma_classify_u8 = {3'd0, 1'b0, value[4:0]};
            else if (value < 8'd96) begin
                delta = value - 8'd32;
                gamma_classify_u8 = {3'd1, delta[5:0]};
            end else if (value < 8'd160) begin
                delta = value - 8'd96;
                gamma_classify_u8 = {3'd2, delta[5:0]};
            end else if (value < 8'd224) begin
                delta = value - 8'd160;
                gamma_classify_u8 = {3'd3, delta[5:0]};
            end else begin
                delta = value - 8'd224;
                gamma_classify_u8 = {3'd4, delta[5:0]};
            end
        end
    endfunction

    function [9:0] gamma_eval_u10;
        input [2:0] segment;
        input [5:0] delta;
        reg [9:0] delta_u10;
        begin
            delta_u10 = {4'd0, delta};
            case (segment)
                3'd0: gamma_eval_u10 = ((delta_u10 + (delta_u10 << 1)) + 10'd1) >> 1;
                3'd1: gamma_eval_u10 = 10'd48  + (((delta_u10 + (delta_u10 << 1)) + 10'd1) >> 1);
                3'd2: gamma_eval_u10 = 10'd144 + (((delta_u10 + (delta_u10 << 2)) + 10'd2) >> 2);
                3'd3: gamma_eval_u10 = 10'd224 + (((delta_u10 + (delta_u10 << 1)) + 10'd4) >> 3);
                default: gamma_eval_u10 = 10'd248 + ((delta_u10 + 10'd2) >> 2);
            endcase
        end
    endfunction

    function [7:0] clip_gamma_u8;
        input [9:0] value;
        begin
            if (value > 10'd255)
                clip_gamma_u8 = 8'hff;
            else
                clip_gamma_u8 = value[7:0];
        end
    endfunction

    function [7:0] clip_signed_u8;
        input signed [10:0] value;
        begin
            if (value < 11'sd0)
                clip_signed_u8 = 8'd0;
            else if (value > 11'sd255)
                clip_signed_u8 = 8'hff;
            else
                clip_signed_u8 = value[7:0];
        end
    endfunction

    reg        de_s0_r;
    reg        de_s1_r;
    reg        de_s2_r;
    reg [23:0] rgb_s0_r;
    reg [23:0] rgb_s1_r;
    reg [23:0] rgb_s2_r;
    reg [8:0]  r_class_s0_r;
    reg [8:0]  g_class_s0_r;
    reg [8:0]  b_class_s0_r;
    reg [8:0]  y_class_s0_r;
    reg [7:0]  y_s0_r;
    reg [9:0]  r_gamma_s1_r;
    reg [9:0]  g_gamma_s1_r;
    reg [9:0]  b_gamma_s1_r;
    reg [9:0]  r_gamma_s2_r;
    reg [9:0]  g_gamma_s2_r;
    reg [9:0]  b_gamma_s2_r;
    reg signed [10:0] delta_s1_r;
    reg [16:0] y_sum_s0_r;
    reg        low_chroma_s0_r;
    reg        low_chroma_s1_r;
    reg        low_chroma_s2_r;

    wire [15:0] r_y_part_w;
    wire [15:0] g_y_part_w;
    wire [14:0] b_y_part_w;
    wire [7:0]  in_r_w;
    wire [7:0]  in_g_w;
    wire [7:0]  in_b_w;
    wire [7:0]  rgb_max_rg_w;
    wire [7:0]  rgb_min_rg_w;
    wire [7:0]  rgb_max_w;
    wire [7:0]  rgb_min_w;
    wire [7:0]  rgb_chroma_w;

    assign in_r_w = in_rgb[23:16];
    assign in_g_w = in_rgb[15:8];
    assign in_b_w = in_rgb[7:0];
    assign rgb_max_rg_w = (in_r_w >= in_g_w) ? in_r_w : in_g_w;
    assign rgb_min_rg_w = (in_r_w <= in_g_w) ? in_r_w : in_g_w;
    assign rgb_max_w = (rgb_max_rg_w >= in_b_w) ? rgb_max_rg_w : in_b_w;
    assign rgb_min_w = (rgb_min_rg_w <= in_b_w) ? rgb_min_rg_w : in_b_w;
    assign rgb_chroma_w = rgb_max_w - rgb_min_w;

    assign r_y_part_w = ({8'd0, in_r_w} << 6)
                      + ({8'd0, in_r_w} << 3)
                      + ({8'd0, in_r_w} << 2)
                      + {8'd0, in_r_w};
    assign g_y_part_w = ({8'd0, in_g_w} << 7)
                      + ({8'd0, in_g_w} << 4)
                      + ({8'd0, in_g_w} << 2)
                      + ({8'd0, in_g_w} << 1);
    assign b_y_part_w = ({7'd0, in_b_w} << 4)
                      + ({7'd0, in_b_w} << 3)
                      + ({7'd0, in_b_w} << 2)
                      + {7'd0, in_b_w};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            de_s0_r <= 1'b0;
            de_s1_r <= 1'b0;
            de_s2_r <= 1'b0;
            rgb_s0_r <= 24'd0;
            rgb_s1_r <= 24'd0;
            rgb_s2_r <= 24'd0;
            r_class_s0_r <= 9'd0;
            g_class_s0_r <= 9'd0;
            b_class_s0_r <= 9'd0;
            y_class_s0_r <= 9'd0;
            y_s0_r <= 8'd0;
            r_gamma_s1_r <= 10'd0;
            g_gamma_s1_r <= 10'd0;
            b_gamma_s1_r <= 10'd0;
            r_gamma_s2_r <= 10'd0;
            g_gamma_s2_r <= 10'd0;
            b_gamma_s2_r <= 10'd0;
            delta_s1_r <= 11'sd0;
            y_sum_s0_r <= 17'd0;
            low_chroma_s0_r <= 1'b0;
            low_chroma_s1_r <= 1'b0;
            low_chroma_s2_r <= 1'b0;
            out_de  <= 1'b0;
            out_rgb <= 24'd0;
        end else begin
            de_s0_r <= in_de;
            rgb_s0_r <= in_de ? in_rgb : 24'd0;
            if (in_de) begin
                r_class_s0_r <= gamma_classify_u8(in_rgb[23:16]);
                g_class_s0_r <= gamma_classify_u8(in_rgb[15:8]);
                b_class_s0_r <= gamma_classify_u8(in_rgb[7:0]);
                y_sum_s0_r <= {1'b0, r_y_part_w} + {1'b0, g_y_part_w} + {2'b00, b_y_part_w} + 17'd128;
                low_chroma_s0_r <= (rgb_chroma_w <= LOW_CHROMA_TH);
            end else begin
                r_class_s0_r <= 9'd0;
                g_class_s0_r <= 9'd0;
                b_class_s0_r <= 9'd0;
                y_sum_s0_r <= 17'd0;
                low_chroma_s0_r <= 1'b0;
            end

            de_s1_r <= de_s0_r;
            rgb_s1_r <= de_s0_r ? rgb_s0_r : 24'd0;
            low_chroma_s1_r <= de_s0_r ? low_chroma_s0_r : 1'b0;
            if (de_s0_r) begin
                r_gamma_s1_r <= gamma_eval_u10(r_class_s0_r[8:6], r_class_s0_r[5:0]);
                g_gamma_s1_r <= gamma_eval_u10(g_class_s0_r[8:6], g_class_s0_r[5:0]);
                b_gamma_s1_r <= gamma_eval_u10(b_class_s0_r[8:6], b_class_s0_r[5:0]);
                y_s0_r <= y_sum_s0_r[15:8];
                y_class_s0_r <= gamma_classify_u8(y_sum_s0_r[15:8]);
            end else begin
                r_gamma_s1_r <= 10'd0;
                g_gamma_s1_r <= 10'd0;
                b_gamma_s1_r <= 10'd0;
                y_s0_r <= 8'd0;
                y_class_s0_r <= 9'd0;
            end

            de_s2_r <= de_s1_r;
            rgb_s2_r <= de_s1_r ? rgb_s1_r : 24'd0;
            low_chroma_s2_r <= de_s1_r ? low_chroma_s1_r : 1'b0;
            if (de_s1_r) begin
                r_gamma_s2_r <= r_gamma_s1_r;
                g_gamma_s2_r <= g_gamma_s1_r;
                b_gamma_s2_r <= b_gamma_s1_r;
                delta_s1_r <= $signed({3'd0, clip_gamma_u8(gamma_eval_u10(y_class_s0_r[8:6], y_class_s0_r[5:0]))})
                            - $signed({3'd0, y_s0_r});
            end else begin
                r_gamma_s2_r <= 10'd0;
                g_gamma_s2_r <= 10'd0;
                b_gamma_s2_r <= 10'd0;
                delta_s1_r <= 11'sd0;
            end

            out_de <= de_s2_r;
            if (de_s2_r) begin
                if (ENABLE != 0 && MODE == 0)
                    out_rgb <= {clip_gamma_u8(r_gamma_s2_r),
                                clip_gamma_u8(g_gamma_s2_r),
                                clip_gamma_u8(b_gamma_s2_r)};
                else if (ENABLE != 0 && (MODE == 1 || (MODE == 2 && low_chroma_s2_r)))
                    out_rgb <= {clip_signed_u8($signed({3'd0, rgb_s2_r[23:16]}) + delta_s1_r),
                                clip_signed_u8($signed({3'd0, rgb_s2_r[15:8]}) + delta_s1_r),
                                clip_signed_u8($signed({3'd0, rgb_s2_r[7:0]}) + delta_s1_r)};
                else if (ENABLE != 0)
                    out_rgb <= {clip_gamma_u8(r_gamma_s2_r),
                                clip_gamma_u8(g_gamma_s2_r),
                                clip_gamma_u8(b_gamma_s2_r)};
                else
                    out_rgb <= rgb_s2_r;
            end else begin
                out_rgb <= 24'd0;
            end
        end
    end

endmodule
