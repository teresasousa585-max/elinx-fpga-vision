`timescale 1ns/1ps

module rgb_ccm_3x3_stage
#(
    parameter signed [11:0] M_RR = 12'sd256,
    parameter signed [11:0] M_RG = 12'sd0,
    parameter signed [11:0] M_RB = 12'sd0,
    parameter signed [11:0] M_GR = 12'sd0,
    parameter signed [11:0] M_GG = 12'sd256,
    parameter signed [11:0] M_GB = 12'sd0,
    parameter signed [11:0] M_BR = 12'sd0,
    parameter signed [11:0] M_BG = 12'sd0,
    parameter signed [11:0] M_BB = 12'sd256
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

    localparam integer STAGE_LATENCY = 2;

    reg        vsync_d0_r;
    reg        vsync_d1_r;
    reg        hsync_d0_r;
    reg        hsync_d1_r;
    reg [10:0] x_d0_r;
    reg [10:0] x_d1_r;
    reg [10:0] y_d0_r;
    reg [10:0] y_d1_r;

    assign out_vsync = vsync_d1_r;
    assign out_hsync = hsync_d1_r;
    assign out_x = out_de ? x_d1_r : 11'd0;
    assign out_y = out_de ? y_d1_r : 11'd0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            vsync_d0_r <= 1'b0;
            vsync_d1_r <= 1'b0;
            hsync_d0_r <= 1'b0;
            hsync_d1_r <= 1'b0;
            x_d0_r <= 11'd0;
            x_d1_r <= 11'd0;
            y_d0_r <= 11'd0;
            y_d1_r <= 11'd0;
        end else begin
            vsync_d0_r <= in_vsync;
            vsync_d1_r <= vsync_d0_r;
            hsync_d0_r <= in_hsync;
            hsync_d1_r <= hsync_d0_r;
            x_d0_r <= in_x;
            x_d1_r <= x_d0_r;
            y_d0_r <= in_y;
            y_d1_r <= y_d0_r;
        end
    end

    rgb_ccm_3x3 #(
        .M_RR(M_RR),
        .M_RG(M_RG),
        .M_RB(M_RB),
        .M_GR(M_GR),
        .M_GG(M_GG),
        .M_GB(M_GB),
        .M_BR(M_BR),
        .M_BG(M_BG),
        .M_BB(M_BB)
    ) u_core (
        .clk    (clk),
        .rst_n  (rst_n),
        .in_de  (in_de),
        .in_rgb (in_rgb),
        .out_de (out_de),
        .out_rgb(out_rgb)
    );

endmodule
