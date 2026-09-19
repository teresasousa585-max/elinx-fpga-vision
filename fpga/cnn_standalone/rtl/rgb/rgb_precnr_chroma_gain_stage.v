`timescale 1ns/1ps

module rgb_precnr_chroma_gain_stage
#(
    parameter integer ENABLE = 1,
    parameter [9:0] GAIN_Q8 = 10'd297
)
(
    input  wire        clk,
    input  wire        rst_n,

    input  wire        in_vsync,
    input  wire        in_hsync,
    input  wire        in_de,
    input  wire [10:0] in_x,
    input  wire [10:0] in_y,
    input  wire [23:0] in_rgb,

    output wire        out_vsync,
    output wire        out_hsync,
    output wire        out_de,
    output wire [10:0] out_x,
    output wire [10:0] out_y,
    output wire [23:0] out_rgb
);

    localparam integer STAGE_LATENCY = 3;

    reg        vsync_d0_r;
    reg        vsync_d1_r;
    reg        vsync_d2_r;
    reg        hsync_d0_r;
    reg        hsync_d1_r;
    reg        hsync_d2_r;
    reg [10:0] x_d0_r;
    reg [10:0] x_d1_r;
    reg [10:0] x_d2_r;
    reg [10:0] y_d0_r;
    reg [10:0] y_d1_r;
    reg [10:0] y_d2_r;

    assign out_vsync = vsync_d2_r;
    assign out_hsync = hsync_d2_r;
    assign out_x = out_de ? x_d2_r : 11'd0;
    assign out_y = out_de ? y_d2_r : 11'd0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            vsync_d0_r <= 1'b0;
            vsync_d1_r <= 1'b0;
            vsync_d2_r <= 1'b0;
            hsync_d0_r <= 1'b0;
            hsync_d1_r <= 1'b0;
            hsync_d2_r <= 1'b0;
            x_d0_r <= 11'd0;
            x_d1_r <= 11'd0;
            x_d2_r <= 11'd0;
            y_d0_r <= 11'd0;
            y_d1_r <= 11'd0;
            y_d2_r <= 11'd0;
        end else begin
            vsync_d0_r <= in_vsync;
            vsync_d1_r <= vsync_d0_r;
            vsync_d2_r <= vsync_d1_r;
            hsync_d0_r <= in_hsync;
            hsync_d1_r <= hsync_d0_r;
            hsync_d2_r <= hsync_d1_r;
            x_d0_r <= in_x;
            x_d1_r <= x_d0_r;
            x_d2_r <= x_d1_r;
            y_d0_r <= in_y;
            y_d1_r <= y_d0_r;
            y_d2_r <= y_d1_r;
        end
    end

    rgb_precnr_chroma_gain #(
        .ENABLE (ENABLE),
        .GAIN_Q8(GAIN_Q8)
    ) u_core (
        .clk    (clk),
        .rst_n  (rst_n),
        .in_de  (in_de),
        .in_rgb (in_rgb),
        .out_de (out_de),
        .out_rgb(out_rgb)
    );

endmodule
