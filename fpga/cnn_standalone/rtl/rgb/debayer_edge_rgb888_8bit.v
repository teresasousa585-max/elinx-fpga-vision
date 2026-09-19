// 5x5 MHC-style Bayer demosaic with RGB888 output.
// The 5x5 window uses causal top/left clamping so the internal image quality
// improves while border pixels are handled by the downstream unsafe-halo mask.

module debayer_edge_rgb888_8bit
#(
    parameter H_DISP     = 1280,
    parameter V_DISP     = 720,
    parameter BAYER_MODE = 0
)
(
    input   wire            clk,
    input   wire            rst_n,
    input   wire            frame_clr,
    input   wire            din_vld,
    input   wire    [7:0]   din,
    input   wire            row_even,
    input   wire            col_even,

    output  reg             rgb_vld,
    output  reg     [23:0]  rgb888
);

    function [7:0] clip_div16_signed;
        input signed [15:0] value;
        reg   signed [15:0] rounded;
        begin
            rounded = (value >= 16'sd0) ? (value + 16'sd8) : (value - 16'sd8);
            rounded = rounded >>> 4;
            if (rounded < 16'sd0)
                clip_div16_signed = 8'd0;
            else if (rounded > 16'sd255)
                clip_div16_signed = 8'd255;
            else
                clip_div16_signed = rounded[7:0];
        end
    endfunction

    wire       win_vld_w;
    wire [7:0] m00_w;
    wire [7:0] m01_w;
    wire [7:0] m02_w;
    wire [7:0] m03_w;
    wire [7:0] m04_w;
    wire [7:0] m10_w;
    wire [7:0] m11_w;
    wire [7:0] m12_w;
    wire [7:0] m13_w;
    wire [7:0] m14_w;
    wire [7:0] m20_w;
    wire [7:0] m21_w;
    wire [7:0] m22_w;
    wire [7:0] m23_w;
    wire [7:0] m24_w;
    wire [7:0] m30_w;
    wire [7:0] m31_w;
    wire [7:0] m32_w;
    wire [7:0] m33_w;
    wire [7:0] m34_w;
    wire [7:0] m40_w;
    wire [7:0] m41_w;
    wire [7:0] m42_w;
    wire [7:0] m43_w;
    wire [7:0] m44_w;

    reg row_even_d1_r;
    reg row_even_d2_r;
    reg row_even_d3_r;
    reg row_even_d4_r;
    reg col_even_d1_r;
    reg col_even_d2_r;
    reg col_even_d3_r;
    reg col_even_d4_r;

    reg        feat_vld_s1_r;
    reg        row_even_s1_r;
    reg        col_even_s1_r;
    reg  [7:0] center_s1_r;
    reg  [9:0] cross4_s1_r;
    reg  [9:0] outer4_s1_r;
    reg  [8:0] lr2_s1_r;
    reg  [8:0] ud2_s1_r;
    reg  [9:0] diag4_s1_r;
    reg [10:0] hneg6_s1_r;
    reg [10:0] vneg6_s1_r;
    reg  [8:0] tb2_s1_r;
    reg  [8:0] midlr2_s1_r;

    reg        feat_vld_s2_r;
    reg        row_even_s2_r;
    reg        col_even_s2_r;
    reg  [7:0] center_s2_r;
    reg  [7:0] g_at_rb_s2_r;
    reg  [7:0] h_at_g_s2_r;
    reg  [7:0] v_at_g_s2_r;
    reg  [7:0] diag_at_rb_s2_r;

    reg  [7:0] out_r_r;
    reg  [7:0] out_g_r;
    reg  [7:0] out_b_r;

    wire signed [15:0] g_num_s1_w =
        $signed({5'd0, center_s1_r, 3'b000}) +
        $signed({3'd0, cross4_s1_r, 2'b00}) -
        $signed({5'd0, outer4_s1_r, 1'b0});
    // Green-site horizontal/vertical recon follows the MHC /16 kernel:
    // 10*center + 8*adjacent + 1*far - 2*diagonal-side.
    wire signed [15:0] h_num_s1_w =
        $signed({2'd0, center_s1_r, 3'b000}) + $signed({5'd0, center_s1_r, 1'b0}) +
        $signed({3'd0, lr2_s1_r, 3'b000}) +
        $signed({7'd0, tb2_s1_r}) -
        $signed({4'd0, hneg6_s1_r, 1'b0});
    wire signed [15:0] v_num_s1_w =
        $signed({2'd0, center_s1_r, 3'b000}) + $signed({5'd0, center_s1_r, 1'b0}) +
        $signed({3'd0, ud2_s1_r, 3'b000}) +
        $signed({7'd0, midlr2_s1_r}) -
        $signed({4'd0, vneg6_s1_r, 1'b0});
    wire signed [15:0] diag_num_s1_w =
        $signed({3'd0, center_s1_r, 2'b00}) + $signed({4'd0, center_s1_r, 3'b000}) +
        $signed({4'd0, diag4_s1_r, 2'b00}) -
        $signed({6'd0, outer4_s1_r}) -
        $signed({5'd0, outer4_s1_r, 1'b0});

    stream_plane_window5x5
    #(
        .H_DISP (H_DISP),
        .V_DISP (V_DISP)
    )
    u_window
    (
        .clk      (clk),
        .rst_n    (rst_n),
        .frame_clr(frame_clr),
        .din_vld  (din_vld),
        .din      (din),
        .out_vld  (win_vld_w),
        .m00      (m00_w), .m01(m01_w), .m02(m02_w), .m03(m03_w), .m04(m04_w),
        .m10      (m10_w), .m11(m11_w), .m12(m12_w), .m13(m13_w), .m14(m14_w),
        .m20      (m20_w), .m21(m21_w), .m22(m22_w), .m23(m23_w), .m24(m24_w),
        .m30      (m30_w), .m31(m31_w), .m32(m32_w), .m33(m33_w), .m34(m34_w),
        .m40      (m40_w), .m41(m41_w), .m42(m42_w), .m43(m43_w), .m44(m44_w)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            row_even_d1_r <= 1'b0;
            row_even_d2_r <= 1'b0;
            row_even_d3_r <= 1'b0;
            row_even_d4_r <= 1'b0;
            col_even_d1_r <= 1'b0;
            col_even_d2_r <= 1'b0;
            col_even_d3_r <= 1'b0;
            col_even_d4_r <= 1'b0;
            feat_vld_s1_r <= 1'b0;
            row_even_s1_r <= 1'b0;
            col_even_s1_r <= 1'b0;
            center_s1_r <= 8'd0;
            cross4_s1_r <= 10'd0;
            outer4_s1_r <= 10'd0;
            lr2_s1_r <= 9'd0;
            ud2_s1_r <= 9'd0;
            diag4_s1_r <= 10'd0;
            hneg6_s1_r <= 11'd0;
            vneg6_s1_r <= 11'd0;
            tb2_s1_r <= 9'd0;
            midlr2_s1_r <= 9'd0;
            feat_vld_s2_r <= 1'b0;
            row_even_s2_r <= 1'b0;
            col_even_s2_r <= 1'b0;
            center_s2_r <= 8'd0;
            g_at_rb_s2_r <= 8'd0;
            h_at_g_s2_r <= 8'd0;
            v_at_g_s2_r <= 8'd0;
            diag_at_rb_s2_r <= 8'd0;
            rgb_vld <= 1'b0;
            rgb888 <= 24'd0;
        end else if (frame_clr) begin
            row_even_d1_r <= 1'b0;
            row_even_d2_r <= 1'b0;
            row_even_d3_r <= 1'b0;
            row_even_d4_r <= 1'b0;
            col_even_d1_r <= 1'b0;
            col_even_d2_r <= 1'b0;
            col_even_d3_r <= 1'b0;
            col_even_d4_r <= 1'b0;
            feat_vld_s1_r <= 1'b0;
            row_even_s1_r <= 1'b0;
            col_even_s1_r <= 1'b0;
            center_s1_r <= 8'd0;
            cross4_s1_r <= 10'd0;
            outer4_s1_r <= 10'd0;
            lr2_s1_r <= 9'd0;
            ud2_s1_r <= 9'd0;
            diag4_s1_r <= 10'd0;
            hneg6_s1_r <= 11'd0;
            vneg6_s1_r <= 11'd0;
            tb2_s1_r <= 9'd0;
            midlr2_s1_r <= 9'd0;
            feat_vld_s2_r <= 1'b0;
            row_even_s2_r <= 1'b0;
            col_even_s2_r <= 1'b0;
            center_s2_r <= 8'd0;
            g_at_rb_s2_r <= 8'd0;
            h_at_g_s2_r <= 8'd0;
            v_at_g_s2_r <= 8'd0;
            diag_at_rb_s2_r <= 8'd0;
            rgb_vld <= 1'b0;
            rgb888 <= 24'd0;
        end else begin
            row_even_d1_r <= row_even;
            row_even_d2_r <= row_even_d1_r;
            row_even_d3_r <= row_even_d2_r;
            row_even_d4_r <= row_even_d3_r;
            col_even_d1_r <= col_even;
            col_even_d2_r <= col_even_d1_r;
            col_even_d3_r <= col_even_d2_r;
            col_even_d4_r <= col_even_d3_r;

            feat_vld_s1_r <= win_vld_w;
            if (win_vld_w) begin
                row_even_s1_r <= row_even_d4_r;
                col_even_s1_r <= col_even_d4_r;
                center_s1_r <= m22_w;
                cross4_s1_r <= {2'd0, m12_w} + {2'd0, m21_w} + {2'd0, m23_w} + {2'd0, m32_w};
                outer4_s1_r <= {2'd0, m02_w} + {2'd0, m20_w} + {2'd0, m24_w} + {2'd0, m42_w};
                lr2_s1_r <= {1'd0, m21_w} + {1'd0, m23_w};
                ud2_s1_r <= {1'd0, m12_w} + {1'd0, m32_w};
                diag4_s1_r <= {2'd0, m11_w} + {2'd0, m13_w} + {2'd0, m31_w} + {2'd0, m33_w};
                hneg6_s1_r <= {3'd0, m11_w} + {3'd0, m13_w} + {3'd0, m20_w} + {3'd0, m24_w} + {3'd0, m31_w} + {3'd0, m33_w};
                vneg6_s1_r <= {3'd0, m01_w} + {3'd0, m03_w} + {3'd0, m11_w} + {3'd0, m13_w} + {3'd0, m31_w} + {3'd0, m33_w};
                tb2_s1_r <= {1'd0, m02_w} + {1'd0, m42_w};
                midlr2_s1_r <= {1'd0, m20_w} + {1'd0, m24_w};
            end else begin
                row_even_s1_r <= 1'b0;
                col_even_s1_r <= 1'b0;
                center_s1_r <= 8'd0;
                cross4_s1_r <= 10'd0;
                outer4_s1_r <= 10'd0;
                lr2_s1_r <= 9'd0;
                ud2_s1_r <= 9'd0;
                diag4_s1_r <= 10'd0;
                hneg6_s1_r <= 11'd0;
                vneg6_s1_r <= 11'd0;
                tb2_s1_r <= 9'd0;
                midlr2_s1_r <= 9'd0;
            end

            feat_vld_s2_r <= feat_vld_s1_r;
            if (feat_vld_s1_r) begin
                row_even_s2_r <= row_even_s1_r;
                col_even_s2_r <= col_even_s1_r;
                center_s2_r <= center_s1_r;
                g_at_rb_s2_r <= clip_div16_signed(g_num_s1_w);
                h_at_g_s2_r <= clip_div16_signed(h_num_s1_w);
                v_at_g_s2_r <= clip_div16_signed(v_num_s1_w);
                diag_at_rb_s2_r <= clip_div16_signed(diag_num_s1_w);
            end else begin
                row_even_s2_r <= 1'b0;
                col_even_s2_r <= 1'b0;
                center_s2_r <= 8'd0;
                g_at_rb_s2_r <= 8'd0;
                h_at_g_s2_r <= 8'd0;
                v_at_g_s2_r <= 8'd0;
                diag_at_rb_s2_r <= 8'd0;
            end

            rgb_vld <= feat_vld_s2_r;
            if (feat_vld_s2_r) begin
                out_r_r = center_s2_r;
                out_g_r = center_s2_r;
                out_b_r = center_s2_r;

                case (BAYER_MODE)
                    0: begin
                        if (row_even_s2_r && col_even_s2_r) begin
                            out_r_r = diag_at_rb_s2_r;
                            out_g_r = g_at_rb_s2_r;
                            out_b_r = center_s2_r;
                        end else if (row_even_s2_r && !col_even_s2_r) begin
                            out_r_r = v_at_g_s2_r;
                            out_g_r = center_s2_r;
                            out_b_r = h_at_g_s2_r;
                        end else if (!row_even_s2_r && col_even_s2_r) begin
                            out_r_r = h_at_g_s2_r;
                            out_g_r = center_s2_r;
                            out_b_r = v_at_g_s2_r;
                        end else begin
                            out_r_r = center_s2_r;
                            out_g_r = g_at_rb_s2_r;
                            out_b_r = diag_at_rb_s2_r;
                        end
                    end
                    1: begin
                        if (row_even_s2_r && col_even_s2_r) begin
                            out_r_r = center_s2_r;
                            out_g_r = g_at_rb_s2_r;
                            out_b_r = diag_at_rb_s2_r;
                        end else if (row_even_s2_r && !col_even_s2_r) begin
                            out_r_r = h_at_g_s2_r;
                            out_g_r = center_s2_r;
                            out_b_r = v_at_g_s2_r;
                        end else if (!row_even_s2_r && col_even_s2_r) begin
                            out_r_r = v_at_g_s2_r;
                            out_g_r = center_s2_r;
                            out_b_r = h_at_g_s2_r;
                        end else begin
                            out_r_r = diag_at_rb_s2_r;
                            out_g_r = g_at_rb_s2_r;
                            out_b_r = center_s2_r;
                        end
                    end
                    2: begin
                        if (row_even_s2_r && col_even_s2_r) begin
                            out_r_r = h_at_g_s2_r;
                            out_g_r = center_s2_r;
                            out_b_r = v_at_g_s2_r;
                        end else if (row_even_s2_r && !col_even_s2_r) begin
                            out_r_r = center_s2_r;
                            out_g_r = g_at_rb_s2_r;
                            out_b_r = diag_at_rb_s2_r;
                        end else if (!row_even_s2_r && col_even_s2_r) begin
                            out_r_r = diag_at_rb_s2_r;
                            out_g_r = g_at_rb_s2_r;
                            out_b_r = center_s2_r;
                        end else begin
                            out_r_r = v_at_g_s2_r;
                            out_g_r = center_s2_r;
                            out_b_r = h_at_g_s2_r;
                        end
                    end
                    default: begin
                        if (row_even_s2_r && col_even_s2_r) begin
                            out_r_r = v_at_g_s2_r;
                            out_g_r = center_s2_r;
                            out_b_r = h_at_g_s2_r;
                        end else if (row_even_s2_r && !col_even_s2_r) begin
                            out_r_r = diag_at_rb_s2_r;
                            out_g_r = g_at_rb_s2_r;
                            out_b_r = center_s2_r;
                        end else if (!row_even_s2_r && col_even_s2_r) begin
                            out_r_r = center_s2_r;
                            out_g_r = g_at_rb_s2_r;
                            out_b_r = diag_at_rb_s2_r;
                        end else begin
                            out_r_r = h_at_g_s2_r;
                            out_g_r = center_s2_r;
                            out_b_r = v_at_g_s2_r;
                        end
                    end
                endcase
                rgb888 <= {out_r_r, out_g_r, out_b_r};
            end else begin
                rgb888 <= 24'd0;
            end
        end
    end

endmodule
