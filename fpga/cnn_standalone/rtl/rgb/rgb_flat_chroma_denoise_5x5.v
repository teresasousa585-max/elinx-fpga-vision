module rgb_flat_chroma_denoise_5x5
#(
    parameter H_DISP = 1280,
    parameter V_DISP = 720,
    parameter ENABLE = 1,
    parameter [7:0] Y_RANGE_TH = 8'd8,
    parameter [7:0] CHROMA_RANGE_TH = 8'd16,
    parameter [8:0] ALPHA_Q8 = 9'd224,
    parameter [7:0] DELTA_CLAMP = 8'd16,
    parameter NEUTRAL_GUARD_ENABLE = 1,
    parameter [7:0] NEUTRAL_OUTWARD_CAP = 8'd2,
    parameter [7:0] NEUTRAL_SAT_TH = 8'd42,
    parameter [7:0] NEUTRAL_CHROMA_TH = 8'd18,
    parameter [10:0] STARTUP_BYPASS_LEFT_PX = 11'd5,
    parameter [10:0] STARTUP_BYPASS_TOP_PX = 11'd4
)
(
    input   wire            clk,
    input   wire            rst_n,
    input   wire            frame_clr,
    input   wire            in_de,
    input   wire    [23:0]  in_rgb,

    output  wire            out_de,
    output  wire    [23:0]  out_rgb
);

generate
if (ENABLE == 0) begin : gen_bypass
    stream_rgb_delay_pipe
    #(
        .LATENCY (16)
    )
    u_bypass_delay
    (
        .clk      (clk),
        .rst_n    (rst_n),
        .frame_clr(frame_clr),
        .in_de    (in_de),
        .in_rgb   (in_rgb),
        .out_de   (out_de),
        .out_rgb  (out_rgb)
    );
end else begin : gen_fcd5
    wire        fcd_de_w;
    wire [23:0] fcd_rgb_w;

    rgb_flat_chroma_denoise_5x5_core
    #(
        .H_DISP(H_DISP),
        .V_DISP(V_DISP),
        .Y_RANGE_TH(Y_RANGE_TH),
        .CHROMA_RANGE_TH(CHROMA_RANGE_TH),
        .ALPHA_Q8(ALPHA_Q8),
        .DELTA_CLAMP(DELTA_CLAMP),
        .NEUTRAL_GUARD_ENABLE(NEUTRAL_GUARD_ENABLE),
        .NEUTRAL_OUTWARD_CAP(NEUTRAL_OUTWARD_CAP),
        .NEUTRAL_SAT_TH(NEUTRAL_SAT_TH),
        .NEUTRAL_CHROMA_TH(NEUTRAL_CHROMA_TH),
        .STARTUP_BYPASS_LEFT_PX(STARTUP_BYPASS_LEFT_PX),
        .STARTUP_BYPASS_TOP_PX(STARTUP_BYPASS_TOP_PX)
    )
    u_core
    (
        .clk      (clk),
        .rst_n    (rst_n),
        .frame_clr(frame_clr),
        .in_de    (in_de),
        .in_rgb   (in_rgb),
        .out_de   (fcd_de_w),
        .out_rgb  (fcd_rgb_w)
    );

    assign out_de = fcd_de_w;
    assign out_rgb = fcd_rgb_w;
end
endgenerate

endmodule

module stream_plane_causal5x5_current_window
#(
    parameter H_DISP = 1280,
    parameter V_DISP = 720,
    parameter REPLICATE_CENTER = 0
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
    output  reg     [7:0]   m44,
    output  wire    [199:0] center_leaf
);

wire [7:0] line1_q;
wire [7:0] line2_q;
wire [7:0] line3_q;
wire [7:0] line4_q;

reg        din_vld_d1;
reg        din_vld_d2;
reg        din_vld_d3;
reg        din_vld_d4;
reg [7:0]  din_d1;
reg [7:0]  din_d2;
reg [7:0]  din_d3;
reg [7:0]  din_d4;
reg [11:0] col_cnt;
reg [11:0] row_cnt;
reg [10:0] col_d1;
reg [10:0] col_d2;
reg [10:0] col_d3;
reg [10:0] col_d4;
reg [11:0] row_d1;
reg [11:0] row_d2;
reg [11:0] row_d3;
reg [11:0] row_d4;
reg [7:0]  line1_q_d1;
reg [7:0]  line1_q_d2;
reg [7:0]  line1_q_d3;
reg [7:0]  line2_q_d1;
reg [7:0]  line2_q_d2;
reg [7:0]  line3_q_d1;

reg [7:0] r0_h0_r, r0_h1_r, r0_h2_r, r0_h3_r;
reg [7:0] r1_h0_r, r1_h1_r, r1_h2_r, r1_h3_r;
reg [7:0] r2_h0_r, r2_h1_r, r2_h2_r, r2_h3_r;
reg [7:0] r3_h0_r, r3_h1_r, r3_h2_r, r3_h3_r;
reg [7:0] r4_h0_r, r4_h1_r, r4_h2_r, r4_h3_r;

localparam [10:0] H_LAST_COL = H_DISP - 1;

wire [7:0] row4_src_w = din_d4;
wire [7:0] row3_src_w = (row_d4 < 12'd1) ? 8'd0 : line1_q_d3;
wire [7:0] row2_src_w = (row_d4 < 12'd2) ? 8'd0 : line2_q_d2;
wire [7:0] row1_src_w = (row_d4 < 12'd3) ? 8'd0 : line3_q_d1;
wire [7:0] row0_src_w = (row_d4 < 12'd4) ? 8'd0 : line4_q;

wire [7:0] r0_t0_w = (col_d4 < 11'd4) ? 8'd0 : r0_h3_r;
wire [7:0] r0_t1_w = (col_d4 < 11'd3) ? 8'd0 : r0_h2_r;
wire [7:0] r0_t2_w = (col_d4 < 11'd2) ? 8'd0 : r0_h1_r;
wire [7:0] r0_t3_w = (col_d4 < 11'd1) ? 8'd0 : r0_h0_r;
wire [7:0] r0_t4_w = row0_src_w;
wire [7:0] r1_t0_w = (col_d4 < 11'd4) ? 8'd0 : r1_h3_r;
wire [7:0] r1_t1_w = (col_d4 < 11'd3) ? 8'd0 : r1_h2_r;
wire [7:0] r1_t2_w = (col_d4 < 11'd2) ? 8'd0 : r1_h1_r;
wire [7:0] r1_t3_w = (col_d4 < 11'd1) ? 8'd0 : r1_h0_r;
wire [7:0] r1_t4_w = row1_src_w;
wire [7:0] r2_t0_w = (col_d4 < 11'd4) ? 8'd0 : r2_h3_r;
wire [7:0] r2_t1_w = (col_d4 < 11'd3) ? 8'd0 : r2_h2_r;
wire [7:0] r2_t2_w = (col_d4 < 11'd2) ? 8'd0 : r2_h1_r;
wire [7:0] r2_t3_w = (col_d4 < 11'd1) ? 8'd0 : r2_h0_r;
wire [7:0] r2_t4_w = row2_src_w;
wire [7:0] r3_t0_w = (col_d4 < 11'd4) ? 8'd0 : r3_h3_r;
wire [7:0] r3_t1_w = (col_d4 < 11'd3) ? 8'd0 : r3_h2_r;
wire [7:0] r3_t2_w = (col_d4 < 11'd2) ? 8'd0 : r3_h1_r;
wire [7:0] r3_t3_w = (col_d4 < 11'd1) ? 8'd0 : r3_h0_r;
wire [7:0] r3_t4_w = row3_src_w;
wire [7:0] r4_t0_w = (col_d4 < 11'd4) ? 8'd0 : r4_h3_r;
wire [7:0] r4_t1_w = (col_d4 < 11'd3) ? 8'd0 : r4_h2_r;
wire [7:0] r4_t2_w = (col_d4 < 11'd2) ? 8'd0 : r4_h1_r;
wire [7:0] r4_t3_w = (col_d4 < 11'd1) ? 8'd0 : r4_h0_r;
wire [7:0] r4_t4_w = row4_src_w;

// Each enabled leaf captures the same center sample on the same edge as m44.
// The physical copies keep the 25 range/mux cones local instead of routing one
// high-fanout center register across the complete 5x5 filter region.
genvar center_leaf_idx;
generate
if (REPLICATE_CENTER != 0) begin : gen_center_leaf_enable
    for (center_leaf_idx = 0; center_leaf_idx < 25; center_leaf_idx = center_leaf_idx + 1) begin : gen_center_leaf
        (* synthesis, keep, preserve, noprune, syn_preserve = 1, syn_keep = 1 *)
        reg [7:0] center_leaf_r;

        always @(posedge clk) begin
            center_leaf_r <= r4_t4_w;
        end

        assign center_leaf[center_leaf_idx*8 +: 8] = center_leaf_r;
    end
end else begin : gen_center_leaf_disable
    assign center_leaf = 200'd0;
end
endgenerate

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
        col_cnt <= 12'd0; row_cnt <= 12'd0;
        din_vld_d1 <= 1'b0; din_vld_d2 <= 1'b0; din_vld_d3 <= 1'b0; din_vld_d4 <= 1'b0;
        din_d1 <= 8'd0; din_d2 <= 8'd0; din_d3 <= 8'd0; din_d4 <= 8'd0;
        col_d1 <= 11'd0; col_d2 <= 11'd0; col_d3 <= 11'd0; col_d4 <= 11'd0;
        row_d1 <= 12'd0; row_d2 <= 12'd0; row_d3 <= 12'd0; row_d4 <= 12'd0;
        line1_q_d1 <= 8'd0; line1_q_d2 <= 8'd0; line1_q_d3 <= 8'd0;
        line2_q_d1 <= 8'd0; line2_q_d2 <= 8'd0; line3_q_d1 <= 8'd0;
        r0_h0_r <= 8'd0; r0_h1_r <= 8'd0; r0_h2_r <= 8'd0; r0_h3_r <= 8'd0;
        r1_h0_r <= 8'd0; r1_h1_r <= 8'd0; r1_h2_r <= 8'd0; r1_h3_r <= 8'd0;
        r2_h0_r <= 8'd0; r2_h1_r <= 8'd0; r2_h2_r <= 8'd0; r2_h3_r <= 8'd0;
        r3_h0_r <= 8'd0; r3_h1_r <= 8'd0; r3_h2_r <= 8'd0; r3_h3_r <= 8'd0;
        r4_h0_r <= 8'd0; r4_h1_r <= 8'd0; r4_h2_r <= 8'd0; r4_h3_r <= 8'd0;
        out_vld <= 1'b0;
        m00 <= 8'd0; m01 <= 8'd0; m02 <= 8'd0; m03 <= 8'd0; m04 <= 8'd0;
        m10 <= 8'd0; m11 <= 8'd0; m12 <= 8'd0; m13 <= 8'd0; m14 <= 8'd0;
        m20 <= 8'd0; m21 <= 8'd0; m22 <= 8'd0; m23 <= 8'd0; m24 <= 8'd0;
        m30 <= 8'd0; m31 <= 8'd0; m32 <= 8'd0; m33 <= 8'd0; m34 <= 8'd0;
        m40 <= 8'd0; m41 <= 8'd0; m42 <= 8'd0; m43 <= 8'd0; m44 <= 8'd0;
    end else if (frame_clr) begin
        col_cnt <= 12'd0; row_cnt <= 12'd0;
        din_vld_d1 <= 1'b0; din_vld_d2 <= 1'b0; din_vld_d3 <= 1'b0; din_vld_d4 <= 1'b0;
        din_d1 <= 8'd0; din_d2 <= 8'd0; din_d3 <= 8'd0; din_d4 <= 8'd0;
        col_d1 <= 11'd0; col_d2 <= 11'd0; col_d3 <= 11'd0; col_d4 <= 11'd0;
        row_d1 <= 12'd0; row_d2 <= 12'd0; row_d3 <= 12'd0; row_d4 <= 12'd0;
        line1_q_d1 <= 8'd0; line1_q_d2 <= 8'd0; line1_q_d3 <= 8'd0;
        line2_q_d1 <= 8'd0; line2_q_d2 <= 8'd0; line3_q_d1 <= 8'd0;
        r0_h0_r <= 8'd0; r0_h1_r <= 8'd0; r0_h2_r <= 8'd0; r0_h3_r <= 8'd0;
        r1_h0_r <= 8'd0; r1_h1_r <= 8'd0; r1_h2_r <= 8'd0; r1_h3_r <= 8'd0;
        r2_h0_r <= 8'd0; r2_h1_r <= 8'd0; r2_h2_r <= 8'd0; r2_h3_r <= 8'd0;
        r3_h0_r <= 8'd0; r3_h1_r <= 8'd0; r3_h2_r <= 8'd0; r3_h3_r <= 8'd0;
        r4_h0_r <= 8'd0; r4_h1_r <= 8'd0; r4_h2_r <= 8'd0; r4_h3_r <= 8'd0;
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
                r0_h0_r <= 8'd0; r0_h1_r <= 8'd0; r0_h2_r <= 8'd0; r0_h3_r <= 8'd0;
                r1_h0_r <= 8'd0; r1_h1_r <= 8'd0; r1_h2_r <= 8'd0; r1_h3_r <= 8'd0;
                r2_h0_r <= 8'd0; r2_h1_r <= 8'd0; r2_h2_r <= 8'd0; r2_h3_r <= 8'd0;
                r3_h0_r <= 8'd0; r3_h1_r <= 8'd0; r3_h2_r <= 8'd0; r3_h3_r <= 8'd0;
                r4_h0_r <= 8'd0; r4_h1_r <= 8'd0; r4_h2_r <= 8'd0; r4_h3_r <= 8'd0;
            end else begin
                r0_h0_r <= row0_src_w; r0_h1_r <= r0_h0_r; r0_h2_r <= r0_h1_r; r0_h3_r <= r0_h2_r;
                r1_h0_r <= row1_src_w; r1_h1_r <= r1_h0_r; r1_h2_r <= r1_h1_r; r1_h3_r <= r1_h2_r;
                r2_h0_r <= row2_src_w; r2_h1_r <= r2_h0_r; r2_h2_r <= r2_h1_r; r2_h3_r <= r2_h2_r;
                r3_h0_r <= row3_src_w; r3_h1_r <= r3_h0_r; r3_h2_r <= r3_h1_r; r3_h3_r <= r3_h2_r;
                r4_h0_r <= row4_src_w; r4_h1_r <= r4_h0_r; r4_h2_r <= r4_h1_r; r4_h3_r <= r4_h2_r;
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

module rgb_flat_chroma_denoise_5x5_core
#(
    parameter H_DISP = 1280,
    parameter V_DISP = 720,
    parameter [7:0] Y_RANGE_TH = 8'd8,
    parameter [7:0] CHROMA_RANGE_TH = 8'd16,
    parameter [8:0] ALPHA_Q8 = 9'd224,
    parameter [7:0] DELTA_CLAMP = 8'd16,
    parameter NEUTRAL_GUARD_ENABLE = 1,
    parameter [7:0] NEUTRAL_OUTWARD_CAP = 8'd2,
    parameter [7:0] NEUTRAL_SAT_TH = 8'd42,
    parameter [7:0] NEUTRAL_CHROMA_TH = 8'd18,
    parameter [10:0] STARTUP_BYPASS_LEFT_PX = 11'd5,
    parameter [10:0] STARTUP_BYPASS_TOP_PX = 11'd4
)
(
    input   wire            clk,
    input   wire            rst_n,
    input   wire            frame_clr,
    input   wire            in_de,
    input   wire    [23:0]  in_rgb,

    output  reg             out_de,
    output  reg     [23:0]  out_rgb
);

function [7:0] clip_u8;
    input signed [13:0] value;
    begin
        if (value < 14'sd0)
            clip_u8 = 8'd0;
        else if (value > 14'sd255)
            clip_u8 = 8'd255;
        else
            clip_u8 = value[7:0];
    end
endfunction

function [7:0] max3_u8;
    input [7:0] a;
    input [7:0] b;
    input [7:0] c;
    reg [7:0] ab;
    begin
        ab = (a >= b) ? a : b;
        max3_u8 = (ab >= c) ? ab : c;
    end
endfunction

function [7:0] min3_u8;
    input [7:0] a;
    input [7:0] b;
    input [7:0] c;
    reg [7:0] ab;
    begin
        ab = (a <= b) ? a : b;
        min3_u8 = (ab <= c) ? ab : c;
    end
endfunction

function [7:0] abs_diff_u8;
    input [7:0] a;
    input [7:0] b;
    begin
        abs_diff_u8 = (a >= b) ? (a - b) : (b - a);
    end
endfunction

function signed [8:0] clamp_signed9;
    input signed [8:0] value;
    input [7:0] limit;
    begin
        if (value < -$signed({1'b0, limit}))
            clamp_signed9 = -$signed({1'b0, limit});
        else if (value > $signed({1'b0, limit}))
            clamp_signed9 = $signed({1'b0, limit});
        else
            clamp_signed9 = value;
    end
endfunction

function [7:0] chroma_abs_from_128;
    input [7:0] value;
    begin
        chroma_abs_from_128 = (value >= 8'd128) ? (value - 8'd128) : (8'd128 - value);
    end
endfunction

function signed [8:0] neutral_outward_limit;
    input signed [8:0] delta;
    input [7:0] center_off;
    begin
        if ((center_off > 8'd128) && (delta > $signed({1'b0, NEUTRAL_OUTWARD_CAP})))
            neutral_outward_limit = $signed({1'b0, NEUTRAL_OUTWARD_CAP});
        else if ((center_off < 8'd128) && (delta < -$signed({1'b0, NEUTRAL_OUTWARD_CAP})))
            neutral_outward_limit = -$signed({1'b0, NEUTRAL_OUTWARD_CAP});
        else
            neutral_outward_limit = delta;
    end
endfunction

function [12:0] row5_weighted;
    input [39:0] row_values;
    reg [7:0] p0;
    reg [7:0] p1;
    reg [7:0] p2;
    reg [7:0] p3;
    reg [7:0] p4;
    begin
        p0 = row_values[7:0];
        p1 = row_values[15:8];
        p2 = row_values[23:16];
        p3 = row_values[31:24];
        p4 = row_values[39:32];
        row5_weighted =
            {5'd0, p0} +
            {4'd0, p1, 1'b0} +
            {3'd0, p2, 2'b00} +
            {4'd0, p3, 1'b0} +
            {5'd0, p4};
    end
endfunction

function [7:0] div100_round_u16;
    input [15:0] value;
    reg [27:0] product;
    begin
        product = (value + 16'd50) * 13'd5243;
        div100_round_u16 = product[26:19];
    end
endfunction

wire [7:0] in_r_w = in_rgb[23:16];
wire [7:0] in_g_w = in_rgb[15:8];
wire [7:0] in_b_w = in_rgb[7:0];

wire [15:0] in_r_y_w = in_r_w * 8'd77;
wire [15:0] in_g_y_w = in_g_w * 8'd150;
wire [15:0] in_b_y_w = in_b_w * 8'd29;
wire [15:0] in_r_cb_w = in_r_w * 8'd43;
wire [15:0] in_g_cb_w = in_g_w * 8'd85;
wire [15:0] in_b_cb_w = in_b_w << 7;
wire [15:0] in_r_cr_w = in_r_w << 7;
wire [15:0] in_g_cr_w = in_g_w * 8'd107;
wire [15:0] in_b_cr_w = in_b_w * 8'd21;

reg        yc0_de_r;
reg [23:0] yc0_rgb_r;
reg [15:0] yc0_r_y_r;
reg [15:0] yc0_g_y_r;
reg [15:0] yc0_b_y_r;
reg [15:0] yc0_r_cb_r;
reg [15:0] yc0_g_cb_r;
reg [15:0] yc0_b_cb_r;
reg [15:0] yc0_r_cr_r;
reg [15:0] yc0_g_cr_r;
reg [15:0] yc0_b_cr_r;

wire [17:0] y_acc_w =
    {2'b00, yc0_r_y_r} +
    {2'b00, yc0_g_y_r} +
    {2'b00, yc0_b_y_r} +
    18'd128;
wire signed [17:0] cb_acc_w =
    -$signed({2'b00, yc0_r_cb_r}) -
    $signed({2'b00, yc0_g_cb_r}) +
    $signed({2'b00, yc0_b_cb_r}) +
    18'sd128;
wire signed [17:0] cr_acc_w =
    $signed({2'b00, yc0_r_cr_r}) -
    $signed({2'b00, yc0_g_cr_r}) -
    $signed({2'b00, yc0_b_cr_r}) +
    18'sd128;

reg        s0_de_r;
reg [23:0] s0_rgb_r;
reg [7:0]  s0_y_r;
reg [7:0]  s0_cb_r;
reg [7:0]  s0_cr_r;
reg [7:0]  s0_r_r;
reg [7:0]  s0_g_r;
reg [7:0]  s0_b_r;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        yc0_de_r <= 1'b0;
        yc0_rgb_r <= 24'd0;
        yc0_r_y_r <= 16'd0; yc0_g_y_r <= 16'd0; yc0_b_y_r <= 16'd0;
        yc0_r_cb_r <= 16'd0; yc0_g_cb_r <= 16'd0; yc0_b_cb_r <= 16'd0;
        yc0_r_cr_r <= 16'd0; yc0_g_cr_r <= 16'd0; yc0_b_cr_r <= 16'd0;
        s0_de_r <= 1'b0;
        s0_rgb_r <= 24'd0;
        s0_y_r <= 8'd0; s0_cb_r <= 8'd0; s0_cr_r <= 8'd0;
        s0_r_r <= 8'd0; s0_g_r <= 8'd0; s0_b_r <= 8'd0;
    end else if (frame_clr) begin
        yc0_de_r <= 1'b0;
        yc0_rgb_r <= 24'd0;
        yc0_r_y_r <= 16'd0; yc0_g_y_r <= 16'd0; yc0_b_y_r <= 16'd0;
        yc0_r_cb_r <= 16'd0; yc0_g_cb_r <= 16'd0; yc0_b_cb_r <= 16'd0;
        yc0_r_cr_r <= 16'd0; yc0_g_cr_r <= 16'd0; yc0_b_cr_r <= 16'd0;
        s0_de_r <= 1'b0;
        s0_rgb_r <= 24'd0;
        s0_y_r <= 8'd0; s0_cb_r <= 8'd0; s0_cr_r <= 8'd0;
        s0_r_r <= 8'd0; s0_g_r <= 8'd0; s0_b_r <= 8'd0;
    end else begin
        yc0_de_r <= in_de;
        yc0_rgb_r <= in_de ? in_rgb : 24'd0;
        yc0_r_y_r <= in_de ? in_r_y_w : 16'd0;
        yc0_g_y_r <= in_de ? in_g_y_w : 16'd0;
        yc0_b_y_r <= in_de ? in_b_y_w : 16'd0;
        yc0_r_cb_r <= in_de ? in_r_cb_w : 16'd0;
        yc0_g_cb_r <= in_de ? in_g_cb_w : 16'd0;
        yc0_b_cb_r <= in_de ? in_b_cb_w : 16'd0;
        yc0_r_cr_r <= in_de ? in_r_cr_w : 16'd0;
        yc0_g_cr_r <= in_de ? in_g_cr_w : 16'd0;
        yc0_b_cr_r <= in_de ? in_b_cr_w : 16'd0;

        s0_de_r <= yc0_de_r;
        if (yc0_de_r) begin
            s0_rgb_r <= yc0_rgb_r;
            s0_y_r <= y_acc_w[15:8];
            s0_cb_r <= (cb_acc_w >>> 8) + 9'sd128;
            s0_cr_r <= (cr_acc_w >>> 8) + 9'sd128;
            s0_r_r <= yc0_rgb_r[23:16];
            s0_g_r <= yc0_rgb_r[15:8];
            s0_b_r <= yc0_rgb_r[7:0];
        end else begin
            s0_rgb_r <= 24'd0;
            s0_y_r <= 8'd0; s0_cb_r <= 8'd0; s0_cr_r <= 8'd0;
            s0_r_r <= 8'd0; s0_g_r <= 8'd0; s0_b_r <= 8'd0;
        end
    end
end

wire y_win_de_w;
wire cb_win_de_w;
wire cr_win_de_w;
wire r_win_de_w;
wire g_win_de_w;
wire b_win_de_w;
wire [199:0] y_win_w;
wire [199:0] cb_win_w;
wire [199:0] cr_win_w;
wire [199:0] r_win_w;
wire [199:0] g_win_w;
wire [199:0] b_win_w;
wire [199:0] y_center_leaf_w;
wire [199:0] cb_center_leaf_w;
wire [199:0] cr_center_leaf_w;

stream_plane_causal5x5_current_window #(
    .H_DISP(H_DISP), .V_DISP(V_DISP), .REPLICATE_CENTER(1)
) u_y_window
(
    .clk(clk), .rst_n(rst_n), .frame_clr(frame_clr), .din_vld(s0_de_r), .din(s0_y_r),
    .out_vld(y_win_de_w),
    .m00(y_win_w[7:0]), .m01(y_win_w[15:8]), .m02(y_win_w[23:16]), .m03(y_win_w[31:24]), .m04(y_win_w[39:32]),
    .m10(y_win_w[47:40]), .m11(y_win_w[55:48]), .m12(y_win_w[63:56]), .m13(y_win_w[71:64]), .m14(y_win_w[79:72]),
    .m20(y_win_w[87:80]), .m21(y_win_w[95:88]), .m22(y_win_w[103:96]), .m23(y_win_w[111:104]), .m24(y_win_w[119:112]),
    .m30(y_win_w[127:120]), .m31(y_win_w[135:128]), .m32(y_win_w[143:136]), .m33(y_win_w[151:144]), .m34(y_win_w[159:152]),
    .m40(y_win_w[167:160]), .m41(y_win_w[175:168]), .m42(y_win_w[183:176]), .m43(y_win_w[191:184]), .m44(y_win_w[199:192]),
    .center_leaf(y_center_leaf_w)
);

stream_plane_causal5x5_current_window #(
    .H_DISP(H_DISP), .V_DISP(V_DISP), .REPLICATE_CENTER(1)
) u_cb_window
(
    .clk(clk), .rst_n(rst_n), .frame_clr(frame_clr), .din_vld(s0_de_r), .din(s0_cb_r),
    .out_vld(cb_win_de_w),
    .m00(cb_win_w[7:0]), .m01(cb_win_w[15:8]), .m02(cb_win_w[23:16]), .m03(cb_win_w[31:24]), .m04(cb_win_w[39:32]),
    .m10(cb_win_w[47:40]), .m11(cb_win_w[55:48]), .m12(cb_win_w[63:56]), .m13(cb_win_w[71:64]), .m14(cb_win_w[79:72]),
    .m20(cb_win_w[87:80]), .m21(cb_win_w[95:88]), .m22(cb_win_w[103:96]), .m23(cb_win_w[111:104]), .m24(cb_win_w[119:112]),
    .m30(cb_win_w[127:120]), .m31(cb_win_w[135:128]), .m32(cb_win_w[143:136]), .m33(cb_win_w[151:144]), .m34(cb_win_w[159:152]),
    .m40(cb_win_w[167:160]), .m41(cb_win_w[175:168]), .m42(cb_win_w[183:176]), .m43(cb_win_w[191:184]), .m44(cb_win_w[199:192]),
    .center_leaf(cb_center_leaf_w)
);

stream_plane_causal5x5_current_window #(
    .H_DISP(H_DISP), .V_DISP(V_DISP), .REPLICATE_CENTER(1)
) u_cr_window
(
    .clk(clk), .rst_n(rst_n), .frame_clr(frame_clr), .din_vld(s0_de_r), .din(s0_cr_r),
    .out_vld(cr_win_de_w),
    .m00(cr_win_w[7:0]), .m01(cr_win_w[15:8]), .m02(cr_win_w[23:16]), .m03(cr_win_w[31:24]), .m04(cr_win_w[39:32]),
    .m10(cr_win_w[47:40]), .m11(cr_win_w[55:48]), .m12(cr_win_w[63:56]), .m13(cr_win_w[71:64]), .m14(cr_win_w[79:72]),
    .m20(cr_win_w[87:80]), .m21(cr_win_w[95:88]), .m22(cr_win_w[103:96]), .m23(cr_win_w[111:104]), .m24(cr_win_w[119:112]),
    .m30(cr_win_w[127:120]), .m31(cr_win_w[135:128]), .m32(cr_win_w[143:136]), .m33(cr_win_w[151:144]), .m34(cr_win_w[159:152]),
    .m40(cr_win_w[167:160]), .m41(cr_win_w[175:168]), .m42(cr_win_w[183:176]), .m43(cr_win_w[191:184]), .m44(cr_win_w[199:192]),
    .center_leaf(cr_center_leaf_w)
);

stream_plane_causal5x5_current_window #(.H_DISP(H_DISP), .V_DISP(V_DISP)) u_r_window
(
    .clk(clk), .rst_n(rst_n), .frame_clr(frame_clr), .din_vld(s0_de_r), .din(s0_r_r),
    .out_vld(r_win_de_w),
    .m00(r_win_w[7:0]), .m01(r_win_w[15:8]), .m02(r_win_w[23:16]), .m03(r_win_w[31:24]), .m04(r_win_w[39:32]),
    .m10(r_win_w[47:40]), .m11(r_win_w[55:48]), .m12(r_win_w[63:56]), .m13(r_win_w[71:64]), .m14(r_win_w[79:72]),
    .m20(r_win_w[87:80]), .m21(r_win_w[95:88]), .m22(r_win_w[103:96]), .m23(r_win_w[111:104]), .m24(r_win_w[119:112]),
    .m30(r_win_w[127:120]), .m31(r_win_w[135:128]), .m32(r_win_w[143:136]), .m33(r_win_w[151:144]), .m34(r_win_w[159:152]),
    .m40(r_win_w[167:160]), .m41(r_win_w[175:168]), .m42(r_win_w[183:176]), .m43(r_win_w[191:184]), .m44(r_win_w[199:192]),
    .center_leaf()
);

stream_plane_causal5x5_current_window #(.H_DISP(H_DISP), .V_DISP(V_DISP)) u_g_window
(
    .clk(clk), .rst_n(rst_n), .frame_clr(frame_clr), .din_vld(s0_de_r), .din(s0_g_r),
    .out_vld(g_win_de_w),
    .m00(g_win_w[7:0]), .m01(g_win_w[15:8]), .m02(g_win_w[23:16]), .m03(g_win_w[31:24]), .m04(g_win_w[39:32]),
    .m10(g_win_w[47:40]), .m11(g_win_w[55:48]), .m12(g_win_w[63:56]), .m13(g_win_w[71:64]), .m14(g_win_w[79:72]),
    .m20(g_win_w[87:80]), .m21(g_win_w[95:88]), .m22(g_win_w[103:96]), .m23(g_win_w[111:104]), .m24(g_win_w[119:112]),
    .m30(g_win_w[127:120]), .m31(g_win_w[135:128]), .m32(g_win_w[143:136]), .m33(g_win_w[151:144]), .m34(g_win_w[159:152]),
    .m40(g_win_w[167:160]), .m41(g_win_w[175:168]), .m42(g_win_w[183:176]), .m43(g_win_w[191:184]), .m44(g_win_w[199:192]),
    .center_leaf()
);

stream_plane_causal5x5_current_window #(.H_DISP(H_DISP), .V_DISP(V_DISP)) u_b_window
(
    .clk(clk), .rst_n(rst_n), .frame_clr(frame_clr), .din_vld(s0_de_r), .din(s0_b_r),
    .out_vld(b_win_de_w),
    .m00(b_win_w[7:0]), .m01(b_win_w[15:8]), .m02(b_win_w[23:16]), .m03(b_win_w[31:24]), .m04(b_win_w[39:32]),
    .m10(b_win_w[47:40]), .m11(b_win_w[55:48]), .m12(b_win_w[63:56]), .m13(b_win_w[71:64]), .m14(b_win_w[79:72]),
    .m20(b_win_w[87:80]), .m21(b_win_w[95:88]), .m22(b_win_w[103:96]), .m23(b_win_w[111:104]), .m24(b_win_w[119:112]),
    .m30(b_win_w[127:120]), .m31(b_win_w[135:128]), .m32(b_win_w[143:136]), .m33(b_win_w[151:144]), .m34(b_win_w[159:152]),
    .m40(b_win_w[167:160]), .m41(b_win_w[175:168]), .m42(b_win_w[183:176]), .m43(b_win_w[191:184]), .m44(b_win_w[199:192]),
    .center_leaf()
);

wire win_de_w = y_win_de_w & cb_win_de_w & cr_win_de_w & r_win_de_w & g_win_de_w & b_win_de_w;

reg [10:0] win_x_cnt_r;
reg [10:0] win_y_cnt_r;
integer i;

localparam [10:0] CORE_H_LAST_COL = H_DISP - 1;
localparam [10:0] CORE_V_LAST_ROW = V_DISP - 1;

reg        s1_de_r;
reg [10:0] s1_x_r;
reg [10:0] s1_y_r;
reg [7:0]  s1_y_center_r;
reg [7:0]  s1_cb_center_r;
reg [7:0]  s1_cr_center_r;
reg [7:0]  s1_r_r;
reg [7:0]  s1_g_r;
reg [7:0]  s1_b_r;
reg [199:0] s1_cb_pick_r;
reg [199:0] s1_cr_pick_r;
reg        s1_neutral_r;
reg        s1_startup_bypass_r;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        win_x_cnt_r <= 11'd0;
        win_y_cnt_r <= 11'd0;
        s1_de_r <= 1'b0;
        s1_x_r <= 11'd0; s1_y_r <= 11'd0;
        s1_y_center_r <= 8'd0; s1_cb_center_r <= 8'd0; s1_cr_center_r <= 8'd0;
        s1_r_r <= 8'd0; s1_g_r <= 8'd0; s1_b_r <= 8'd0;
        s1_cb_pick_r <= 200'd0; s1_cr_pick_r <= 200'd0;
        s1_neutral_r <= 1'b0;
        s1_startup_bypass_r <= 1'b0;
    end else if (frame_clr) begin
        win_x_cnt_r <= 11'd0;
        win_y_cnt_r <= 11'd0;
        s1_de_r <= 1'b0;
        s1_x_r <= 11'd0; s1_y_r <= 11'd0;
        s1_y_center_r <= 8'd0; s1_cb_center_r <= 8'd0; s1_cr_center_r <= 8'd0;
        s1_r_r <= 8'd0; s1_g_r <= 8'd0; s1_b_r <= 8'd0;
        s1_cb_pick_r <= 200'd0; s1_cr_pick_r <= 200'd0;
        s1_neutral_r <= 1'b0;
        s1_startup_bypass_r <= 1'b0;
    end else begin
        s1_de_r <= win_de_w;
        if (win_de_w) begin
            s1_x_r <= win_x_cnt_r;
            s1_y_r <= win_y_cnt_r;
            s1_y_center_r <= y_win_w[199:192];
            s1_cb_center_r <= cb_win_w[199:192];
            s1_cr_center_r <= cr_win_w[199:192];
            s1_r_r <= r_win_w[199:192];
            s1_g_r <= g_win_w[199:192];
            s1_b_r <= b_win_w[199:192];
            s1_startup_bypass_r <= (win_x_cnt_r < STARTUP_BYPASS_LEFT_PX) || (win_y_cnt_r < STARTUP_BYPASS_TOP_PX);
            s1_neutral_r <=
                (NEUTRAL_GUARD_ENABLE != 0) &&
                (y_win_w[199:192] >= 8'd64) &&
                (y_win_w[199:192] <= 8'd220) &&
                ((max3_u8(r_win_w[199:192], g_win_w[199:192], b_win_w[199:192]) -
                  min3_u8(r_win_w[199:192], g_win_w[199:192], b_win_w[199:192])) <= NEUTRAL_SAT_TH) &&
                (chroma_abs_from_128(cb_win_w[199:192]) <= NEUTRAL_CHROMA_TH) &&
                (chroma_abs_from_128(cr_win_w[199:192]) <= NEUTRAL_CHROMA_TH);

            for (i = 0; i < 25; i = i + 1) begin
                if ((abs_diff_u8(y_win_w[i*8 +: 8], y_center_leaf_w[i*8 +: 8]) <= Y_RANGE_TH) &&
                    (abs_diff_u8(cb_win_w[i*8 +: 8], cb_center_leaf_w[i*8 +: 8]) <= CHROMA_RANGE_TH) &&
                    (abs_diff_u8(cr_win_w[i*8 +: 8], cr_center_leaf_w[i*8 +: 8]) <= CHROMA_RANGE_TH)) begin
                    s1_cb_pick_r[i*8 +: 8] <= cb_win_w[i*8 +: 8];
                    s1_cr_pick_r[i*8 +: 8] <= cr_win_w[i*8 +: 8];
                end else begin
                    s1_cb_pick_r[i*8 +: 8] <= cb_center_leaf_w[i*8 +: 8];
                    s1_cr_pick_r[i*8 +: 8] <= cr_center_leaf_w[i*8 +: 8];
                end
            end

            if (win_x_cnt_r == CORE_H_LAST_COL) begin
                win_x_cnt_r <= 11'd0;
                if (win_y_cnt_r == CORE_V_LAST_ROW)
                    win_y_cnt_r <= 11'd0;
                else
                    win_y_cnt_r <= win_y_cnt_r + 11'd1;
            end else begin
                win_x_cnt_r <= win_x_cnt_r + 11'd1;
            end
        end else begin
            s1_x_r <= 11'd0; s1_y_r <= 11'd0;
            s1_y_center_r <= 8'd0; s1_cb_center_r <= 8'd0; s1_cr_center_r <= 8'd0;
            s1_r_r <= 8'd0; s1_g_r <= 8'd0; s1_b_r <= 8'd0;
            s1_cb_pick_r <= 200'd0; s1_cr_pick_r <= 200'd0;
            s1_neutral_r <= 1'b0;
            s1_startup_bypass_r <= 1'b0;
        end
    end
end

reg        s2_de_r;
reg [7:0]  s2_y_center_r;
reg [7:0]  s2_cb_center_r;
reg [7:0]  s2_cr_center_r;
reg [7:0]  s2_r_r;
reg [7:0]  s2_g_r;
reg [7:0]  s2_b_r;
reg [12:0] s2_cb_row0_r, s2_cb_row1_r, s2_cb_row2_r, s2_cb_row3_r, s2_cb_row4_r;
reg [12:0] s2_cr_row0_r, s2_cr_row1_r, s2_cr_row2_r, s2_cr_row3_r, s2_cr_row4_r;
reg        s2_neutral_r;
reg        s2_startup_bypass_r;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        s2_de_r <= 1'b0;
        s2_y_center_r <= 8'd0; s2_cb_center_r <= 8'd0; s2_cr_center_r <= 8'd0;
        s2_r_r <= 8'd0; s2_g_r <= 8'd0; s2_b_r <= 8'd0;
        s2_cb_row0_r <= 13'd0; s2_cb_row1_r <= 13'd0; s2_cb_row2_r <= 13'd0; s2_cb_row3_r <= 13'd0; s2_cb_row4_r <= 13'd0;
        s2_cr_row0_r <= 13'd0; s2_cr_row1_r <= 13'd0; s2_cr_row2_r <= 13'd0; s2_cr_row3_r <= 13'd0; s2_cr_row4_r <= 13'd0;
        s2_neutral_r <= 1'b0; s2_startup_bypass_r <= 1'b0;
    end else if (frame_clr) begin
        s2_de_r <= 1'b0;
        s2_y_center_r <= 8'd0; s2_cb_center_r <= 8'd0; s2_cr_center_r <= 8'd0;
        s2_r_r <= 8'd0; s2_g_r <= 8'd0; s2_b_r <= 8'd0;
        s2_cb_row0_r <= 13'd0; s2_cb_row1_r <= 13'd0; s2_cb_row2_r <= 13'd0; s2_cb_row3_r <= 13'd0; s2_cb_row4_r <= 13'd0;
        s2_cr_row0_r <= 13'd0; s2_cr_row1_r <= 13'd0; s2_cr_row2_r <= 13'd0; s2_cr_row3_r <= 13'd0; s2_cr_row4_r <= 13'd0;
        s2_neutral_r <= 1'b0; s2_startup_bypass_r <= 1'b0;
    end else begin
        s2_de_r <= s1_de_r;
        s2_y_center_r <= s1_de_r ? s1_y_center_r : 8'd0;
        s2_cb_center_r <= s1_de_r ? s1_cb_center_r : 8'd0;
        s2_cr_center_r <= s1_de_r ? s1_cr_center_r : 8'd0;
        s2_r_r <= s1_de_r ? s1_r_r : 8'd0;
        s2_g_r <= s1_de_r ? s1_g_r : 8'd0;
        s2_b_r <= s1_de_r ? s1_b_r : 8'd0;
        s2_cb_row0_r <= s1_de_r ? row5_weighted(s1_cb_pick_r[39:0]) : 13'd0;
        s2_cb_row1_r <= s1_de_r ? row5_weighted(s1_cb_pick_r[79:40]) : 13'd0;
        s2_cb_row2_r <= s1_de_r ? row5_weighted(s1_cb_pick_r[119:80]) : 13'd0;
        s2_cb_row3_r <= s1_de_r ? row5_weighted(s1_cb_pick_r[159:120]) : 13'd0;
        s2_cb_row4_r <= s1_de_r ? row5_weighted(s1_cb_pick_r[199:160]) : 13'd0;
        s2_cr_row0_r <= s1_de_r ? row5_weighted(s1_cr_pick_r[39:0]) : 13'd0;
        s2_cr_row1_r <= s1_de_r ? row5_weighted(s1_cr_pick_r[79:40]) : 13'd0;
        s2_cr_row2_r <= s1_de_r ? row5_weighted(s1_cr_pick_r[119:80]) : 13'd0;
        s2_cr_row3_r <= s1_de_r ? row5_weighted(s1_cr_pick_r[159:120]) : 13'd0;
        s2_cr_row4_r <= s1_de_r ? row5_weighted(s1_cr_pick_r[199:160]) : 13'd0;
        s2_neutral_r <= s1_de_r ? s1_neutral_r : 1'b0;
        s2_startup_bypass_r <= s1_de_r ? s1_startup_bypass_r : 1'b0;
    end
end

reg        s3_de_r;
reg [7:0]  s3_cb_center_r;
reg [7:0]  s3_cr_center_r;
reg [7:0]  s3_r_r;
reg [7:0]  s3_g_r;
reg [7:0]  s3_b_r;
reg [15:0] s3_cb_sum_r;
reg [15:0] s3_cr_sum_r;
reg        s3_neutral_r;
reg        s3_startup_bypass_r;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        s3_de_r <= 1'b0;
        s3_cb_center_r <= 8'd0; s3_cr_center_r <= 8'd0;
        s3_r_r <= 8'd0; s3_g_r <= 8'd0; s3_b_r <= 8'd0;
        s3_cb_sum_r <= 16'd0; s3_cr_sum_r <= 16'd0;
        s3_neutral_r <= 1'b0; s3_startup_bypass_r <= 1'b0;
    end else if (frame_clr) begin
        s3_de_r <= 1'b0;
        s3_cb_center_r <= 8'd0; s3_cr_center_r <= 8'd0;
        s3_r_r <= 8'd0; s3_g_r <= 8'd0; s3_b_r <= 8'd0;
        s3_cb_sum_r <= 16'd0; s3_cr_sum_r <= 16'd0;
        s3_neutral_r <= 1'b0; s3_startup_bypass_r <= 1'b0;
    end else begin
        s3_de_r <= s2_de_r;
        s3_cb_center_r <= s2_de_r ? s2_cb_center_r : 8'd0;
        s3_cr_center_r <= s2_de_r ? s2_cr_center_r : 8'd0;
        s3_r_r <= s2_de_r ? s2_r_r : 8'd0;
        s3_g_r <= s2_de_r ? s2_g_r : 8'd0;
        s3_b_r <= s2_de_r ? s2_b_r : 8'd0;
        s3_cb_sum_r <= s2_de_r ? ({3'd0, s2_cb_row0_r} + {2'd0, s2_cb_row1_r, 1'b0} + {1'd0, s2_cb_row2_r, 2'b00} + {2'd0, s2_cb_row3_r, 1'b0} + {3'd0, s2_cb_row4_r}) : 16'd0;
        s3_cr_sum_r <= s2_de_r ? ({3'd0, s2_cr_row0_r} + {2'd0, s2_cr_row1_r, 1'b0} + {1'd0, s2_cr_row2_r, 2'b00} + {2'd0, s2_cr_row3_r, 1'b0} + {3'd0, s2_cr_row4_r}) : 16'd0;
        s3_neutral_r <= s2_de_r ? s2_neutral_r : 1'b0;
        s3_startup_bypass_r <= s2_de_r ? s2_startup_bypass_r : 1'b0;
    end
end

reg        s4_de_r;
reg [7:0]  s4_cb_center_r;
reg [7:0]  s4_cr_center_r;
reg [7:0]  s4_r_r;
reg [7:0]  s4_g_r;
reg [7:0]  s4_b_r;
reg [7:0]  s4_cb_filtered_r;
reg [7:0]  s4_cr_filtered_r;
reg        s4_neutral_r;
reg        s4_startup_bypass_r;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        s4_de_r <= 1'b0;
        s4_cb_center_r <= 8'd0; s4_cr_center_r <= 8'd0;
        s4_r_r <= 8'd0; s4_g_r <= 8'd0; s4_b_r <= 8'd0;
        s4_cb_filtered_r <= 8'd0; s4_cr_filtered_r <= 8'd0;
        s4_neutral_r <= 1'b0; s4_startup_bypass_r <= 1'b0;
    end else if (frame_clr) begin
        s4_de_r <= 1'b0;
        s4_cb_center_r <= 8'd0; s4_cr_center_r <= 8'd0;
        s4_r_r <= 8'd0; s4_g_r <= 8'd0; s4_b_r <= 8'd0;
        s4_cb_filtered_r <= 8'd0; s4_cr_filtered_r <= 8'd0;
        s4_neutral_r <= 1'b0; s4_startup_bypass_r <= 1'b0;
    end else begin
        s4_de_r <= s3_de_r;
        s4_cb_center_r <= s3_de_r ? s3_cb_center_r : 8'd0;
        s4_cr_center_r <= s3_de_r ? s3_cr_center_r : 8'd0;
        s4_r_r <= s3_de_r ? s3_r_r : 8'd0;
        s4_g_r <= s3_de_r ? s3_g_r : 8'd0;
        s4_b_r <= s3_de_r ? s3_b_r : 8'd0;
        s4_cb_filtered_r <= s3_de_r ? div100_round_u16(s3_cb_sum_r) : 8'd0;
        s4_cr_filtered_r <= s3_de_r ? div100_round_u16(s3_cr_sum_r) : 8'd0;
        s4_neutral_r <= s3_de_r ? s3_neutral_r : 1'b0;
        s4_startup_bypass_r <= s3_de_r ? s3_startup_bypass_r : 1'b0;
    end
end

wire signed [8:0] s5_dcb_raw_w = $signed({1'b0, s4_cb_filtered_r}) - $signed({1'b0, s4_cb_center_r});
wire signed [8:0] s5_dcr_raw_w = $signed({1'b0, s4_cr_filtered_r}) - $signed({1'b0, s4_cr_center_r});
wire signed [8:0] s5_dcb_clamped_w = clamp_signed9(s5_dcb_raw_w, DELTA_CLAMP);
wire signed [8:0] s5_dcr_clamped_w = clamp_signed9(s5_dcr_raw_w, DELTA_CLAMP);
wire signed [8:0] s5_dcb_guarded_w = s4_neutral_r ? neutral_outward_limit(s5_dcb_clamped_w, s4_cb_center_r) : s5_dcb_clamped_w;
wire signed [8:0] s5_dcr_guarded_w = s4_neutral_r ? neutral_outward_limit(s5_dcr_clamped_w, s4_cr_center_r) : s5_dcr_clamped_w;

reg        s5_de_r;
reg [7:0]  s5_r_r;
reg [7:0]  s5_g_r;
reg [7:0]  s5_b_r;
reg signed [8:0] s5_dcb_r;
reg signed [8:0] s5_dcr_r;
reg        s5_startup_bypass_r;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        s5_de_r <= 1'b0;
        s5_r_r <= 8'd0; s5_g_r <= 8'd0; s5_b_r <= 8'd0;
        s5_dcb_r <= 9'sd0; s5_dcr_r <= 9'sd0;
        s5_startup_bypass_r <= 1'b0;
    end else if (frame_clr) begin
        s5_de_r <= 1'b0;
        s5_r_r <= 8'd0; s5_g_r <= 8'd0; s5_b_r <= 8'd0;
        s5_dcb_r <= 9'sd0; s5_dcr_r <= 9'sd0;
        s5_startup_bypass_r <= 1'b0;
    end else begin
        s5_de_r <= s4_de_r;
        s5_r_r <= s4_de_r ? s4_r_r : 8'd0;
        s5_g_r <= s4_de_r ? s4_g_r : 8'd0;
        s5_b_r <= s4_de_r ? s4_b_r : 8'd0;
        s5_dcb_r <= (s4_de_r && !s4_startup_bypass_r) ? s5_dcb_guarded_w : 9'sd0;
        s5_dcr_r <= (s4_de_r && !s4_startup_bypass_r) ? s5_dcr_guarded_w : 9'sd0;
        s5_startup_bypass_r <= s4_de_r ? s4_startup_bypass_r : 1'b0;
    end
end

reg        s6_de_r;
reg [7:0]  s6_r_r;
reg [7:0]  s6_g_r;
reg [7:0]  s6_b_r;
reg signed [17:0] s6_dcb_prod_r;
reg signed [17:0] s6_dcr_prod_r;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        s6_de_r <= 1'b0;
        s6_r_r <= 8'd0; s6_g_r <= 8'd0; s6_b_r <= 8'd0;
        s6_dcb_prod_r <= 18'sd0; s6_dcr_prod_r <= 18'sd0;
    end else if (frame_clr) begin
        s6_de_r <= 1'b0;
        s6_r_r <= 8'd0; s6_g_r <= 8'd0; s6_b_r <= 8'd0;
        s6_dcb_prod_r <= 18'sd0; s6_dcr_prod_r <= 18'sd0;
    end else begin
        s6_de_r <= s5_de_r;
        s6_r_r <= s5_de_r ? s5_r_r : 8'd0;
        s6_g_r <= s5_de_r ? s5_g_r : 8'd0;
        s6_b_r <= s5_de_r ? s5_b_r : 8'd0;
        s6_dcb_prod_r <= s5_dcb_r * $signed({1'b0, ALPHA_Q8});
        s6_dcr_prod_r <= s5_dcr_r * $signed({1'b0, ALPHA_Q8});
    end
end

wire signed [8:0] s7_dcb_scaled_w = (s6_dcb_prod_r + 18'sd128) >>> 8;
wire signed [8:0] s7_dcr_scaled_w = (s6_dcr_prod_r + 18'sd128) >>> 8;

reg        s7_de_r;
reg [7:0]  s7_r_r;
reg [7:0]  s7_g_r;
reg [7:0]  s7_b_r;
reg signed [8:0] s7_dcb_r;
reg signed [8:0] s7_dcr_r;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        s7_de_r <= 1'b0;
        s7_r_r <= 8'd0; s7_g_r <= 8'd0; s7_b_r <= 8'd0;
        s7_dcb_r <= 9'sd0; s7_dcr_r <= 9'sd0;
    end else if (frame_clr) begin
        s7_de_r <= 1'b0;
        s7_r_r <= 8'd0; s7_g_r <= 8'd0; s7_b_r <= 8'd0;
        s7_dcb_r <= 9'sd0; s7_dcr_r <= 9'sd0;
    end else begin
        s7_de_r <= s6_de_r;
        s7_r_r <= s6_de_r ? s6_r_r : 8'd0;
        s7_g_r <= s6_de_r ? s6_g_r : 8'd0;
        s7_b_r <= s6_de_r ? s6_b_r : 8'd0;
        s7_dcb_r <= s7_dcb_scaled_w;
        s7_dcr_r <= s7_dcr_scaled_w;
    end
end

reg        s8_de_r;
reg [7:0]  s8_r_r;
reg [7:0]  s8_g_r;
reg [7:0]  s8_b_r;
reg signed [18:0] s8_dr_prod_r;
reg signed [18:0] s8_db_prod_r;
reg signed [18:0] s8_dg_cb_prod_r;
reg signed [18:0] s8_dg_cr_prod_r;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        s8_de_r <= 1'b0;
        s8_r_r <= 8'd0; s8_g_r <= 8'd0; s8_b_r <= 8'd0;
        s8_dr_prod_r <= 19'sd0; s8_db_prod_r <= 19'sd0;
        s8_dg_cb_prod_r <= 19'sd0; s8_dg_cr_prod_r <= 19'sd0;
    end else if (frame_clr) begin
        s8_de_r <= 1'b0;
        s8_r_r <= 8'd0; s8_g_r <= 8'd0; s8_b_r <= 8'd0;
        s8_dr_prod_r <= 19'sd0; s8_db_prod_r <= 19'sd0;
        s8_dg_cb_prod_r <= 19'sd0; s8_dg_cr_prod_r <= 19'sd0;
    end else begin
        s8_de_r <= s7_de_r;
        s8_r_r <= s7_de_r ? s7_r_r : 8'd0;
        s8_g_r <= s7_de_r ? s7_g_r : 8'd0;
        s8_b_r <= s7_de_r ? s7_b_r : 8'd0;
        s8_dr_prod_r <= s7_dcr_r * 10'sd359;
        s8_db_prod_r <= s7_dcb_r * 10'sd454;
        s8_dg_cb_prod_r <= s7_dcb_r * 9'sd88;
        s8_dg_cr_prod_r <= s7_dcr_r * 9'sd183;
    end
end

reg        s9_de_r;
reg [7:0]  s9_r_r;
reg [7:0]  s9_g_r;
reg [7:0]  s9_b_r;
reg signed [18:0] s9_dr_prod_r;
reg signed [18:0] s9_db_prod_r;
reg signed [18:0] s9_dg_sum_r;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        s9_de_r <= 1'b0;
        s9_r_r <= 8'd0; s9_g_r <= 8'd0; s9_b_r <= 8'd0;
        s9_dr_prod_r <= 19'sd0; s9_db_prod_r <= 19'sd0; s9_dg_sum_r <= 19'sd0;
    end else if (frame_clr) begin
        s9_de_r <= 1'b0;
        s9_r_r <= 8'd0; s9_g_r <= 8'd0; s9_b_r <= 8'd0;
        s9_dr_prod_r <= 19'sd0; s9_db_prod_r <= 19'sd0; s9_dg_sum_r <= 19'sd0;
    end else begin
        s9_de_r <= s8_de_r;
        s9_r_r <= s8_de_r ? s8_r_r : 8'd0;
        s9_g_r <= s8_de_r ? s8_g_r : 8'd0;
        s9_b_r <= s8_de_r ? s8_b_r : 8'd0;
        s9_dr_prod_r <= s8_dr_prod_r + 19'sd128;
        s9_db_prod_r <= s8_db_prod_r + 19'sd128;
        s9_dg_sum_r <= s8_dg_cb_prod_r + s8_dg_cr_prod_r + 19'sd128;
    end
end

wire signed [10:0] s10_dr_w = s9_dr_prod_r >>> 8;
wire signed [10:0] s10_db_w = s9_db_prod_r >>> 8;
wire signed [10:0] s10_dg_w = -(s9_dg_sum_r >>> 8);
wire [7:0] s10_out_r_w = clip_u8($signed({1'b0, s9_r_r}) + s10_dr_w);
wire [7:0] s10_out_g_w = clip_u8($signed({1'b0, s9_g_r}) + s10_dg_w);
wire [7:0] s10_out_b_w = clip_u8($signed({1'b0, s9_b_r}) + s10_db_w);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        out_de <= 1'b0;
        out_rgb <= 24'd0;
    end else if (frame_clr) begin
        out_de <= 1'b0;
        out_rgb <= 24'd0;
    end else begin
        out_de <= s9_de_r;
        out_rgb <= s9_de_r ? {s10_out_r_w, s10_out_g_w, s10_out_b_w} : 24'd0;
    end
end

endmodule
