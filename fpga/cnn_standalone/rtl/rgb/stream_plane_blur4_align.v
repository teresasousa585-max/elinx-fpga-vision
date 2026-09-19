module stream_plane_blur4_align
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
    output  wire  [7:0]   out_blur2,
    output  wire  [7:0]   out_blur4
);

    wire        center_de_w;
    wire [7:0]  center_d4_w;

    wire        de1_w;
    wire        de2_w;
    wire        de3_w;
    wire        de4_w;
    wire [7:0]  center1_unused_w;
    wire [7:0]  center2_unused_w;
    wire [7:0]  center3_unused_w;
    wire [7:0]  center4_unused_w;
    wire [7:0]  blur1_w;
    wire [7:0]  blur2_w;
    wire [7:0]  blur3_w;
    wire [7:0]  blur4_w;

    wire        blur2_dly_de_w;
    wire [7:0]  blur2_dly_w;

    stream_plane_delay4_3x3
    #(
        .H_DISP (H_DISP),
        .V_DISP (V_DISP)
    )
    u_center_delay4
    (
        .clk        (clk),
        .rst_n      (rst_n),
        .frame_clr  (frame_clr),
        .din_vld    (din_vld),
        .din        (din),
        .out_vld    (center_de_w),
        .out_center (center_d4_w)
    );

    stream_plane_bilateral_3x3
    #(
        .H_DISP   (H_DISP),
        .V_DISP   (V_DISP),
        .ENABLE   (ENABLE),
        .RANGE_TH (8'd255)
    )
    u_blur1
    (
        .clk          (clk),
        .rst_n        (rst_n),
        .frame_clr    (frame_clr),
        .din_vld      (din_vld),
        .din          (din),
        .out_vld      (de1_w),
        .out_center   (center1_unused_w),
        .out_filtered (blur1_w)
    );

    stream_plane_bilateral_3x3
    #(
        .H_DISP   (H_DISP),
        .V_DISP   (V_DISP),
        .ENABLE   (ENABLE),
        .RANGE_TH (8'd255)
    )
    u_blur2
    (
        .clk          (clk),
        .rst_n        (rst_n),
        .frame_clr    (frame_clr),
        .din_vld      (de1_w),
        .din          (blur1_w),
        .out_vld      (de2_w),
        .out_center   (center2_unused_w),
        .out_filtered (blur2_w)
    );

    stream_plane_bilateral_3x3
    #(
        .H_DISP   (H_DISP),
        .V_DISP   (V_DISP),
        .ENABLE   (ENABLE),
        .RANGE_TH (8'd255)
    )
    u_blur3
    (
        .clk          (clk),
        .rst_n        (rst_n),
        .frame_clr    (frame_clr),
        .din_vld      (de2_w),
        .din          (blur2_w),
        .out_vld      (de3_w),
        .out_center   (center3_unused_w),
        .out_filtered (blur3_w)
    );

    stream_plane_bilateral_3x3
    #(
        .H_DISP   (H_DISP),
        .V_DISP   (V_DISP),
        .ENABLE   (ENABLE),
        .RANGE_TH (8'd255)
    )
    u_blur4
    (
        .clk          (clk),
        .rst_n        (rst_n),
        .frame_clr    (frame_clr),
        .din_vld      (de3_w),
        .din          (blur3_w),
        .out_vld      (de4_w),
        .out_center   (center4_unused_w),
        .out_filtered (blur4_w)
    );

    stream_plane_delay2_3x3
    #(
        .H_DISP (H_DISP),
        .V_DISP (V_DISP)
    )
    u_blur2_delay2
    (
        .clk        (clk),
        .rst_n      (rst_n),
        .frame_clr  (frame_clr),
        .din_vld    (de2_w),
        .din        (blur2_w),
        .out_vld    (blur2_dly_de_w),
        .out_center (blur2_dly_w)
    );

    assign out_vld = center_de_w & blur2_dly_de_w & de4_w;
    assign out_center = center_d4_w;
    assign out_blur2 = blur2_dly_w;
    assign out_blur4 = blur4_w;

endmodule
