module stream_plane_delay2_3x3
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

    wire        de1_w;
    wire        de2_w;
    wire [7:0]  center1_w;
    wire [7:0]  center2_w;

    stream_plane_center_delay_3x3
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

    stream_plane_center_delay_3x3
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
        .out_vld    (de2_w),
        .out_center (center2_w)
    );

    assign out_vld = de2_w;
    assign out_center = center2_w;

endmodule

module stream_plane_center_delay_3x3
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

    localparam [10:0] H_LAST_COL = H_DISP - 1;

    wire [7:0] line1_q;

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
    reg  [7:0]  matrix_22;
    reg  [7:0]  matrix_23;
    reg         pix_vld;
    reg         center_vld_r;
    reg  [7:0]  center_s1_r;
    wire [7:0]  vertical_src_w = (row_d2 == 12'd0) ? 8'd0 : line1_q_d1;

    m4k_linebuf_2048x8 u_line_buf_1
    (
        .clock      (clk),
        .wren       (din_vld),
        .wraddress  (col_cnt[10:0]),
        .data       (din),
        .rdaddress  (col_cnt[10:0]),
        .q          (line1_q)
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
            matrix_22 <= 8'd0;
            matrix_23 <= 8'd0;
            pix_vld <= 1'b0;
            center_vld_r <= 1'b0;
            center_s1_r <= 8'd0;
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
            matrix_22 <= 8'd0;
            matrix_23 <= 8'd0;
            pix_vld <= 1'b0;
            center_vld_r <= 1'b0;
            center_s1_r <= 8'd0;
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
                    matrix_22 <= 8'd0;
                    matrix_23 <= 8'd0;
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
                center_s1_r <= 8'd0;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_vld <= 1'b0;
            out_center <= 8'd0;
        end else if (frame_clr) begin
            out_vld <= 1'b0;
            out_center <= 8'd0;
        end else begin
            out_vld <= center_vld_r;
            out_center <= center_vld_r ? center_s1_r : 8'd0;
        end
    end

endmodule
