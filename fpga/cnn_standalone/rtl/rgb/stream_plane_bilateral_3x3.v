module stream_plane_bilateral_3x3
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

    localparam [10:0] H_LAST_COL = H_DISP - 1;

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

    wire [7:0] line1_q;
    wire [7:0] line2_q;
    wire [7:0] next_top_src_w;
    wire [7:0] next_mid_src_w;
    wire       reflect_top_w;
    wire       reflect_left_w;
    wire [7:0] shift_m11_w;
    wire [7:0] shift_m12_w;
    wire [7:0] shift_m13_w;
    wire [7:0] shift_m21_w;
    wire [7:0] shift_m22_w;
    wire [7:0] shift_m23_w;
    wire [7:0] shift_m31_w;
    wire [7:0] shift_m32_w;
    wire [7:0] shift_m33_w;
    wire [7:0] topref_m11_w;
    wire [7:0] topref_m12_w;
    wire [7:0] topref_m13_w;
    wire [7:0] final_m11_w;
    wire [7:0] final_m21_w;
    wire [7:0] final_m31_w;

    (* preserve, syn_preserve = 1 *) reg         din_vld_d1;
    (* preserve, syn_preserve = 1 *) reg         din_vld_d2;
    reg  [7:0]  din_d1;
    reg  [7:0]  din_d2;
    (* preserve, syn_preserve = 1 *) reg  [11:0] col_cnt;
    (* preserve, syn_preserve = 1 *) reg  [11:0] row_cnt;
    (* preserve, syn_preserve = 1 *) reg  [10:0] col_d1;
    (* preserve, syn_preserve = 1 *) reg  [10:0] col_d2;
    (* preserve, syn_preserve = 1 *) reg  [11:0] row_d1;
    (* preserve, syn_preserve = 1 *) reg  [11:0] row_d2;
    reg  [7:0]  line1_q_d1;

    reg  [7:0]  matrix_11;
    reg  [7:0]  matrix_12;
    reg  [7:0]  matrix_13;
    reg  [7:0]  matrix_21;
    reg  [7:0]  matrix_22;
    reg  [7:0]  matrix_23;
    reg  [7:0]  matrix_31;
    reg  [7:0]  matrix_32;
    reg  [7:0]  matrix_33;
    reg         pix_vld;
    reg         filt_vld_r;
    reg  [7:0]  center_s1_r;
    reg  [7:0]  p11_s1_r;
    reg  [7:0]  p12_s1_r;
    reg  [7:0]  p13_s1_r;
    reg  [7:0]  p21_s1_r;
    reg  [7:0]  p23_s1_r;
    reg  [7:0]  p31_s1_r;
    reg  [7:0]  p32_s1_r;
    reg  [7:0]  p33_s1_r;

    wire [7:0] p11_w = range_pick(matrix_11, matrix_22);
    wire [7:0] p12_w = range_pick(matrix_12, matrix_22);
    wire [7:0] p13_w = range_pick(matrix_13, matrix_22);
    wire [7:0] p21_w = range_pick(matrix_21, matrix_22);
    wire [7:0] p23_w = range_pick(matrix_23, matrix_22);
    wire [7:0] p31_w = range_pick(matrix_31, matrix_22);
    wire [7:0] p32_w = range_pick(matrix_32, matrix_22);
    wire [7:0] p33_w = range_pick(matrix_33, matrix_22);

    wire [10:0] filtered_row0_w =
        {3'd0, p11_s1_r} + {2'd0, p12_s1_r, 1'b0} + {3'd0, p13_s1_r};
    wire [10:0] filtered_row1_w =
        {2'd0, p21_s1_r, 1'b0} + {1'd0, center_s1_r, 2'b00} + {2'd0, p23_s1_r, 1'b0};
    wire [10:0] filtered_row2_w =
        {3'd0, p31_s1_r} + {2'd0, p32_s1_r, 1'b0} + {3'd0, p33_s1_r};
    wire [11:0] filtered_sum_w =
        {1'b0, filtered_row0_w} + {1'b0, filtered_row1_w} + {1'b0, filtered_row2_w};
    wire [7:0] filtered_px_w = (filtered_sum_w + 12'd8) >> 4;
    assign next_top_src_w = (row_d2 < 12'd2) ? 8'd0 : line2_q;
    assign next_mid_src_w = (row_d2 == 12'd0) ? 8'd0 : line1_q_d1;
    assign reflect_top_w  = 1'b0;
    assign reflect_left_w = 1'b0;
    assign shift_m11_w = matrix_12;
    assign shift_m12_w = matrix_13;
    assign shift_m13_w = next_top_src_w;
    assign shift_m21_w = matrix_22;
    assign shift_m22_w = matrix_23;
    assign shift_m23_w = next_mid_src_w;
    assign shift_m31_w = matrix_32;
    assign shift_m32_w = matrix_33;
    assign shift_m33_w = din_d2;
    assign topref_m11_w = reflect_top_w ? shift_m31_w : shift_m11_w;
    assign topref_m12_w = reflect_top_w ? shift_m32_w : shift_m12_w;
    assign topref_m13_w = reflect_top_w ? shift_m33_w : shift_m13_w;
    assign final_m11_w = reflect_left_w ? topref_m13_w : topref_m11_w;
    assign final_m21_w = reflect_left_w ? shift_m23_w : shift_m21_w;
    assign final_m31_w = reflect_left_w ? shift_m33_w : shift_m31_w;

    m4k_linebuf_2048x8 u_line_buf_1
    (
        .clock      (clk),
        .wren       (din_vld),
        .wraddress  (col_cnt[10:0]),
        .data       (din),
        .rdaddress  (col_cnt[10:0]),
        .q          (line1_q)
    );

    m4k_linebuf_2048x8 u_line_buf_2
    (
        .clock      (clk),
        .wren       (din_vld_d1 && (row_d1 != 12'd0)),
        .wraddress  (col_d1),
        .data       (line1_q),
        .rdaddress  (col_d1),
        .q          (line2_q)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            col_cnt <= 12'd0;
            row_cnt <= 12'd0;
            din_vld_d1 <= 1'b0;
            din_vld_d2 <= 1'b0;
            din_d1 <= 8'd0;
            din_d2 <= 8'd0;
            col_d1 <= 11'd0;
            col_d2 <= 11'd0;
            row_d1 <= 12'd0;
            row_d2 <= 12'd0;
            line1_q_d1 <= 8'd0;
            matrix_11 <= 8'd0;
            matrix_12 <= 8'd0;
            matrix_13 <= 8'd0;
            matrix_21 <= 8'd0;
            matrix_22 <= 8'd0;
            matrix_23 <= 8'd0;
            matrix_31 <= 8'd0;
            matrix_32 <= 8'd0;
            matrix_33 <= 8'd0;
            pix_vld <= 1'b0;
            filt_vld_r <= 1'b0;
            center_s1_r <= 8'd0;
            p11_s1_r <= 8'd0;
            p12_s1_r <= 8'd0;
            p13_s1_r <= 8'd0;
            p21_s1_r <= 8'd0;
            p23_s1_r <= 8'd0;
            p31_s1_r <= 8'd0;
            p32_s1_r <= 8'd0;
            p33_s1_r <= 8'd0;
        end else if (frame_clr) begin
            col_cnt <= 12'd0;
            row_cnt <= 12'd0;
            din_vld_d1 <= 1'b0;
            din_vld_d2 <= 1'b0;
            din_d1 <= 8'd0;
            din_d2 <= 8'd0;
            col_d1 <= 11'd0;
            col_d2 <= 11'd0;
            row_d1 <= 12'd0;
            row_d2 <= 12'd0;
            line1_q_d1 <= 8'd0;
            matrix_11 <= 8'd0;
            matrix_12 <= 8'd0;
            matrix_13 <= 8'd0;
            matrix_21 <= 8'd0;
            matrix_22 <= 8'd0;
            matrix_23 <= 8'd0;
            matrix_31 <= 8'd0;
            matrix_32 <= 8'd0;
            matrix_33 <= 8'd0;
            pix_vld <= 1'b0;
            filt_vld_r <= 1'b0;
            center_s1_r <= 8'd0;
            p11_s1_r <= 8'd0;
            p12_s1_r <= 8'd0;
            p13_s1_r <= 8'd0;
            p21_s1_r <= 8'd0;
            p23_s1_r <= 8'd0;
            p31_s1_r <= 8'd0;
            p32_s1_r <= 8'd0;
            p33_s1_r <= 8'd0;
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

            if (din_vld_d2) begin
                if (col_d2 == H_LAST_COL) begin
                    matrix_11 <= 8'd0;
                    matrix_12 <= 8'd0;
                    matrix_13 <= 8'd0;
                    matrix_21 <= 8'd0;
                    matrix_22 <= 8'd0;
                    matrix_23 <= 8'd0;
                    matrix_31 <= 8'd0;
                    matrix_32 <= 8'd0;
                    matrix_33 <= 8'd0;
                end else begin
                    matrix_11 <= final_m11_w;
                    matrix_12 <= topref_m12_w;
                    matrix_13 <= topref_m13_w;
                    matrix_21 <= final_m21_w;
                    matrix_22 <= shift_m22_w;
                    matrix_23 <= shift_m23_w;
                    matrix_31 <= final_m31_w;
                    matrix_32 <= shift_m32_w;
                    matrix_33 <= shift_m33_w;
                end

                pix_vld  <= 1'b1;
            end else begin
                pix_vld  <= 1'b0;
            end

            filt_vld_r <= pix_vld;
            if (pix_vld) begin
                center_s1_r <= matrix_22;
                p11_s1_r <= p11_w;
                p12_s1_r <= p12_w;
                p13_s1_r <= p13_w;
                p21_s1_r <= p21_w;
                p23_s1_r <= p23_w;
                p31_s1_r <= p31_w;
                p32_s1_r <= p32_w;
                p33_s1_r <= p33_w;
            end else begin
                center_s1_r <= 8'd0;
                p11_s1_r <= 8'd0;
                p12_s1_r <= 8'd0;
                p13_s1_r <= 8'd0;
                p21_s1_r <= 8'd0;
                p23_s1_r <= 8'd0;
                p31_s1_r <= 8'd0;
                p32_s1_r <= 8'd0;
                p33_s1_r <= 8'd0;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_vld <= 1'b0;
            out_center <= 8'd0;
            out_filtered <= 8'd0;
        end else if (frame_clr) begin
            out_vld <= 1'b0;
            out_center <= 8'd0;
            out_filtered <= 8'd0;
        end else begin
            out_vld <= filt_vld_r;
            if (filt_vld_r) begin
                out_center <= center_s1_r;
                if (ENABLE != 0)
                    out_filtered <= filtered_px_w;
                else
                    out_filtered <= center_s1_r;
            end else begin
                out_center <= 8'd0;
                out_filtered <= 8'd0;
            end
        end
    end

endmodule
