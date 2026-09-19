module stream_plane_delay4_3x3
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

    localparam [10:0] H_LAST_COL = H_DISP - 1;

    function [7:0] clamp_delay4_left_u8;
        input [10:0] col;
        input [7:0] cur;
        input [7:0] h0;
        input [7:0] h1;
        input [7:0] h2;
        input [7:0] h3;
        begin
            if (col == 11'd0)
                clamp_delay4_left_u8 = cur;
            else if (col == 11'd1)
                clamp_delay4_left_u8 = h0;
            else if (col == 11'd2)
                clamp_delay4_left_u8 = h1;
            else if (col == 11'd3)
                clamp_delay4_left_u8 = h2;
            else
                clamp_delay4_left_u8 = h3;
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
    reg  [7:0]  h0_r;
    reg  [7:0]  h1_r;
    reg  [7:0]  h2_r;
    reg  [7:0]  h3_r;
    reg         direct_vld_r;
    reg  [7:0]  direct_data_r;
    reg  [14:0] direct_vld_pipe_r;
    reg  [7:0]  direct_data_pipe0_r;
    reg  [7:0]  direct_data_pipe1_r;
    reg  [7:0]  direct_data_pipe2_r;
    reg  [7:0]  direct_data_pipe3_r;
    reg  [7:0]  direct_data_pipe4_r;
    reg  [7:0]  direct_data_pipe5_r;
    reg  [7:0]  direct_data_pipe6_r;
    reg  [7:0]  direct_data_pipe7_r;
    reg  [7:0]  direct_data_pipe8_r;
    reg  [7:0]  direct_data_pipe9_r;
    reg  [7:0]  direct_data_pipe10_r;
    reg  [7:0]  direct_data_pipe11_r;
    reg  [7:0]  direct_data_pipe12_r;
    reg  [7:0]  direct_data_pipe13_r;
    reg  [7:0]  direct_data_pipe14_r;

    wire [7:0] vertical_src_w = (row_d4 < 12'd4) ? 8'd0 : line4_q;
    wire [7:0] direct_data_w = h3_r;

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
            h0_r <= 8'd0;
            h1_r <= 8'd0;
            h2_r <= 8'd0;
            h3_r <= 8'd0;
            direct_vld_r <= 1'b0;
            direct_data_r <= 8'd0;
            direct_vld_pipe_r <= 15'd0;
            direct_data_pipe0_r <= 8'd0;
            direct_data_pipe1_r <= 8'd0;
            direct_data_pipe2_r <= 8'd0;
            direct_data_pipe3_r <= 8'd0;
            direct_data_pipe4_r <= 8'd0;
            direct_data_pipe5_r <= 8'd0;
            direct_data_pipe6_r <= 8'd0;
            direct_data_pipe7_r <= 8'd0;
            direct_data_pipe8_r <= 8'd0;
            direct_data_pipe9_r <= 8'd0;
            direct_data_pipe10_r <= 8'd0;
            direct_data_pipe11_r <= 8'd0;
            direct_data_pipe12_r <= 8'd0;
            direct_data_pipe13_r <= 8'd0;
            direct_data_pipe14_r <= 8'd0;
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
            h0_r <= 8'd0;
            h1_r <= 8'd0;
            h2_r <= 8'd0;
            h3_r <= 8'd0;
            direct_vld_r <= 1'b0;
            direct_data_r <= 8'd0;
            direct_vld_pipe_r <= 15'd0;
            direct_data_pipe0_r <= 8'd0;
            direct_data_pipe1_r <= 8'd0;
            direct_data_pipe2_r <= 8'd0;
            direct_data_pipe3_r <= 8'd0;
            direct_data_pipe4_r <= 8'd0;
            direct_data_pipe5_r <= 8'd0;
            direct_data_pipe6_r <= 8'd0;
            direct_data_pipe7_r <= 8'd0;
            direct_data_pipe8_r <= 8'd0;
            direct_data_pipe9_r <= 8'd0;
            direct_data_pipe10_r <= 8'd0;
            direct_data_pipe11_r <= 8'd0;
            direct_data_pipe12_r <= 8'd0;
            direct_data_pipe13_r <= 8'd0;
            direct_data_pipe14_r <= 8'd0;
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
            din_d1     <= din;
            col_d1     <= col_cnt[10:0];
            row_d1     <= row_cnt;

            din_vld_d2 <= din_vld_d1;
            din_d2     <= din_d1;
            col_d2     <= col_d1;
            row_d2     <= row_d1;
            line1_q_d1 <= line1_q;

            din_vld_d3 <= din_vld_d2;
            din_d3     <= din_d2;
            col_d3     <= col_d2;
            row_d3     <= row_d2;
            line1_q_d2 <= line1_q_d1;
            line2_q_d1 <= line2_q;

            din_vld_d4 <= din_vld_d3;
            din_d4     <= din_d3;
            col_d4     <= col_d3;
            row_d4     <= row_d3;
            line1_q_d3 <= line1_q_d2;
            line2_q_d2 <= line2_q_d1;
            line3_q_d1 <= line3_q;

            direct_vld_r <= din_vld_d4;
            if (din_vld_d4) begin
                direct_data_r <= direct_data_w;
                if (col_d4 == H_LAST_COL) begin
                    h0_r <= 8'd0;
                    h1_r <= 8'd0;
                    h2_r <= 8'd0;
                    h3_r <= 8'd0;
                end else begin
                    h0_r <= vertical_src_w;
                    h1_r <= h0_r;
                    h2_r <= h1_r;
                    h3_r <= h2_r;
                end
            end else begin
                direct_data_r <= 8'd0;
            end

            direct_vld_pipe_r <= {direct_vld_pipe_r[13:0], direct_vld_r};
            direct_data_pipe0_r <= direct_data_r;
            direct_data_pipe1_r <= direct_data_pipe0_r;
            direct_data_pipe2_r <= direct_data_pipe1_r;
            direct_data_pipe3_r <= direct_data_pipe2_r;
            direct_data_pipe4_r <= direct_data_pipe3_r;
            direct_data_pipe5_r <= direct_data_pipe4_r;
            direct_data_pipe6_r <= direct_data_pipe5_r;
            direct_data_pipe7_r <= direct_data_pipe6_r;
            direct_data_pipe8_r <= direct_data_pipe7_r;
            direct_data_pipe9_r <= direct_data_pipe8_r;
            direct_data_pipe10_r <= direct_data_pipe9_r;
            direct_data_pipe11_r <= direct_data_pipe10_r;
            direct_data_pipe12_r <= direct_data_pipe11_r;
            direct_data_pipe13_r <= direct_data_pipe12_r;
            direct_data_pipe14_r <= direct_data_pipe13_r;
        end
    end

    assign out_vld = direct_vld_pipe_r[14];
    assign out_center = direct_vld_pipe_r[14] ? direct_data_pipe14_r : 8'd0;

endmodule

module stream_quad_delay4_3x3
#(
    parameter H_DISP = 1280,
    parameter V_DISP = 720
)
(
    input   wire          clk,
    input   wire          rst_n,
    input   wire          frame_clr,
    input   wire          din_vld,
    input   wire  [31:0]  din_quad,
    output  wire          out_vld,
    output  wire  [31:0]  out_center_quad
);

    wire        de2_w;
    wire        de4_w;
    wire [31:0] center2_w;
    wire [31:0] center4_w;

    stream_quad_delay2_3x3
    #(
        .H_DISP (H_DISP),
        .V_DISP (V_DISP)
    )
    u_delay2a
    (
        .clk             (clk),
        .rst_n           (rst_n),
        .frame_clr       (frame_clr),
        .din_vld         (din_vld),
        .din_quad        (din_quad),
        .out_vld         (de2_w),
        .out_center_quad (center2_w)
    );

    stream_quad_delay2_3x3
    #(
        .H_DISP (H_DISP),
        .V_DISP (V_DISP)
    )
    u_delay2b
    (
        .clk             (clk),
        .rst_n           (rst_n),
        .frame_clr       (frame_clr),
        .din_vld         (de2_w),
        .din_quad        (center2_w),
        .out_vld         (de4_w),
        .out_center_quad (center4_w)
    );

    assign out_vld = de4_w;
    assign out_center_quad = center4_w;

endmodule

module stream_quad_delay2_3x3
#(
    parameter H_DISP = 1280,
    parameter V_DISP = 720
)
(
    input   wire          clk,
    input   wire          rst_n,
    input   wire          frame_clr,
    input   wire          din_vld,
    input   wire  [31:0]  din_quad,
    output  wire          out_vld,
    output  wire  [31:0]  out_center_quad
);

    wire        de1_w;
    wire        de2_w;
    wire [31:0] center1_w;
    wire [31:0] center2_w;

    stream_quad_center_delay_3x3
    #(
        .H_DISP (H_DISP),
        .V_DISP (V_DISP)
    )
    u_delay1
    (
        .clk             (clk),
        .rst_n           (rst_n),
        .frame_clr       (frame_clr),
        .din_vld         (din_vld),
        .din_quad        (din_quad),
        .out_vld         (de1_w),
        .out_center_quad (center1_w)
    );

    stream_quad_center_delay_3x3
    #(
        .H_DISP (H_DISP),
        .V_DISP (V_DISP)
    )
    u_delay2
    (
        .clk             (clk),
        .rst_n           (rst_n),
        .frame_clr       (frame_clr),
        .din_vld         (de1_w),
        .din_quad        (center1_w),
        .out_vld         (de2_w),
        .out_center_quad (center2_w)
    );

    assign out_vld = de2_w;
    assign out_center_quad = center2_w;

endmodule

module stream_quad_center_delay_3x3
#(
    parameter H_DISP = 1280,
    parameter V_DISP = 720
)
(
    input   wire          clk,
    input   wire          rst_n,
    input   wire          frame_clr,
    input   wire          din_vld,
    input   wire  [31:0]  din_quad,
    output  reg           out_vld,
    output  reg   [31:0]  out_center_quad
);

    localparam [10:0] H_LAST_COL = H_DISP - 1;

    wire [7:0] line1_q3;
    wire [7:0] line1_q2;
    wire [7:0] line1_q1;
    wire [7:0] line1_q0;
    wire [31:0] line1_q = {line1_q3, line1_q2, line1_q1, line1_q0};

    (* preserve, syn_preserve = 1 *) reg         din_vld_d1;
    (* preserve, syn_preserve = 1 *) reg         din_vld_d2;
    reg  [31:0] din_d1;
    reg  [31:0] din_d2;
    (* preserve, syn_preserve = 1 *) reg  [11:0] col_cnt;
    (* preserve, syn_preserve = 1 *) reg  [11:0] row_cnt;
    (* preserve, syn_preserve = 1 *) reg  [10:0] col_d1;
    (* preserve, syn_preserve = 1 *) reg  [10:0] col_d2;
    (* preserve, syn_preserve = 1 *) reg  [11:0] row_d1;
    (* preserve, syn_preserve = 1 *) reg  [11:0] row_d2;
    reg  [31:0] line1_q_d1;
    reg  [31:0] matrix_22;
    reg  [31:0] matrix_23;
    reg         pix_vld;
    reg         center_vld_r;
    reg  [31:0] center_s1_r;
    wire [31:0] vertical_src_w = (row_d2 == 12'd0) ? 32'd0 : line1_q_d1;

    m4k_linebuf_2048x8 u_line_buf_3
    (
        .clock      (clk),
        .wren       (din_vld),
        .wraddress  (col_cnt[10:0]),
        .data       (din_quad[31:24]),
        .rdaddress  (col_cnt[10:0]),
        .q          (line1_q3)
    );

    m4k_linebuf_2048x8 u_line_buf_2
    (
        .clock      (clk),
        .wren       (din_vld),
        .wraddress  (col_cnt[10:0]),
        .data       (din_quad[23:16]),
        .rdaddress  (col_cnt[10:0]),
        .q          (line1_q2)
    );

    m4k_linebuf_2048x8 u_line_buf_1
    (
        .clock      (clk),
        .wren       (din_vld),
        .wraddress  (col_cnt[10:0]),
        .data       (din_quad[15:8]),
        .rdaddress  (col_cnt[10:0]),
        .q          (line1_q1)
    );

    m4k_linebuf_2048x8 u_line_buf_0
    (
        .clock      (clk),
        .wren       (din_vld),
        .wraddress  (col_cnt[10:0]),
        .data       (din_quad[7:0]),
        .rdaddress  (col_cnt[10:0]),
        .q          (line1_q0)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            col_cnt <= 12'd0;
            row_cnt <= 12'd0;
            din_vld_d1 <= 1'b0;
            din_vld_d2 <= 1'b0;
            din_d1 <= 32'd0;
            din_d2 <= 32'd0;
            col_d1 <= 11'd0;
            col_d2 <= 11'd0;
            row_d1 <= 12'd0;
            row_d2 <= 12'd0;
            line1_q_d1 <= 32'd0;
            matrix_22 <= 32'd0;
            matrix_23 <= 32'd0;
            pix_vld <= 1'b0;
            center_vld_r <= 1'b0;
            center_s1_r <= 32'd0;
        end else if (frame_clr) begin
            col_cnt <= 12'd0;
            row_cnt <= 12'd0;
            din_vld_d1 <= 1'b0;
            din_vld_d2 <= 1'b0;
            din_d1 <= 32'd0;
            din_d2 <= 32'd0;
            col_d1 <= 11'd0;
            col_d2 <= 11'd0;
            row_d1 <= 12'd0;
            row_d2 <= 12'd0;
            line1_q_d1 <= 32'd0;
            matrix_22 <= 32'd0;
            matrix_23 <= 32'd0;
            pix_vld <= 1'b0;
            center_vld_r <= 1'b0;
            center_s1_r <= 32'd0;
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
            din_d1     <= din_quad;
            col_d1     <= col_cnt[10:0];
            row_d1     <= row_cnt;

            din_vld_d2 <= din_vld_d1;
            din_d2     <= din_d1;
            col_d2     <= col_d1;
            row_d2     <= row_d1;
            line1_q_d1 <= line1_q;

            if (din_vld_d2) begin
                if (col_d2 == H_LAST_COL) begin
                    matrix_22 <= 32'd0;
                    matrix_23 <= 32'd0;
                end else begin
                    matrix_22 <= matrix_23;
                    matrix_23 <= vertical_src_w;
                end

                pix_vld <= 1'b1;
            end else begin
                pix_vld <= 1'b0;
            end

            center_vld_r <= pix_vld;
            if (pix_vld)
                center_s1_r <= matrix_22;
            else
                center_s1_r <= 32'd0;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_vld <= 1'b0;
            out_center_quad <= 32'd0;
        end else if (frame_clr) begin
            out_vld <= 1'b0;
            out_center_quad <= 32'd0;
        end else begin
            out_vld <= center_vld_r;
            out_center_quad <= center_vld_r ? center_s1_r : 32'd0;
        end
    end

endmodule

module stream_rgb_delay4_3x3
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

    localparam [10:0] H_LAST_COL = H_DISP - 1;

    function [23:0] clamp_delay4_left_rgb;
        input [10:0] col;
        input [23:0] cur;
        input [23:0] h0;
        input [23:0] h1;
        input [23:0] h2;
        input [23:0] h3;
        begin
            if (col == 11'd0)
                clamp_delay4_left_rgb = cur;
            else if (col == 11'd1)
                clamp_delay4_left_rgb = h0;
            else if (col == 11'd2)
                clamp_delay4_left_rgb = h1;
            else if (col == 11'd3)
                clamp_delay4_left_rgb = h2;
            else
                clamp_delay4_left_rgb = h3;
        end
    endfunction

    wire [7:0] line1_r_q;
    wire [7:0] line1_g_q;
    wire [7:0] line1_b_q;
    wire [7:0] line2_r_q;
    wire [7:0] line2_g_q;
    wire [7:0] line2_b_q;
    wire [7:0] line3_r_q;
    wire [7:0] line3_g_q;
    wire [7:0] line3_b_q;
    wire [7:0] line4_r_q;
    wire [7:0] line4_g_q;
    wire [7:0] line4_b_q;
    wire [23:0] line1_q = {line1_r_q, line1_g_q, line1_b_q};
    wire [23:0] line2_q = {line2_r_q, line2_g_q, line2_b_q};
    wire [23:0] line3_q = {line3_r_q, line3_g_q, line3_b_q};
    wire [23:0] line4_q = {line4_r_q, line4_g_q, line4_b_q};

    (* preserve, syn_preserve = 1 *) reg         din_vld_d1;
    (* preserve, syn_preserve = 1 *) reg         din_vld_d2;
    (* preserve, syn_preserve = 1 *) reg         din_vld_d3;
    (* preserve, syn_preserve = 1 *) reg         din_vld_d4;
    reg  [23:0] din_d1;
    reg  [23:0] din_d2;
    reg  [23:0] din_d3;
    reg  [23:0] din_d4;
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
    reg  [23:0] line1_q_d1;
    reg  [23:0] line1_q_d2;
    reg  [23:0] line1_q_d3;
    reg  [23:0] line2_q_d1;
    reg  [23:0] line2_q_d2;
    reg  [23:0] line3_q_d1;
    reg  [23:0] h0_r;
    reg  [23:0] h1_r;
    reg  [23:0] h2_r;
    reg  [23:0] h3_r;
    reg         direct_vld_r;
    reg  [23:0] direct_rgb_r;
    reg  [14:0] direct_vld_pipe_r;
    reg  [23:0] direct_rgb_pipe0_r;
    reg  [23:0] direct_rgb_pipe1_r;
    reg  [23:0] direct_rgb_pipe2_r;
    reg  [23:0] direct_rgb_pipe3_r;
    reg  [23:0] direct_rgb_pipe4_r;
    reg  [23:0] direct_rgb_pipe5_r;
    reg  [23:0] direct_rgb_pipe6_r;
    reg  [23:0] direct_rgb_pipe7_r;
    reg  [23:0] direct_rgb_pipe8_r;
    reg  [23:0] direct_rgb_pipe9_r;
    reg  [23:0] direct_rgb_pipe10_r;
    reg  [23:0] direct_rgb_pipe11_r;
    reg  [23:0] direct_rgb_pipe12_r;
    reg  [23:0] direct_rgb_pipe13_r;
    reg  [23:0] direct_rgb_pipe14_r;

    wire [23:0] vertical_src_w = (row_d4 < 12'd4) ? 24'd0 : line4_q;
    wire [23:0] direct_rgb_w = h3_r;

    m4k_linebuf_2048x8 u_line1_r
    (
        .clock      (clk),
        .wren       (din_vld),
        .wraddress  (col_cnt[10:0]),
        .data       (din_rgb[23:16]),
        .rdaddress  (col_cnt[10:0]),
        .q          (line1_r_q)
    );

    m4k_linebuf_2048x8 u_line1_g
    (
        .clock      (clk),
        .wren       (din_vld),
        .wraddress  (col_cnt[10:0]),
        .data       (din_rgb[15:8]),
        .rdaddress  (col_cnt[10:0]),
        .q          (line1_g_q)
    );

    m4k_linebuf_2048x8 u_line1_b
    (
        .clock      (clk),
        .wren       (din_vld),
        .wraddress  (col_cnt[10:0]),
        .data       (din_rgb[7:0]),
        .rdaddress  (col_cnt[10:0]),
        .q          (line1_b_q)
    );

    m4k_linebuf_2048x8 u_line2_r
    (
        .clock      (clk),
        .wren       (din_vld_d1 && (row_d1 != 12'd0)),
        .wraddress  (col_d1),
        .data       (line1_q[23:16]),
        .rdaddress  (col_d1),
        .q          (line2_r_q)
    );

    m4k_linebuf_2048x8 u_line2_g
    (
        .clock      (clk),
        .wren       (din_vld_d1 && (row_d1 != 12'd0)),
        .wraddress  (col_d1),
        .data       (line1_q[15:8]),
        .rdaddress  (col_d1),
        .q          (line2_g_q)
    );

    m4k_linebuf_2048x8 u_line2_b
    (
        .clock      (clk),
        .wren       (din_vld_d1 && (row_d1 != 12'd0)),
        .wraddress  (col_d1),
        .data       (line1_q[7:0]),
        .rdaddress  (col_d1),
        .q          (line2_b_q)
    );

    m4k_linebuf_2048x8 u_line3_r
    (
        .clock      (clk),
        .wren       (din_vld_d2 && (row_d2 > 12'd1)),
        .wraddress  (col_d2),
        .data       (line2_q[23:16]),
        .rdaddress  (col_d2),
        .q          (line3_r_q)
    );

    m4k_linebuf_2048x8 u_line3_g
    (
        .clock      (clk),
        .wren       (din_vld_d2 && (row_d2 > 12'd1)),
        .wraddress  (col_d2),
        .data       (line2_q[15:8]),
        .rdaddress  (col_d2),
        .q          (line3_g_q)
    );

    m4k_linebuf_2048x8 u_line3_b
    (
        .clock      (clk),
        .wren       (din_vld_d2 && (row_d2 > 12'd1)),
        .wraddress  (col_d2),
        .data       (line2_q[7:0]),
        .rdaddress  (col_d2),
        .q          (line3_b_q)
    );

    m4k_linebuf_2048x8 u_line4_r
    (
        .clock      (clk),
        .wren       (din_vld_d3 && (row_d3 > 12'd2)),
        .wraddress  (col_d3),
        .data       (line3_q[23:16]),
        .rdaddress  (col_d3),
        .q          (line4_r_q)
    );

    m4k_linebuf_2048x8 u_line4_g
    (
        .clock      (clk),
        .wren       (din_vld_d3 && (row_d3 > 12'd2)),
        .wraddress  (col_d3),
        .data       (line3_q[15:8]),
        .rdaddress  (col_d3),
        .q          (line4_g_q)
    );

    m4k_linebuf_2048x8 u_line4_b
    (
        .clock      (clk),
        .wren       (din_vld_d3 && (row_d3 > 12'd2)),
        .wraddress  (col_d3),
        .data       (line3_q[7:0]),
        .rdaddress  (col_d3),
        .q          (line4_b_q)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            col_cnt <= 12'd0;
            row_cnt <= 12'd0;
            din_vld_d1 <= 1'b0;
            din_vld_d2 <= 1'b0;
            din_vld_d3 <= 1'b0;
            din_vld_d4 <= 1'b0;
            din_d1 <= 24'd0;
            din_d2 <= 24'd0;
            din_d3 <= 24'd0;
            din_d4 <= 24'd0;
            col_d1 <= 11'd0;
            col_d2 <= 11'd0;
            col_d3 <= 11'd0;
            col_d4 <= 11'd0;
            row_d1 <= 12'd0;
            row_d2 <= 12'd0;
            row_d3 <= 12'd0;
            row_d4 <= 12'd0;
            line1_q_d1 <= 24'd0;
            line1_q_d2 <= 24'd0;
            line1_q_d3 <= 24'd0;
            line2_q_d1 <= 24'd0;
            line2_q_d2 <= 24'd0;
            line3_q_d1 <= 24'd0;
            h0_r <= 24'd0;
            h1_r <= 24'd0;
            h2_r <= 24'd0;
            h3_r <= 24'd0;
            direct_vld_r <= 1'b0;
            direct_rgb_r <= 24'd0;
            direct_vld_pipe_r <= 15'd0;
            direct_rgb_pipe0_r <= 24'd0;
            direct_rgb_pipe1_r <= 24'd0;
            direct_rgb_pipe2_r <= 24'd0;
            direct_rgb_pipe3_r <= 24'd0;
            direct_rgb_pipe4_r <= 24'd0;
            direct_rgb_pipe5_r <= 24'd0;
            direct_rgb_pipe6_r <= 24'd0;
            direct_rgb_pipe7_r <= 24'd0;
            direct_rgb_pipe8_r <= 24'd0;
            direct_rgb_pipe9_r <= 24'd0;
            direct_rgb_pipe10_r <= 24'd0;
            direct_rgb_pipe11_r <= 24'd0;
            direct_rgb_pipe12_r <= 24'd0;
            direct_rgb_pipe13_r <= 24'd0;
            direct_rgb_pipe14_r <= 24'd0;
        end else if (frame_clr) begin
            col_cnt <= 12'd0;
            row_cnt <= 12'd0;
            din_vld_d1 <= 1'b0;
            din_vld_d2 <= 1'b0;
            din_vld_d3 <= 1'b0;
            din_vld_d4 <= 1'b0;
            din_d1 <= 24'd0;
            din_d2 <= 24'd0;
            din_d3 <= 24'd0;
            din_d4 <= 24'd0;
            col_d1 <= 11'd0;
            col_d2 <= 11'd0;
            col_d3 <= 11'd0;
            col_d4 <= 11'd0;
            row_d1 <= 12'd0;
            row_d2 <= 12'd0;
            row_d3 <= 12'd0;
            row_d4 <= 12'd0;
            line1_q_d1 <= 24'd0;
            line1_q_d2 <= 24'd0;
            line1_q_d3 <= 24'd0;
            line2_q_d1 <= 24'd0;
            line2_q_d2 <= 24'd0;
            line3_q_d1 <= 24'd0;
            h0_r <= 24'd0;
            h1_r <= 24'd0;
            h2_r <= 24'd0;
            h3_r <= 24'd0;
            direct_vld_r <= 1'b0;
            direct_rgb_r <= 24'd0;
            direct_vld_pipe_r <= 15'd0;
            direct_rgb_pipe0_r <= 24'd0;
            direct_rgb_pipe1_r <= 24'd0;
            direct_rgb_pipe2_r <= 24'd0;
            direct_rgb_pipe3_r <= 24'd0;
            direct_rgb_pipe4_r <= 24'd0;
            direct_rgb_pipe5_r <= 24'd0;
            direct_rgb_pipe6_r <= 24'd0;
            direct_rgb_pipe7_r <= 24'd0;
            direct_rgb_pipe8_r <= 24'd0;
            direct_rgb_pipe9_r <= 24'd0;
            direct_rgb_pipe10_r <= 24'd0;
            direct_rgb_pipe11_r <= 24'd0;
            direct_rgb_pipe12_r <= 24'd0;
            direct_rgb_pipe13_r <= 24'd0;
            direct_rgb_pipe14_r <= 24'd0;
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
            din_d1     <= din_rgb;
            col_d1     <= col_cnt[10:0];
            row_d1     <= row_cnt;

            din_vld_d2 <= din_vld_d1;
            din_d2     <= din_d1;
            col_d2     <= col_d1;
            row_d2     <= row_d1;
            line1_q_d1 <= line1_q;

            din_vld_d3 <= din_vld_d2;
            din_d3     <= din_d2;
            col_d3     <= col_d2;
            row_d3     <= row_d2;
            line1_q_d2 <= line1_q_d1;
            line2_q_d1 <= line2_q;

            din_vld_d4 <= din_vld_d3;
            din_d4     <= din_d3;
            col_d4     <= col_d3;
            row_d4     <= row_d3;
            line1_q_d3 <= line1_q_d2;
            line2_q_d2 <= line2_q_d1;
            line3_q_d1 <= line3_q;

            direct_vld_r <= din_vld_d4;
            if (din_vld_d4) begin
                direct_rgb_r <= direct_rgb_w;
                if (col_d4 == H_LAST_COL) begin
                    h0_r <= 24'd0;
                    h1_r <= 24'd0;
                    h2_r <= 24'd0;
                    h3_r <= 24'd0;
                end else begin
                    h0_r <= vertical_src_w;
                    h1_r <= h0_r;
                    h2_r <= h1_r;
                    h3_r <= h2_r;
                end
            end else begin
                direct_rgb_r <= 24'd0;
            end

            direct_vld_pipe_r <= {direct_vld_pipe_r[13:0], direct_vld_r};
            direct_rgb_pipe0_r <= direct_rgb_r;
            direct_rgb_pipe1_r <= direct_rgb_pipe0_r;
            direct_rgb_pipe2_r <= direct_rgb_pipe1_r;
            direct_rgb_pipe3_r <= direct_rgb_pipe2_r;
            direct_rgb_pipe4_r <= direct_rgb_pipe3_r;
            direct_rgb_pipe5_r <= direct_rgb_pipe4_r;
            direct_rgb_pipe6_r <= direct_rgb_pipe5_r;
            direct_rgb_pipe7_r <= direct_rgb_pipe6_r;
            direct_rgb_pipe8_r <= direct_rgb_pipe7_r;
            direct_rgb_pipe9_r <= direct_rgb_pipe8_r;
            direct_rgb_pipe10_r <= direct_rgb_pipe9_r;
            direct_rgb_pipe11_r <= direct_rgb_pipe10_r;
            direct_rgb_pipe12_r <= direct_rgb_pipe11_r;
            direct_rgb_pipe13_r <= direct_rgb_pipe12_r;
            direct_rgb_pipe14_r <= direct_rgb_pipe13_r;
        end
    end

    assign out_vld = direct_vld_pipe_r[14];
    assign out_center_rgb = direct_vld_pipe_r[14] ? direct_rgb_pipe14_r : 24'd0;

endmodule

module stream_rgb_delay2_3x3
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

    wire        de1_w;
    wire        de2_w;
    wire [23:0] center1_w;
    wire [23:0] center2_w;

    stream_rgb_center_delay_3x3
    #(
        .H_DISP (H_DISP),
        .V_DISP (V_DISP)
    )
    u_delay1
    (
        .clk            (clk),
        .rst_n          (rst_n),
        .frame_clr      (frame_clr),
        .din_vld        (din_vld),
        .din_rgb        (din_rgb),
        .out_vld        (de1_w),
        .out_center_rgb (center1_w)
    );

    stream_rgb_center_delay_3x3
    #(
        .H_DISP (H_DISP),
        .V_DISP (V_DISP)
    )
    u_delay2
    (
        .clk            (clk),
        .rst_n          (rst_n),
        .frame_clr      (frame_clr),
        .din_vld        (de1_w),
        .din_rgb        (center1_w),
        .out_vld        (de2_w),
        .out_center_rgb (center2_w)
    );

    assign out_vld = de2_w;
    assign out_center_rgb = center2_w;

endmodule

module stream_rgb_center_delay_3x3
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
    output  reg           out_vld,
    output  reg   [23:0]  out_center_rgb
);

    localparam [10:0] H_LAST_COL = H_DISP - 1;

    wire [7:0] line1_r_q;
    wire [7:0] line1_g_q;
    wire [7:0] line1_b_q;
    wire [23:0] line1_q = {line1_r_q, line1_g_q, line1_b_q};

    (* preserve, syn_preserve = 1 *) reg         din_vld_d1;
    (* preserve, syn_preserve = 1 *) reg         din_vld_d2;
    reg  [23:0] din_d1;
    reg  [23:0] din_d2;
    (* preserve, syn_preserve = 1 *) reg  [11:0] col_cnt;
    (* preserve, syn_preserve = 1 *) reg  [11:0] row_cnt;
    (* preserve, syn_preserve = 1 *) reg  [10:0] col_d1;
    (* preserve, syn_preserve = 1 *) reg  [10:0] col_d2;
    (* preserve, syn_preserve = 1 *) reg  [11:0] row_d1;
    (* preserve, syn_preserve = 1 *) reg  [11:0] row_d2;
    reg  [23:0] line1_q_d1;
    reg  [23:0] matrix_22;
    reg  [23:0] matrix_23;
    reg         pix_vld;
    reg         center_vld_r;
    reg  [23:0] center_s1_r;
    wire [23:0] vertical_src_w = (row_d2 == 12'd0) ? 24'd0 : line1_q_d1;

    m4k_linebuf_2048x8 u_line_buf_r
    (
        .clock      (clk),
        .wren       (din_vld),
        .wraddress  (col_cnt[10:0]),
        .data       (din_rgb[23:16]),
        .rdaddress  (col_cnt[10:0]),
        .q          (line1_r_q)
    );

    m4k_linebuf_2048x8 u_line_buf_g
    (
        .clock      (clk),
        .wren       (din_vld),
        .wraddress  (col_cnt[10:0]),
        .data       (din_rgb[15:8]),
        .rdaddress  (col_cnt[10:0]),
        .q          (line1_g_q)
    );

    m4k_linebuf_2048x8 u_line_buf_b
    (
        .clock      (clk),
        .wren       (din_vld),
        .wraddress  (col_cnt[10:0]),
        .data       (din_rgb[7:0]),
        .rdaddress  (col_cnt[10:0]),
        .q          (line1_b_q)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            col_cnt <= 12'd0;
            row_cnt <= 12'd0;
            din_vld_d1 <= 1'b0;
            din_vld_d2 <= 1'b0;
            din_d1 <= 24'd0;
            din_d2 <= 24'd0;
            col_d1 <= 11'd0;
            col_d2 <= 11'd0;
            row_d1 <= 12'd0;
            row_d2 <= 12'd0;
            line1_q_d1 <= 24'd0;
            matrix_22 <= 24'd0;
            matrix_23 <= 24'd0;
            pix_vld <= 1'b0;
            center_vld_r <= 1'b0;
            center_s1_r <= 24'd0;
        end else if (frame_clr) begin
            col_cnt <= 12'd0;
            row_cnt <= 12'd0;
            din_vld_d1 <= 1'b0;
            din_vld_d2 <= 1'b0;
            din_d1 <= 24'd0;
            din_d2 <= 24'd0;
            col_d1 <= 11'd0;
            col_d2 <= 11'd0;
            row_d1 <= 12'd0;
            row_d2 <= 12'd0;
            line1_q_d1 <= 24'd0;
            matrix_22 <= 24'd0;
            matrix_23 <= 24'd0;
            pix_vld <= 1'b0;
            center_vld_r <= 1'b0;
            center_s1_r <= 24'd0;
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
            din_d1     <= din_rgb;
            col_d1     <= col_cnt[10:0];
            row_d1     <= row_cnt;

            din_vld_d2 <= din_vld_d1;
            din_d2     <= din_d1;
            col_d2     <= col_d1;
            row_d2     <= row_d1;
            line1_q_d1 <= line1_q;

            if (din_vld_d2) begin
                if (col_d2 == H_LAST_COL) begin
                    matrix_22 <= 24'd0;
                    matrix_23 <= 24'd0;
                end else begin
                    matrix_22 <= matrix_23;
                    matrix_23 <= vertical_src_w;
                end

                pix_vld <= 1'b1;
            end else begin
                pix_vld <= 1'b0;
            end

            center_vld_r <= pix_vld;
            if (pix_vld)
                center_s1_r <= matrix_22;
            else
                center_s1_r <= 24'd0;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_vld <= 1'b0;
            out_center_rgb <= 24'd0;
        end else if (frame_clr) begin
            out_vld <= 1'b0;
            out_center_rgb <= 24'd0;
        end else begin
            out_vld <= center_vld_r;
            out_center_rgb <= center_vld_r ? center_s1_r : 24'd0;
        end
    end

endmodule
