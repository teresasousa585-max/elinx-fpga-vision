module stream_plane_window5x5
#(
    parameter H_DISP = 1280,
    parameter V_DISP = 720
)
(
    input   wire            clk,
    input   wire            rst_n,
    input   wire            frame_clr,
    input   wire            din_vld,
    input   wire    [7:0]   din,

    output  reg             out_vld,
    output  reg     [7:0]   m00,
    output  reg     [7:0]   m01,
    output  reg     [7:0]   m02,
    output  reg     [7:0]   m03,
    output  reg     [7:0]   m04,
    output  reg     [7:0]   m10,
    output  reg     [7:0]   m11,
    output  reg     [7:0]   m12,
    output  reg     [7:0]   m13,
    output  reg     [7:0]   m14,
    output  reg     [7:0]   m20,
    output  reg     [7:0]   m21,
    output  reg     [7:0]   m22,
    output  reg     [7:0]   m23,
    output  reg     [7:0]   m24,
    output  reg     [7:0]   m30,
    output  reg     [7:0]   m31,
    output  reg     [7:0]   m32,
    output  reg     [7:0]   m33,
    output  reg     [7:0]   m34,
    output  reg     [7:0]   m40,
    output  reg     [7:0]   m41,
    output  reg     [7:0]   m42,
    output  reg     [7:0]   m43,
    output  reg     [7:0]   m44
);

    localparam [10:0] H_LAST_COL = H_DISP - 1;

    function [39:0] clamp5_left_u8;
        input [10:0] col;
        input [7:0] cur;
        input [7:0] h0;
        input [7:0] h1;
        input [7:0] h2;
        input [7:0] h3;
        input [7:0] h4;
        reg   [7:0] oldest;
        reg   [7:0] t0;
        reg   [7:0] t1;
        reg   [7:0] t2;
        reg   [7:0] t3;
        reg   [7:0] t4;
        begin
            if (col == 11'd0)
                oldest = cur;
            else if (col == 11'd1)
                oldest = h0;
            else if (col == 11'd2)
                oldest = h1;
            else if (col == 11'd3)
                oldest = h2;
            else if (col == 11'd4)
                oldest = h3;
            else
                oldest = h4;

            t0 = (col < 11'd5) ? oldest : h4;
            t1 = (col < 11'd4) ? oldest : h3;
            t2 = (col < 11'd3) ? oldest : h2;
            t3 = (col < 11'd2) ? oldest : h1;
            t4 = (col == 11'd0) ? oldest : h0;
            clamp5_left_u8 = {t0, t1, t2, t3, t4};
        end
    endfunction

    wire [7:0] line1_q;
    wire [7:0] line2_q;
    wire [7:0] line3_q;
    wire [7:0] line4_q;

    (* preserve, syn_preserve = 1 *) reg         din_vld_d1;
    (* preserve, syn_preserve = 1 *) reg         din_vld_d2;
    (* preserve, syn_preserve = 1 *) reg         din_vld_d3;
    (* preserve, syn_preserve = 1 *) reg         din_vld_d4;
    reg  [7:0]  din_d1;
    reg  [7:0]  din_d2;
    reg  [7:0]  din_d3;
    reg  [7:0]  din_d4;
    (* preserve, syn_preserve = 1 *) reg  [11:0] col_cnt;
    (* preserve, syn_preserve = 1 *) reg  [11:0] row_cnt;
    (* preserve, syn_preserve = 1 *) reg  [10:0] col_d1;
    (* preserve, syn_preserve = 1 *) reg  [10:0] col_d2;
    (* preserve, syn_preserve = 1 *) reg  [10:0] col_d3;
    (* preserve, syn_preserve = 1 *) reg  [10:0] col_d4;
    (* preserve, syn_preserve = 1 *) reg  [11:0] row_d1;
    (* preserve, syn_preserve = 1 *) reg  [11:0] row_d2;
    (* preserve, syn_preserve = 1 *) reg  [11:0] row_d3;
    (* preserve, syn_preserve = 1 *) reg  [11:0] row_d4;
    reg  [7:0]  line1_q_d1;
    reg  [7:0]  line1_q_d2;
    reg  [7:0]  line1_q_d3;
    reg  [7:0]  line2_q_d1;
    reg  [7:0]  line2_q_d2;
    reg  [7:0]  line3_q_d1;

    reg  [7:0]  r0_h0_r;
    reg  [7:0]  r0_h1_r;
    reg  [7:0]  r0_h2_r;
    reg  [7:0]  r0_h3_r;
    reg  [7:0]  r0_h4_r;
    reg  [7:0]  r1_h0_r;
    reg  [7:0]  r1_h1_r;
    reg  [7:0]  r1_h2_r;
    reg  [7:0]  r1_h3_r;
    reg  [7:0]  r1_h4_r;
    reg  [7:0]  r2_h0_r;
    reg  [7:0]  r2_h1_r;
    reg  [7:0]  r2_h2_r;
    reg  [7:0]  r2_h3_r;
    reg  [7:0]  r2_h4_r;
    reg  [7:0]  r3_h0_r;
    reg  [7:0]  r3_h1_r;
    reg  [7:0]  r3_h2_r;
    reg  [7:0]  r3_h3_r;
    reg  [7:0]  r3_h4_r;
    reg  [7:0]  r4_h0_r;
    reg  [7:0]  r4_h1_r;
    reg  [7:0]  r4_h2_r;
    reg  [7:0]  r4_h3_r;
    reg  [7:0]  r4_h4_r;

    wire [7:0] row4_src_w = din_d4;
    wire [7:0] row3_src_w = (row_d4 < 12'd1) ? 8'd0 : line1_q_d3;
    wire [7:0] row2_src_w = (row_d4 < 12'd2) ? 8'd0 : line2_q_d2;
    wire [7:0] row1_src_w = (row_d4 < 12'd3) ? 8'd0 : line3_q_d1;
    wire [7:0] row0_src_w = (row_d4 < 12'd4) ? 8'd0 : line4_q;

    wire [7:0] r0_t0_w = r0_h4_r;
    wire [7:0] r0_t1_w = r0_h3_r;
    wire [7:0] r0_t2_w = r0_h2_r;
    wire [7:0] r0_t3_w = r0_h1_r;
    wire [7:0] r0_t4_w = r0_h0_r;
    wire [7:0] r1_t0_w = r1_h4_r;
    wire [7:0] r1_t1_w = r1_h3_r;
    wire [7:0] r1_t2_w = r1_h2_r;
    wire [7:0] r1_t3_w = r1_h1_r;
    wire [7:0] r1_t4_w = r1_h0_r;
    wire [7:0] r2_t0_w = r2_h4_r;
    wire [7:0] r2_t1_w = r2_h3_r;
    wire [7:0] r2_t2_w = r2_h2_r;
    wire [7:0] r2_t3_w = r2_h1_r;
    wire [7:0] r2_t4_w = r2_h0_r;
    wire [7:0] r3_t0_w = r3_h4_r;
    wire [7:0] r3_t1_w = r3_h3_r;
    wire [7:0] r3_t2_w = r3_h2_r;
    wire [7:0] r3_t3_w = r3_h1_r;
    wire [7:0] r3_t4_w = r3_h0_r;
    wire [7:0] r4_t0_w = r4_h4_r;
    wire [7:0] r4_t1_w = r4_h3_r;
    wire [7:0] r4_t2_w = r4_h2_r;
    wire [7:0] r4_t3_w = r4_h1_r;
    wire [7:0] r4_t4_w = r4_h0_r;

    m4k_linebuf_2048x8 u_line1
    (
        .clock      (clk),
        .wren       (din_vld),
        .wraddress  (col_cnt[10:0]),
        .data       (din),
        .rdaddress  (col_cnt[10:0]),
        .q          (line1_q)
    );

    m4k_linebuf_2048x8 u_line2
    (
        .clock      (clk),
        .wren       (din_vld_d1 && (row_d1 != 12'd0)),
        .wraddress  (col_d1),
        .data       (line1_q),
        .rdaddress  (col_d1),
        .q          (line2_q)
    );

    m4k_linebuf_2048x8 u_line3
    (
        .clock      (clk),
        .wren       (din_vld_d2 && (row_d2 > 12'd1)),
        .wraddress  (col_d2),
        .data       (line2_q),
        .rdaddress  (col_d2),
        .q          (line3_q)
    );

    m4k_linebuf_2048x8 u_line4
    (
        .clock      (clk),
        .wren       (din_vld_d3 && (row_d3 > 12'd2)),
        .wraddress  (col_d3),
        .data       (line3_q),
        .rdaddress  (col_d3),
        .q          (line4_q)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            col_cnt <= 12'd0;
            row_cnt <= 12'd0;
            din_vld_d1 <= 1'b0;
            din_vld_d2 <= 1'b0;
            din_vld_d3 <= 1'b0;
            din_vld_d4 <= 1'b0;
            din_d1 <= 8'd0;
            din_d2 <= 8'd0;
            din_d3 <= 8'd0;
            din_d4 <= 8'd0;
            col_d1 <= 11'd0;
            col_d2 <= 11'd0;
            col_d3 <= 11'd0;
            col_d4 <= 11'd0;
            row_d1 <= 12'd0;
            row_d2 <= 12'd0;
            row_d3 <= 12'd0;
            row_d4 <= 12'd0;
            line1_q_d1 <= 8'd0;
            line1_q_d2 <= 8'd0;
            line1_q_d3 <= 8'd0;
            line2_q_d1 <= 8'd0;
            line2_q_d2 <= 8'd0;
            line3_q_d1 <= 8'd0;
            r0_h0_r <= 8'd0; r0_h1_r <= 8'd0; r0_h2_r <= 8'd0; r0_h3_r <= 8'd0; r0_h4_r <= 8'd0;
            r1_h0_r <= 8'd0; r1_h1_r <= 8'd0; r1_h2_r <= 8'd0; r1_h3_r <= 8'd0; r1_h4_r <= 8'd0;
            r2_h0_r <= 8'd0; r2_h1_r <= 8'd0; r2_h2_r <= 8'd0; r2_h3_r <= 8'd0; r2_h4_r <= 8'd0;
            r3_h0_r <= 8'd0; r3_h1_r <= 8'd0; r3_h2_r <= 8'd0; r3_h3_r <= 8'd0; r3_h4_r <= 8'd0;
            r4_h0_r <= 8'd0; r4_h1_r <= 8'd0; r4_h2_r <= 8'd0; r4_h3_r <= 8'd0; r4_h4_r <= 8'd0;
            out_vld <= 1'b0;
            m00 <= 8'd0; m01 <= 8'd0; m02 <= 8'd0; m03 <= 8'd0; m04 <= 8'd0;
            m10 <= 8'd0; m11 <= 8'd0; m12 <= 8'd0; m13 <= 8'd0; m14 <= 8'd0;
            m20 <= 8'd0; m21 <= 8'd0; m22 <= 8'd0; m23 <= 8'd0; m24 <= 8'd0;
            m30 <= 8'd0; m31 <= 8'd0; m32 <= 8'd0; m33 <= 8'd0; m34 <= 8'd0;
            m40 <= 8'd0; m41 <= 8'd0; m42 <= 8'd0; m43 <= 8'd0; m44 <= 8'd0;
        end else if (frame_clr) begin
            col_cnt <= 12'd0;
            row_cnt <= 12'd0;
            din_vld_d1 <= 1'b0;
            din_vld_d2 <= 1'b0;
            din_vld_d3 <= 1'b0;
            din_vld_d4 <= 1'b0;
            din_d1 <= 8'd0;
            din_d2 <= 8'd0;
            din_d3 <= 8'd0;
            din_d4 <= 8'd0;
            col_d1 <= 11'd0;
            col_d2 <= 11'd0;
            col_d3 <= 11'd0;
            col_d4 <= 11'd0;
            row_d1 <= 12'd0;
            row_d2 <= 12'd0;
            row_d3 <= 12'd0;
            row_d4 <= 12'd0;
            line1_q_d1 <= 8'd0;
            line1_q_d2 <= 8'd0;
            line1_q_d3 <= 8'd0;
            line2_q_d1 <= 8'd0;
            line2_q_d2 <= 8'd0;
            line3_q_d1 <= 8'd0;
            r0_h0_r <= 8'd0; r0_h1_r <= 8'd0; r0_h2_r <= 8'd0; r0_h3_r <= 8'd0; r0_h4_r <= 8'd0;
            r1_h0_r <= 8'd0; r1_h1_r <= 8'd0; r1_h2_r <= 8'd0; r1_h3_r <= 8'd0; r1_h4_r <= 8'd0;
            r2_h0_r <= 8'd0; r2_h1_r <= 8'd0; r2_h2_r <= 8'd0; r2_h3_r <= 8'd0; r2_h4_r <= 8'd0;
            r3_h0_r <= 8'd0; r3_h1_r <= 8'd0; r3_h2_r <= 8'd0; r3_h3_r <= 8'd0; r3_h4_r <= 8'd0;
            r4_h0_r <= 8'd0; r4_h1_r <= 8'd0; r4_h2_r <= 8'd0; r4_h3_r <= 8'd0; r4_h4_r <= 8'd0;
            out_vld <= 1'b0;
            m00 <= 8'd0; m01 <= 8'd0; m02 <= 8'd0; m03 <= 8'd0; m04 <= 8'd0;
            m10 <= 8'd0; m11 <= 8'd0; m12 <= 8'd0; m13 <= 8'd0; m14 <= 8'd0;
            m20 <= 8'd0; m21 <= 8'd0; m22 <= 8'd0; m23 <= 8'd0; m24 <= 8'd0;
            m30 <= 8'd0; m31 <= 8'd0; m32 <= 8'd0; m33 <= 8'd0; m34 <= 8'd0;
            m40 <= 8'd0; m41 <= 8'd0; m42 <= 8'd0; m43 <= 8'd0; m44 <= 8'd0;
        end else begin
            if (din_vld) begin
                if (col_cnt == H_DISP - 12'd1) begin
                    col_cnt <= 12'd0;
                    if (row_cnt == V_DISP - 12'd1)
                        row_cnt <= 12'd0;
                    else
                        row_cnt <= row_cnt + 12'd1;
                end else begin
                    col_cnt <= col_cnt + 12'd1;
                end
            end

            din_vld_d1 <= din_vld;
            din_d1 <= din;
            col_d1 <= col_cnt[10:0];
            row_d1 <= row_cnt;

            din_vld_d2 <= din_vld_d1;
            din_d2 <= din_d1;
            col_d2 <= col_d1;
            row_d2 <= row_d1;
            line1_q_d1 <= line1_q;

            din_vld_d3 <= din_vld_d2;
            din_d3 <= din_d2;
            col_d3 <= col_d2;
            row_d3 <= row_d2;
            line1_q_d2 <= line1_q_d1;
            line2_q_d1 <= line2_q;

            din_vld_d4 <= din_vld_d3;
            din_d4 <= din_d3;
            col_d4 <= col_d3;
            row_d4 <= row_d3;
            line1_q_d3 <= line1_q_d2;
            line2_q_d2 <= line2_q_d1;
            line3_q_d1 <= line3_q;

            out_vld <= din_vld_d4;
            if (din_vld_d4) begin
                m00 <= r0_t0_w; m01 <= r0_t1_w; m02 <= r0_t2_w; m03 <= r0_t3_w; m04 <= r0_t4_w;
                m10 <= r1_t0_w; m11 <= r1_t1_w; m12 <= r1_t2_w; m13 <= r1_t3_w; m14 <= r1_t4_w;
                m20 <= r2_t0_w; m21 <= r2_t1_w; m22 <= r2_t2_w; m23 <= r2_t3_w; m24 <= r2_t4_w;
                m30 <= r3_t0_w; m31 <= r3_t1_w; m32 <= r3_t2_w; m33 <= r3_t3_w; m34 <= r3_t4_w;
                m40 <= r4_t0_w; m41 <= r4_t1_w; m42 <= r4_t2_w; m43 <= r4_t3_w; m44 <= r4_t4_w;

                if (col_d4 == H_LAST_COL) begin
                    r0_h0_r <= 8'd0; r0_h1_r <= 8'd0; r0_h2_r <= 8'd0; r0_h3_r <= 8'd0; r0_h4_r <= 8'd0;
                    r1_h0_r <= 8'd0; r1_h1_r <= 8'd0; r1_h2_r <= 8'd0; r1_h3_r <= 8'd0; r1_h4_r <= 8'd0;
                    r2_h0_r <= 8'd0; r2_h1_r <= 8'd0; r2_h2_r <= 8'd0; r2_h3_r <= 8'd0; r2_h4_r <= 8'd0;
                    r3_h0_r <= 8'd0; r3_h1_r <= 8'd0; r3_h2_r <= 8'd0; r3_h3_r <= 8'd0; r3_h4_r <= 8'd0;
                    r4_h0_r <= 8'd0; r4_h1_r <= 8'd0; r4_h2_r <= 8'd0; r4_h3_r <= 8'd0; r4_h4_r <= 8'd0;
                end else begin
                    r0_h0_r <= row0_src_w; r0_h1_r <= r0_h0_r; r0_h2_r <= r0_h1_r; r0_h3_r <= r0_h2_r; r0_h4_r <= r0_h3_r;
                    r1_h0_r <= row1_src_w; r1_h1_r <= r1_h0_r; r1_h2_r <= r1_h1_r; r1_h3_r <= r1_h2_r; r1_h4_r <= r1_h3_r;
                    r2_h0_r <= row2_src_w; r2_h1_r <= r2_h0_r; r2_h2_r <= r2_h1_r; r2_h3_r <= r2_h2_r; r2_h4_r <= r2_h3_r;
                    r3_h0_r <= row3_src_w; r3_h1_r <= r3_h0_r; r3_h2_r <= r3_h1_r; r3_h3_r <= r3_h2_r; r3_h4_r <= r3_h3_r;
                    r4_h0_r <= row4_src_w; r4_h1_r <= r4_h0_r; r4_h2_r <= r4_h1_r; r4_h3_r <= r4_h2_r; r4_h4_r <= r4_h3_r;
                end
            end else begin
                m00 <= 8'd0; m01 <= 8'd0; m02 <= 8'd0; m03 <= 8'd0; m04 <= 8'd0;
                m10 <= 8'd0; m11 <= 8'd0; m12 <= 8'd0; m13 <= 8'd0; m14 <= 8'd0;
                m20 <= 8'd0; m21 <= 8'd0; m22 <= 8'd0; m23 <= 8'd0; m24 <= 8'd0;
                m30 <= 8'd0; m31 <= 8'd0; m32 <= 8'd0; m33 <= 8'd0; m34 <= 8'd0;
                m40 <= 8'd0; m41 <= 8'd0; m42 <= 8'd0; m43 <= 8'd0; m44 <= 8'd0;
            end
        end
    end

endmodule

module stream_plane_center_delay_5x5
#(
    parameter H_DISP = 1280,
    parameter V_DISP = 720
)
(
    input   wire          clk,
    input   wire          rst_n,
    input   wire          frame_clr,
    input   wire          din_vld,
    input   wire  [7:0]   din,
    output  reg           out_vld,
    output  reg   [7:0]   out_center
);

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
    reg        center_vld_s1_r;
    reg        center_vld_s2_r;
    reg  [7:0] center_s1_r;
    reg  [7:0] center_s2_r;

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
            center_vld_s1_r <= 1'b0;
            center_vld_s2_r <= 1'b0;
            center_s1_r <= 8'd0;
            center_s2_r <= 8'd0;
            out_vld <= 1'b0;
            out_center <= 8'd0;
        end else if (frame_clr) begin
            center_vld_s1_r <= 1'b0;
            center_vld_s2_r <= 1'b0;
            center_s1_r <= 8'd0;
            center_s2_r <= 8'd0;
            out_vld <= 1'b0;
            out_center <= 8'd0;
        end else begin
            center_vld_s1_r <= win_vld_w;
            center_vld_s2_r <= center_vld_s1_r;
            center_s1_r <= win_vld_w ? m22_w : 8'd0;
            center_s2_r <= center_vld_s1_r ? center_s1_r : 8'd0;
            out_vld <= center_vld_s2_r;
            out_center <= center_vld_s2_r ? center_s2_r : 8'd0;
        end
    end

endmodule

module stream_plane_delay2_5x5
#(
    parameter H_DISP = 1280,
    parameter V_DISP = 720
)
(
    input   wire          clk,
    input   wire          rst_n,
    input   wire          frame_clr,
    input   wire          din_vld,
    input   wire  [7:0]   din,
    output  wire          out_vld,
    output  wire  [7:0]   out_center
);

    wire       de1_w;
    wire [7:0] center1_w;

    stream_plane_center_delay_5x5
    #(
        .H_DISP (H_DISP),
        .V_DISP (V_DISP)
    )
    u_delay1
    (
        .clk        (clk),
        .rst_n      (rst_n),
        .frame_clr  (frame_clr),
        .din_vld    (din_vld),
        .din        (din),
        .out_vld    (de1_w),
        .out_center (center1_w)
    );

    stream_plane_center_delay_5x5
    #(
        .H_DISP (H_DISP),
        .V_DISP (V_DISP)
    )
    u_delay2
    (
        .clk        (clk),
        .rst_n      (rst_n),
        .frame_clr  (frame_clr),
        .din_vld    (de1_w),
        .din        (center1_w),
        .out_vld    (out_vld),
        .out_center (out_center)
    );

endmodule

module stream_rgb_center_delay_5x5
#(
    parameter H_DISP = 1280,
    parameter V_DISP = 720
)
(
    input   wire          clk,
    input   wire          rst_n,
    input   wire          frame_clr,
    input   wire          din_vld,
    input   wire  [23:0]  din_rgb,
    output  wire          out_vld,
    output  wire  [23:0]  out_center_rgb
);

    wire de_r_w;
    wire de_g_w;
    wire de_b_w;
    wire [7:0] r_center_w;
    wire [7:0] g_center_w;
    wire [7:0] b_center_w;

    stream_plane_center_delay_5x5
    #(
        .H_DISP (H_DISP),
        .V_DISP (V_DISP)
    )
    u_r_delay
    (
        .clk        (clk),
        .rst_n      (rst_n),
        .frame_clr  (frame_clr),
        .din_vld    (din_vld),
        .din        (din_rgb[23:16]),
        .out_vld    (de_r_w),
        .out_center (r_center_w)
    );

    stream_plane_center_delay_5x5
    #(
        .H_DISP (H_DISP),
        .V_DISP (V_DISP)
    )
    u_g_delay
    (
        .clk        (clk),
        .rst_n      (rst_n),
        .frame_clr  (frame_clr),
        .din_vld    (din_vld),
        .din        (din_rgb[15:8]),
        .out_vld    (de_g_w),
        .out_center (g_center_w)
    );

    stream_plane_center_delay_5x5
    #(
        .H_DISP (H_DISP),
        .V_DISP (V_DISP)
    )
    u_b_delay
    (
        .clk        (clk),
        .rst_n      (rst_n),
        .frame_clr  (frame_clr),
        .din_vld    (din_vld),
        .din        (din_rgb[7:0]),
        .out_vld    (de_b_w),
        .out_center (b_center_w)
    );

    assign out_vld = de_r_w & de_g_w & de_b_w;
    assign out_center_rgb = {r_center_w, g_center_w, b_center_w};

endmodule
