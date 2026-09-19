module stream_plane_box4_align
#(
    parameter H_DISP = 1280,
    parameter V_DISP = 720,
    parameter ENABLE = 1
)
(
    input   wire          clk,
    input   wire          rst_n,
    input   wire          frame_clr,
    input   wire          din_vld,
    input   wire  [7:0]   din,
    output  wire          out_vld,
    output  wire  [7:0]   out_center,
    output  wire  [7:0]   out_box2,
    output  wire  [7:0]   out_box4
);

    localparam [10:0] H_LAST_COL = H_DISP - 1;

    function [31:0] clamp4_left_u8;
        input [10:0] col;
        input [7:0] cur;
        input [7:0] h0;
        input [7:0] h1;
        input [7:0] h2;
        input [7:0] h3;
        reg   [7:0] oldest;
        reg   [7:0] t0;
        reg   [7:0] t1;
        reg   [7:0] t2;
        reg   [7:0] t3;
        begin
            if (col == 11'd0)
                oldest = cur;
            else if (col == 11'd1)
                oldest = h0;
            else if (col == 11'd2)
                oldest = h1;
            else if (col == 11'd3)
                oldest = h2;
            else
                oldest = h3;

            t0 = (col == 11'd0) ? oldest : h0;
            t1 = (col < 11'd2) ? oldest : h1;
            t2 = (col < 11'd3) ? oldest : h2;
            t3 = (col < 11'd4) ? oldest : h3;
            clamp4_left_u8 = {t0, t1, t2, t3};
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

    reg [7:0] r1_h0_r;
    reg [7:0] r1_h1_r;
    reg [7:0] r1_h2_r;
    reg [7:0] r1_h3_r;
    reg [7:0] r2_h0_r;
    reg [7:0] r2_h1_r;
    reg [7:0] r2_h2_r;
    reg [7:0] r2_h3_r;
    reg [7:0] r3_h0_r;
    reg [7:0] r3_h1_r;
    reg [7:0] r3_h2_r;
    reg [7:0] r3_h3_r;
    reg [7:0] r4_h0_r;
    reg [7:0] r4_h1_r;
    reg [7:0] r4_h2_r;
    reg [7:0] r4_h3_r;

    reg         sum_s1_vld_r;
    reg  [7:0] center_s1_r;
    reg  [9:0] box2_sum_s1_r;
    reg  [9:0] row1_sum_s1_r;
    reg  [9:0] row2_sum_s1_r;
    reg  [9:0] row3_sum_s1_r;
    reg  [9:0] row4_sum_s1_r;
    reg         sum_s2_vld_r;
    reg  [7:0] center_s2_r;
    reg  [7:0] box2_s2_r;
    reg  [7:0] box4_s2_r;
    reg  [12:0] pipe_vld_r;
    reg  [7:0]  center_pipe0_r;
    reg  [7:0]  center_pipe1_r;
    reg  [7:0]  center_pipe2_r;
    reg  [7:0]  center_pipe3_r;
    reg  [7:0]  center_pipe4_r;
    reg  [7:0]  center_pipe5_r;
    reg  [7:0]  center_pipe6_r;
    reg  [7:0]  center_pipe7_r;
    reg  [7:0]  center_pipe8_r;
    reg  [7:0]  center_pipe9_r;
    reg  [7:0]  center_pipe10_r;
    reg  [7:0]  center_pipe11_r;
    reg  [7:0]  center_pipe12_r;
    reg  [7:0]  box2_pipe0_r;
    reg  [7:0]  box2_pipe1_r;
    reg  [7:0]  box2_pipe2_r;
    reg  [7:0]  box2_pipe3_r;
    reg  [7:0]  box2_pipe4_r;
    reg  [7:0]  box2_pipe5_r;
    reg  [7:0]  box2_pipe6_r;
    reg  [7:0]  box2_pipe7_r;
    reg  [7:0]  box2_pipe8_r;
    reg  [7:0]  box2_pipe9_r;
    reg  [7:0]  box2_pipe10_r;
    reg  [7:0]  box2_pipe11_r;
    reg  [7:0]  box2_pipe12_r;
    reg  [7:0]  box4_pipe0_r;
    reg  [7:0]  box4_pipe1_r;
    reg  [7:0]  box4_pipe2_r;
    reg  [7:0]  box4_pipe3_r;
    reg  [7:0]  box4_pipe4_r;
    reg  [7:0]  box4_pipe5_r;
    reg  [7:0]  box4_pipe6_r;
    reg  [7:0]  box4_pipe7_r;
    reg  [7:0]  box4_pipe8_r;
    reg  [7:0]  box4_pipe9_r;
    reg  [7:0]  box4_pipe10_r;
    reg  [7:0]  box4_pipe11_r;
    reg  [7:0]  box4_pipe12_r;

    wire [7:0] row1_src_w = (row_d4 < 12'd1) ? 8'd0 : line1_q_d3;
    wire [7:0] row2_src_w = (row_d4 < 12'd2) ? 8'd0 : line2_q_d2;
    wire [7:0] row3_src_w = (row_d4 < 12'd3) ? 8'd0 : line3_q_d1;
    wire [7:0] row4_src_w = (row_d4 < 12'd4) ? 8'd0 : line4_q;

    wire [7:0] r1_t0_w = r1_h0_r;
    wire [7:0] r1_t1_w = r1_h1_r;
    wire [7:0] r1_t2_w = r1_h2_r;
    wire [7:0] r1_t3_w = r1_h3_r;
    wire [7:0] r2_t0_w = r2_h0_r;
    wire [7:0] r2_t1_w = r2_h1_r;
    wire [7:0] r2_t2_w = r2_h2_r;
    wire [7:0] r2_t3_w = r2_h3_r;
    wire [7:0] r3_t0_w = r3_h0_r;
    wire [7:0] r3_t1_w = r3_h1_r;
    wire [7:0] r3_t2_w = r3_h2_r;
    wire [7:0] r3_t3_w = r3_h3_r;
    wire [7:0] r4_t0_w = r4_h0_r;
    wire [7:0] r4_t1_w = r4_h1_r;
    wire [7:0] r4_t2_w = r4_h2_r;
    wire [7:0] r4_t3_w = r4_h3_r;

    wire [11:0] box4_sum_s2_w =
        {2'd0, row1_sum_s1_r} + {2'd0, row2_sum_s1_r} +
        {2'd0, row3_sum_s1_r} + {2'd0, row4_sum_s1_r};

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
            r1_h0_r <= 8'd0; r1_h1_r <= 8'd0; r1_h2_r <= 8'd0; r1_h3_r <= 8'd0;
            r2_h0_r <= 8'd0; r2_h1_r <= 8'd0; r2_h2_r <= 8'd0; r2_h3_r <= 8'd0;
            r3_h0_r <= 8'd0; r3_h1_r <= 8'd0; r3_h2_r <= 8'd0; r3_h3_r <= 8'd0;
            r4_h0_r <= 8'd0; r4_h1_r <= 8'd0; r4_h2_r <= 8'd0; r4_h3_r <= 8'd0;
            sum_s1_vld_r <= 1'b0;
            center_s1_r <= 8'd0;
            box2_sum_s1_r <= 10'd0;
            row1_sum_s1_r <= 10'd0;
            row2_sum_s1_r <= 10'd0;
            row3_sum_s1_r <= 10'd0;
            row4_sum_s1_r <= 10'd0;
            sum_s2_vld_r <= 1'b0;
            center_s2_r <= 8'd0;
            box2_s2_r <= 8'd0;
            box4_s2_r <= 8'd0;
            pipe_vld_r <= 13'd0;
            center_pipe0_r <= 8'd0; center_pipe1_r <= 8'd0; center_pipe2_r <= 8'd0; center_pipe3_r <= 8'd0;
            center_pipe4_r <= 8'd0; center_pipe5_r <= 8'd0; center_pipe6_r <= 8'd0; center_pipe7_r <= 8'd0;
            center_pipe8_r <= 8'd0; center_pipe9_r <= 8'd0; center_pipe10_r <= 8'd0; center_pipe11_r <= 8'd0; center_pipe12_r <= 8'd0;
            box2_pipe0_r <= 8'd0; box2_pipe1_r <= 8'd0; box2_pipe2_r <= 8'd0; box2_pipe3_r <= 8'd0;
            box2_pipe4_r <= 8'd0; box2_pipe5_r <= 8'd0; box2_pipe6_r <= 8'd0; box2_pipe7_r <= 8'd0;
            box2_pipe8_r <= 8'd0; box2_pipe9_r <= 8'd0; box2_pipe10_r <= 8'd0; box2_pipe11_r <= 8'd0; box2_pipe12_r <= 8'd0;
            box4_pipe0_r <= 8'd0; box4_pipe1_r <= 8'd0; box4_pipe2_r <= 8'd0; box4_pipe3_r <= 8'd0;
            box4_pipe4_r <= 8'd0; box4_pipe5_r <= 8'd0; box4_pipe6_r <= 8'd0; box4_pipe7_r <= 8'd0;
            box4_pipe8_r <= 8'd0; box4_pipe9_r <= 8'd0; box4_pipe10_r <= 8'd0; box4_pipe11_r <= 8'd0; box4_pipe12_r <= 8'd0;
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
            r1_h0_r <= 8'd0; r1_h1_r <= 8'd0; r1_h2_r <= 8'd0; r1_h3_r <= 8'd0;
            r2_h0_r <= 8'd0; r2_h1_r <= 8'd0; r2_h2_r <= 8'd0; r2_h3_r <= 8'd0;
            r3_h0_r <= 8'd0; r3_h1_r <= 8'd0; r3_h2_r <= 8'd0; r3_h3_r <= 8'd0;
            r4_h0_r <= 8'd0; r4_h1_r <= 8'd0; r4_h2_r <= 8'd0; r4_h3_r <= 8'd0;
            sum_s1_vld_r <= 1'b0;
            center_s1_r <= 8'd0;
            box2_sum_s1_r <= 10'd0;
            row1_sum_s1_r <= 10'd0;
            row2_sum_s1_r <= 10'd0;
            row3_sum_s1_r <= 10'd0;
            row4_sum_s1_r <= 10'd0;
            sum_s2_vld_r <= 1'b0;
            center_s2_r <= 8'd0;
            box2_s2_r <= 8'd0;
            box4_s2_r <= 8'd0;
            pipe_vld_r <= 13'd0;
            center_pipe0_r <= 8'd0; center_pipe1_r <= 8'd0; center_pipe2_r <= 8'd0; center_pipe3_r <= 8'd0;
            center_pipe4_r <= 8'd0; center_pipe5_r <= 8'd0; center_pipe6_r <= 8'd0; center_pipe7_r <= 8'd0;
            center_pipe8_r <= 8'd0; center_pipe9_r <= 8'd0; center_pipe10_r <= 8'd0; center_pipe11_r <= 8'd0; center_pipe12_r <= 8'd0;
            box2_pipe0_r <= 8'd0; box2_pipe1_r <= 8'd0; box2_pipe2_r <= 8'd0; box2_pipe3_r <= 8'd0;
            box2_pipe4_r <= 8'd0; box2_pipe5_r <= 8'd0; box2_pipe6_r <= 8'd0; box2_pipe7_r <= 8'd0;
            box2_pipe8_r <= 8'd0; box2_pipe9_r <= 8'd0; box2_pipe10_r <= 8'd0; box2_pipe11_r <= 8'd0; box2_pipe12_r <= 8'd0;
            box4_pipe0_r <= 8'd0; box4_pipe1_r <= 8'd0; box4_pipe2_r <= 8'd0; box4_pipe3_r <= 8'd0;
            box4_pipe4_r <= 8'd0; box4_pipe5_r <= 8'd0; box4_pipe6_r <= 8'd0; box4_pipe7_r <= 8'd0;
            box4_pipe8_r <= 8'd0; box4_pipe9_r <= 8'd0; box4_pipe10_r <= 8'd0; box4_pipe11_r <= 8'd0; box4_pipe12_r <= 8'd0;
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

            sum_s1_vld_r <= din_vld_d4;
            if (din_vld_d4) begin
                center_s1_r <= r4_t3_w;
                box2_sum_s1_r <= {2'd0, r4_t3_w} + {2'd0, r4_t2_w} + {2'd0, r3_t3_w} + {2'd0, r3_t2_w};
                row1_sum_s1_r <= {2'd0, r1_t0_w} + {2'd0, r1_t1_w} + {2'd0, r1_t2_w} + {2'd0, r1_t3_w};
                row2_sum_s1_r <= {2'd0, r2_t0_w} + {2'd0, r2_t1_w} + {2'd0, r2_t2_w} + {2'd0, r2_t3_w};
                row3_sum_s1_r <= {2'd0, r3_t0_w} + {2'd0, r3_t1_w} + {2'd0, r3_t2_w} + {2'd0, r3_t3_w};
                row4_sum_s1_r <= {2'd0, r4_t0_w} + {2'd0, r4_t1_w} + {2'd0, r4_t2_w} + {2'd0, r4_t3_w};
                if (col_d4 == H_LAST_COL) begin
                    r1_h0_r <= 8'd0; r1_h1_r <= 8'd0; r1_h2_r <= 8'd0; r1_h3_r <= 8'd0;
                    r2_h0_r <= 8'd0; r2_h1_r <= 8'd0; r2_h2_r <= 8'd0; r2_h3_r <= 8'd0;
                    r3_h0_r <= 8'd0; r3_h1_r <= 8'd0; r3_h2_r <= 8'd0; r3_h3_r <= 8'd0;
                    r4_h0_r <= 8'd0; r4_h1_r <= 8'd0; r4_h2_r <= 8'd0; r4_h3_r <= 8'd0;
                end else begin
                    r1_h0_r <= row1_src_w; r1_h1_r <= r1_h0_r; r1_h2_r <= r1_h1_r; r1_h3_r <= r1_h2_r;
                    r2_h0_r <= row2_src_w; r2_h1_r <= r2_h0_r; r2_h2_r <= r2_h1_r; r2_h3_r <= r2_h2_r;
                    r3_h0_r <= row3_src_w; r3_h1_r <= r3_h0_r; r3_h2_r <= r3_h1_r; r3_h3_r <= r3_h2_r;
                    r4_h0_r <= row4_src_w; r4_h1_r <= r4_h0_r; r4_h2_r <= r4_h1_r; r4_h3_r <= r4_h2_r;
                end
            end else begin
                center_s1_r <= 8'd0;
                box2_sum_s1_r <= 10'd0;
                row1_sum_s1_r <= 10'd0;
                row2_sum_s1_r <= 10'd0;
                row3_sum_s1_r <= 10'd0;
                row4_sum_s1_r <= 10'd0;
            end

            sum_s2_vld_r <= sum_s1_vld_r;
            if (sum_s1_vld_r) begin
                center_s2_r <= center_s1_r;
                box2_s2_r <= (box2_sum_s1_r + 10'd2) >> 2;
                box4_s2_r <= (box4_sum_s2_w + 12'd8) >> 4;
            end else begin
                center_s2_r <= 8'd0;
                box2_s2_r <= 8'd0;
                box4_s2_r <= 8'd0;
            end

            pipe_vld_r <= {pipe_vld_r[11:0], sum_s2_vld_r};
            center_pipe0_r <= center_s2_r; center_pipe1_r <= center_pipe0_r; center_pipe2_r <= center_pipe1_r; center_pipe3_r <= center_pipe2_r;
            center_pipe4_r <= center_pipe3_r; center_pipe5_r <= center_pipe4_r; center_pipe6_r <= center_pipe5_r; center_pipe7_r <= center_pipe6_r;
            center_pipe8_r <= center_pipe7_r; center_pipe9_r <= center_pipe8_r; center_pipe10_r <= center_pipe9_r; center_pipe11_r <= center_pipe10_r; center_pipe12_r <= center_pipe11_r;
            box2_pipe0_r <= box2_s2_r; box2_pipe1_r <= box2_pipe0_r; box2_pipe2_r <= box2_pipe1_r; box2_pipe3_r <= box2_pipe2_r;
            box2_pipe4_r <= box2_pipe3_r; box2_pipe5_r <= box2_pipe4_r; box2_pipe6_r <= box2_pipe5_r; box2_pipe7_r <= box2_pipe6_r;
            box2_pipe8_r <= box2_pipe7_r; box2_pipe9_r <= box2_pipe8_r; box2_pipe10_r <= box2_pipe9_r; box2_pipe11_r <= box2_pipe10_r; box2_pipe12_r <= box2_pipe11_r;
            box4_pipe0_r <= box4_s2_r; box4_pipe1_r <= box4_pipe0_r; box4_pipe2_r <= box4_pipe1_r; box4_pipe3_r <= box4_pipe2_r;
            box4_pipe4_r <= box4_pipe3_r; box4_pipe5_r <= box4_pipe4_r; box4_pipe6_r <= box4_pipe5_r; box4_pipe7_r <= box4_pipe6_r;
            box4_pipe8_r <= box4_pipe7_r; box4_pipe9_r <= box4_pipe8_r; box4_pipe10_r <= box4_pipe9_r; box4_pipe11_r <= box4_pipe10_r; box4_pipe12_r <= box4_pipe11_r;
        end
    end

    assign out_vld = pipe_vld_r[12];
    assign out_center = pipe_vld_r[12] ? center_pipe12_r : 8'd0;
    assign out_box2 = pipe_vld_r[12] ? (ENABLE ? box2_pipe12_r : center_pipe12_r) : 8'd0;
    assign out_box4 = pipe_vld_r[12] ? (ENABLE ? box4_pipe12_r : center_pipe12_r) : 8'd0;

endmodule
