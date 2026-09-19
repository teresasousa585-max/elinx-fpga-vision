module stream_plane_bilateral_5x5
#(
    parameter H_DISP = 1280,
    parameter V_DISP = 720,
    parameter ENABLE = 1,
    parameter [7:0] RANGE_TH = 8'd32
)
(
    input   wire            clk,
    input   wire            rst_n,
    input   wire            frame_clr,
    input   wire            din_vld,
    input   wire    [7:0]   din,

    output  reg             out_vld,
    output  reg     [7:0]   out_center,
    output  reg     [7:0]   out_filtered
);

    function [7:0] abs_diff;
        input [7:0] a;
        input [7:0] b;
        begin
            abs_diff = (a >= b) ? (a - b) : (b - a);
        end
    endfunction

    function [7:0] range_pick;
        input [7:0] neighbor;
        input [7:0] center;
        begin
            range_pick = (abs_diff(neighbor, center) <= RANGE_TH) ? neighbor : center;
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
    reg [12:0] row0_s2_r;
    reg [12:0] row1_s2_r;
    reg [12:0] row2_s2_r;
    reg [12:0] row3_s2_r;
    reg [12:0] row4_s2_r;

    reg        feat_vld_s3_r;
    reg  [7:0] center_s3_r;
    reg [15:0] row01_s3_r;
    reg [15:0] row23_s3_r;
    reg [15:0] row4_s3_r;

    reg        feat_vld_s4_r;
    reg  [7:0] center_s4_r;
    reg [15:0] filt_sum_s4_r;

    reg        feat_vld_s5_r;
    reg  [7:0] center_s5_r;
    reg  [7:0] filt_px_s5_r;

    reg               feat_vld_s6_r;
    reg  [7:0]        center_s6_r;
    reg  [7:0]        filtered_px_s6_r;

    reg        feat_vld_s7_r;
    reg  [7:0] center_s7_r;
    reg  [7:0] filtered_px_s7_r;

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
            row0_s2_r <= 13'd0;
            row1_s2_r <= 13'd0;
            row2_s2_r <= 13'd0;
            row3_s2_r <= 13'd0;
            row4_s2_r <= 13'd0;
            feat_vld_s3_r <= 1'b0;
            center_s3_r <= 8'd0;
            row01_s3_r <= 16'd0;
            row23_s3_r <= 16'd0;
            row4_s3_r <= 16'd0;
            feat_vld_s4_r <= 1'b0;
            center_s4_r <= 8'd0;
            filt_sum_s4_r <= 16'd0;
            feat_vld_s5_r <= 1'b0;
            center_s5_r <= 8'd0;
            filt_px_s5_r <= 8'd0;
            feat_vld_s6_r <= 1'b0;
            center_s6_r <= 8'd0;
            filtered_px_s6_r <= 8'd0;
            feat_vld_s7_r <= 1'b0;
            center_s7_r <= 8'd0;
            filtered_px_s7_r <= 8'd0;
            out_vld <= 1'b0;
            out_center <= 8'd0;
            out_filtered <= 8'd0;
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
            row0_s2_r <= 13'd0;
            row1_s2_r <= 13'd0;
            row2_s2_r <= 13'd0;
            row3_s2_r <= 13'd0;
            row4_s2_r <= 13'd0;
            feat_vld_s3_r <= 1'b0;
            center_s3_r <= 8'd0;
            row01_s3_r <= 16'd0;
            row23_s3_r <= 16'd0;
            row4_s3_r <= 16'd0;
            feat_vld_s4_r <= 1'b0;
            center_s4_r <= 8'd0;
            filt_sum_s4_r <= 16'd0;
            feat_vld_s5_r <= 1'b0;
            center_s5_r <= 8'd0;
            filt_px_s5_r <= 8'd0;
            feat_vld_s6_r <= 1'b0;
            center_s6_r <= 8'd0;
            filtered_px_s6_r <= 8'd0;
            feat_vld_s7_r <= 1'b0;
            center_s7_r <= 8'd0;
            filtered_px_s7_r <= 8'd0;
            out_vld <= 1'b0;
            out_center <= 8'd0;
            out_filtered <= 8'd0;
        end else begin
            feat_vld_s1_r <= win_vld_w;
            if (win_vld_w) begin
                center_s1_r <= m22_w;
                p00_s1_r <= range_pick(m00_w, m22_w); p01_s1_r <= range_pick(m01_w, m22_w); p02_s1_r <= range_pick(m02_w, m22_w); p03_s1_r <= range_pick(m03_w, m22_w); p04_s1_r <= range_pick(m04_w, m22_w);
                p10_s1_r <= range_pick(m10_w, m22_w); p11_s1_r <= range_pick(m11_w, m22_w); p12_s1_r <= range_pick(m12_w, m22_w); p13_s1_r <= range_pick(m13_w, m22_w); p14_s1_r <= range_pick(m14_w, m22_w);
                p20_s1_r <= range_pick(m20_w, m22_w); p21_s1_r <= range_pick(m21_w, m22_w); p22_s1_r <= m22_w;                  p23_s1_r <= range_pick(m23_w, m22_w); p24_s1_r <= range_pick(m24_w, m22_w);
                p30_s1_r <= range_pick(m30_w, m22_w); p31_s1_r <= range_pick(m31_w, m22_w); p32_s1_r <= range_pick(m32_w, m22_w); p33_s1_r <= range_pick(m33_w, m22_w); p34_s1_r <= range_pick(m34_w, m22_w);
                p40_s1_r <= range_pick(m40_w, m22_w); p41_s1_r <= range_pick(m41_w, m22_w); p42_s1_r <= range_pick(m42_w, m22_w); p43_s1_r <= range_pick(m43_w, m22_w); p44_s1_r <= range_pick(m44_w, m22_w);
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
                row0_s2_r <= row5_weighted(p00_s1_r, p01_s1_r, p02_s1_r, p03_s1_r, p04_s1_r);
                row1_s2_r <= row5_weighted(p10_s1_r, p11_s1_r, p12_s1_r, p13_s1_r, p14_s1_r);
                row2_s2_r <= row5_weighted(p20_s1_r, p21_s1_r, p22_s1_r, p23_s1_r, p24_s1_r);
                row3_s2_r <= row5_weighted(p30_s1_r, p31_s1_r, p32_s1_r, p33_s1_r, p34_s1_r);
                row4_s2_r <= row5_weighted(p40_s1_r, p41_s1_r, p42_s1_r, p43_s1_r, p44_s1_r);
            end else begin
                center_s2_r <= 8'd0;
                row0_s2_r <= 13'd0;
                row1_s2_r <= 13'd0;
                row2_s2_r <= 13'd0;
                row3_s2_r <= 13'd0;
                row4_s2_r <= 13'd0;
            end

            feat_vld_s3_r <= feat_vld_s2_r;
            if (feat_vld_s2_r) begin
                center_s3_r <= center_s2_r;
                row01_s3_r <= {3'b000, row0_s2_r} + {1'b0, row1_s2_r, 2'b00};
                row23_s3_r <= {1'b0, row2_s2_r, 2'b00} + {2'b00, row2_s2_r, 1'b0} + {1'b0, row3_s2_r, 2'b00};
                row4_s3_r <= {3'b000, row4_s2_r};
            end else begin
                center_s3_r <= 8'd0;
                row01_s3_r <= 16'd0;
                row23_s3_r <= 16'd0;
                row4_s3_r <= 16'd0;
            end

            feat_vld_s4_r <= feat_vld_s3_r;
            if (feat_vld_s3_r) begin
                center_s4_r <= center_s3_r;
                filt_sum_s4_r <= row01_s3_r + row23_s3_r + row4_s3_r;
            end else begin
                center_s4_r <= 8'd0;
                filt_sum_s4_r <= 16'd0;
            end

            feat_vld_s5_r <= feat_vld_s4_r;
            if (feat_vld_s4_r) begin
                center_s5_r <= center_s4_r;
                filt_px_s5_r <= (filt_sum_s4_r + 16'd128) >> 8;
            end else begin
                center_s5_r <= 8'd0;
                filt_px_s5_r <= 8'd0;
            end

            feat_vld_s6_r <= feat_vld_s5_r;
            if (feat_vld_s5_r) begin
                center_s6_r <= center_s5_r;
                filtered_px_s6_r <= filt_px_s5_r;
            end else begin
                center_s6_r <= 8'd0;
                filtered_px_s6_r <= 8'd0;
            end

            feat_vld_s7_r <= feat_vld_s6_r;
            if (feat_vld_s6_r) begin
                center_s7_r <= center_s6_r;
                filtered_px_s7_r <= filtered_px_s6_r;
            end else begin
                center_s7_r <= 8'd0;
                filtered_px_s7_r <= 8'd0;
            end

            out_vld <= feat_vld_s7_r;
            if (feat_vld_s7_r) begin
                out_center <= center_s7_r;
                out_filtered <= (ENABLE != 0) ? filtered_px_s7_r : center_s7_r;
            end else begin
                out_center <= 8'd0;
                out_filtered <= 8'd0;
            end
        end
    end

endmodule
