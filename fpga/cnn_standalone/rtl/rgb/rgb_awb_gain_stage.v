`timescale 1ns/1ps

module rgb_awb_gain_stage
#(
    parameter [8:0] R_GAIN = 9'd256,
    parameter [8:0] G_GAIN = 9'd256,
    parameter [8:0] B_GAIN = 9'd256
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

    localparam integer STAGE_LATENCY = 1;

    reg        vsync_d1_r;
    reg        hsync_d1_r;
    reg [10:0] x_d1_r;
    reg [10:0] y_d1_r;

    assign out_vsync = vsync_d1_r;
    assign out_hsync = hsync_d1_r;
    assign out_x = out_de ? x_d1_r : 11'd0;
    assign out_y = out_de ? y_d1_r : 11'd0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            vsync_d1_r <= 1'b0;
            hsync_d1_r <= 1'b0;
            x_d1_r <= 11'd0;
            y_d1_r <= 11'd0;
        end else begin
            vsync_d1_r <= in_vsync;
            hsync_d1_r <= in_hsync;
            x_d1_r <= in_x;
            y_d1_r <= in_y;
        end
    end

    rgb_awb_gain #(
        .R_GAIN(R_GAIN),
        .G_GAIN(G_GAIN),
        .B_GAIN(B_GAIN)
    ) u_core (
        .clk    (clk),
        .rst_n  (rst_n),
        .in_de  (in_de),
        .in_rgb (in_rgb),
        .out_de (out_de),
        .out_rgb(out_rgb)
    );

endmodule
