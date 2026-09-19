module stream_plane_cross5_5x5
#(
    parameter H_DISP = 1280,
    parameter V_DISP = 720,
    parameter [1:0] TARGET_MODE = 2'd0
)
(
    input   wire            clk,
    input   wire            rst_n,
    input   wire            frame_clr,
    input   wire            din_vld,
    input   wire    [7:0]   din,

    output  reg             out_vld,
    output  reg     [7:0]   out_center,
    output  reg     [7:0]   out_target,
    output  reg     [7:0]   out_blur
);

    function [7:0] median5_u8;
        input [7:0] in0;
        input [7:0] in1;
        input [7:0] in2;
        input [7:0] in3;
        input [7:0] in4;
        reg   [7:0] a0;
        reg   [7:0] a1;
        reg   [7:0] a2;
        reg   [7:0] a3;
        reg   [7:0] a4;
        reg   [7:0] t;
        begin
            // t is consumed only inside a swap, but assigning it on every
            // function path prevents an inferred-latch ambiguity in eLinx.
            t = 8'd0;
            a0 = in0;
            a1 = in1;
            a2 = in2;
            a3 = in3;
            a4 = in4;
            if (a0 > a1) begin t = a0; a0 = a1; a1 = t; end
            if (a3 > a4) begin t = a3; a3 = a4; a4 = t; end
            if (a0 > a3) begin t = a0; a0 = a3; a3 = t; end
            if (a1 > a4) begin t = a1; a1 = a4; a4 = t; end
            if (a1 > a2) begin t = a1; a1 = a2; a2 = t; end
            if (a2 > a3) begin t = a2; a2 = a3; a3 = t; end
            if (a1 > a2) begin t = a1; a1 = a2; a2 = t; end
            median5_u8 = a2;
        end
    endfunction

    function [12:0] row5_weighted;
        input [7:0] a0;
        input [7:0] a1;
        input [7:0] a2;
        input [7:0] a3;
        input [7:0] a4;
        begin
            row5_weighted =
                {5'd0, a0} +
                {3'd0, a1, 2'b00} +
                {2'd0, a2, 2'b00} + {3'd0, a2, 1'b0} +
                {3'd0, a3, 2'b00} +
                {5'd0, a4};
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

    reg        feat_vld_s1_r;
    reg  [7:0] center_s1_r;
    reg  [7:0] p00_s1_r;
    reg  [7:0] p01_s1_r;
    reg  [7:0] p02_s1_r;
    reg  [7:0] p03_s1_r;
    reg  [7:0] p04_s1_r;
    reg  [7:0] p10_s1_r;
    reg  [7:0] p11_s1_r;
    reg  [7:0] p12_s1_r;
    reg  [7:0] p13_s1_r;
    reg  [7:0] p14_s1_r;
    reg  [7:0] p20_s1_r;
    reg  [7:0] p21_s1_r;
    reg  [7:0] p22_s1_r;
    reg  [7:0] p23_s1_r;
    reg  [7:0] p24_s1_r;
    reg  [7:0] p30_s1_r;
    reg  [7:0] p31_s1_r;
    reg  [7:0] p32_s1_r;
    reg  [7:0] p33_s1_r;
    reg  [7:0] p34_s1_r;
    reg  [7:0] p40_s1_r;
    reg  [7:0] p41_s1_r;
    reg  [7:0] p42_s1_r;
    reg  [7:0] p43_s1_r;
    reg  [7:0] p44_s1_r;

    reg        feat_vld_s2_r;
    reg  [7:0] center_s2_r;
    reg  [7:0] median_s2_r;
    reg  [7:0] cross_lp_s2_r;
    reg [12:0] row0_s2_r;
    reg [12:0] row1_s2_r;
    reg [12:0] row2_s2_r;
    reg [12:0] row3_s2_r;
    reg [12:0] row4_s2_r;

    wire [13:0] cross_sum_s1_w =
        {3'd0, p22_s1_r, 3'b000} +
        {4'd0, p22_s1_r, 2'b00} +
        {4'd0, p12_s1_r, 2'b00} +
        {4'd0, p21_s1_r, 2'b00} +
        {4'd0, p23_s1_r, 2'b00} +
        {4'd0, p32_s1_r, 2'b00} +
        {6'd0, p02_s1_r} +
        {6'd0, p20_s1_r} +
        {6'd0, p24_s1_r} +
        {6'd0, p42_s1_r};
    wire [7:0] cross_lp_s1_w = (cross_sum_s1_w + 14'd16) >> 5;
    wire [15:0] blur_sum_w =
        {3'd0, row0_s2_r} +
        {1'd0, row1_s2_r, 2'b00} +
        {row2_s2_r, 2'b00} + {1'd0, row2_s2_r, 1'b0} +
        {1'd0, row3_s2_r, 2'b00} +
        {3'd0, row4_s2_r};
    wire [7:0] blur_px_w = (blur_sum_w + 16'd128) >> 8;
    wire [8:0] target_avg_w = {1'b0, median_s2_r} + {1'b0, cross_lp_s2_r} + 9'd1;
    wire [12:0] target_weighted_w =
        {1'b0, median_s2_r, 4'b0000} +
        {2'b00, median_s2_r, 3'b000} +
        {4'b0000, median_s2_r} +
        {4'b0000, cross_lp_s2_r, 2'b00} +
        {5'b00000, cross_lp_s2_r, 1'b0} +
        {5'b00000, cross_lp_s2_r};
    wire [7:0] target_weighted_px_w = (target_weighted_w + 13'd16) >> 5;
    wire [7:0] target_px_w =
        (TARGET_MODE == 2'd1) ? target_avg_w[8:1] :
        ((TARGET_MODE == 2'd2) ? median_s2_r :
        ((TARGET_MODE == 2'd3) ? target_weighted_px_w : cross_lp_s2_r));

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
            feat_vld_s1_r <= 1'b0;
            center_s1_r <= 8'd0;
            p00_s1_r <= 8'd0; p01_s1_r <= 8'd0; p02_s1_r <= 8'd0; p03_s1_r <= 8'd0; p04_s1_r <= 8'd0;
            p10_s1_r <= 8'd0; p11_s1_r <= 8'd0; p12_s1_r <= 8'd0; p13_s1_r <= 8'd0; p14_s1_r <= 8'd0;
            p20_s1_r <= 8'd0; p21_s1_r <= 8'd0; p22_s1_r <= 8'd0; p23_s1_r <= 8'd0; p24_s1_r <= 8'd0;
            p30_s1_r <= 8'd0; p31_s1_r <= 8'd0; p32_s1_r <= 8'd0; p33_s1_r <= 8'd0; p34_s1_r <= 8'd0;
            p40_s1_r <= 8'd0; p41_s1_r <= 8'd0; p42_s1_r <= 8'd0; p43_s1_r <= 8'd0; p44_s1_r <= 8'd0;
            feat_vld_s2_r <= 1'b0;
            center_s2_r <= 8'd0;
            median_s2_r <= 8'd0;
            cross_lp_s2_r <= 8'd0;
            row0_s2_r <= 13'd0;
            row1_s2_r <= 13'd0;
            row2_s2_r <= 13'd0;
            row3_s2_r <= 13'd0;
            row4_s2_r <= 13'd0;
            out_vld <= 1'b0;
            out_center <= 8'd0;
            out_target <= 8'd0;
            out_blur <= 8'd0;
        end else if (frame_clr) begin
            feat_vld_s1_r <= 1'b0;
            center_s1_r <= 8'd0;
            p00_s1_r <= 8'd0; p01_s1_r <= 8'd0; p02_s1_r <= 8'd0; p03_s1_r <= 8'd0; p04_s1_r <= 8'd0;
            p10_s1_r <= 8'd0; p11_s1_r <= 8'd0; p12_s1_r <= 8'd0; p13_s1_r <= 8'd0; p14_s1_r <= 8'd0;
            p20_s1_r <= 8'd0; p21_s1_r <= 8'd0; p22_s1_r <= 8'd0; p23_s1_r <= 8'd0; p24_s1_r <= 8'd0;
            p30_s1_r <= 8'd0; p31_s1_r <= 8'd0; p32_s1_r <= 8'd0; p33_s1_r <= 8'd0; p34_s1_r <= 8'd0;
            p40_s1_r <= 8'd0; p41_s1_r <= 8'd0; p42_s1_r <= 8'd0; p43_s1_r <= 8'd0; p44_s1_r <= 8'd0;
            feat_vld_s2_r <= 1'b0;
            center_s2_r <= 8'd0;
            median_s2_r <= 8'd0;
            cross_lp_s2_r <= 8'd0;
            row0_s2_r <= 13'd0;
            row1_s2_r <= 13'd0;
            row2_s2_r <= 13'd0;
            row3_s2_r <= 13'd0;
            row4_s2_r <= 13'd0;
            out_vld <= 1'b0;
            out_center <= 8'd0;
            out_target <= 8'd0;
            out_blur <= 8'd0;
        end else begin
            feat_vld_s1_r <= win_vld_w;
            if (win_vld_w) begin
                center_s1_r <= m22_w;
                p00_s1_r <= m00_w; p01_s1_r <= m01_w; p02_s1_r <= m02_w; p03_s1_r <= m03_w; p04_s1_r <= m04_w;
                p10_s1_r <= m10_w; p11_s1_r <= m11_w; p12_s1_r <= m12_w; p13_s1_r <= m13_w; p14_s1_r <= m14_w;
                p20_s1_r <= m20_w; p21_s1_r <= m21_w; p22_s1_r <= m22_w; p23_s1_r <= m23_w; p24_s1_r <= m24_w;
                p30_s1_r <= m30_w; p31_s1_r <= m31_w; p32_s1_r <= m32_w; p33_s1_r <= m33_w; p34_s1_r <= m34_w;
                p40_s1_r <= m40_w; p41_s1_r <= m41_w; p42_s1_r <= m42_w; p43_s1_r <= m43_w; p44_s1_r <= m44_w;
            end else begin
                center_s1_r <= 8'd0;
                p00_s1_r <= 8'd0; p01_s1_r <= 8'd0; p02_s1_r <= 8'd0; p03_s1_r <= 8'd0; p04_s1_r <= 8'd0;
                p10_s1_r <= 8'd0; p11_s1_r <= 8'd0; p12_s1_r <= 8'd0; p13_s1_r <= 8'd0; p14_s1_r <= 8'd0;
                p20_s1_r <= 8'd0; p21_s1_r <= 8'd0; p22_s1_r <= 8'd0; p23_s1_r <= 8'd0; p24_s1_r <= 8'd0;
                p30_s1_r <= 8'd0; p31_s1_r <= 8'd0; p32_s1_r <= 8'd0; p33_s1_r <= 8'd0; p34_s1_r <= 8'd0;
                p40_s1_r <= 8'd0; p41_s1_r <= 8'd0; p42_s1_r <= 8'd0; p43_s1_r <= 8'd0; p44_s1_r <= 8'd0;
            end

            feat_vld_s2_r <= feat_vld_s1_r;
            if (feat_vld_s1_r) begin
                center_s2_r <= center_s1_r;
                median_s2_r <= median5_u8(p22_s1_r, p12_s1_r, p21_s1_r, p23_s1_r, p32_s1_r);
                cross_lp_s2_r <= cross_lp_s1_w;
                row0_s2_r <= row5_weighted(p00_s1_r, p01_s1_r, p02_s1_r, p03_s1_r, p04_s1_r);
                row1_s2_r <= row5_weighted(p10_s1_r, p11_s1_r, p12_s1_r, p13_s1_r, p14_s1_r);
                row2_s2_r <= row5_weighted(p20_s1_r, p21_s1_r, p22_s1_r, p23_s1_r, p24_s1_r);
                row3_s2_r <= row5_weighted(p30_s1_r, p31_s1_r, p32_s1_r, p33_s1_r, p34_s1_r);
                row4_s2_r <= row5_weighted(p40_s1_r, p41_s1_r, p42_s1_r, p43_s1_r, p44_s1_r);
            end else begin
                center_s2_r <= 8'd0;
                median_s2_r <= 8'd0;
                cross_lp_s2_r <= 8'd0;
                row0_s2_r <= 13'd0;
                row1_s2_r <= 13'd0;
                row2_s2_r <= 13'd0;
                row3_s2_r <= 13'd0;
                row4_s2_r <= 13'd0;
            end

            out_vld <= feat_vld_s2_r;
            if (feat_vld_s2_r) begin
                out_center <= center_s2_r;
                out_target <= target_px_w;
                out_blur <= blur_px_w;
            end else begin
                out_center <= 8'd0;
                out_target <= 8'd0;
                out_blur <= 8'd0;
            end
        end
    end

endmodule
