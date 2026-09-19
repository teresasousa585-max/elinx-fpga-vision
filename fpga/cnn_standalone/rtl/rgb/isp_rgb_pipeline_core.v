`timescale 1ns/1ps

module isp_rgb_pipeline_core
#(
    parameter integer H_DISP = 1280,
    parameter integer V_DISP = 720,

    parameter [8:0] AWB_R_GAIN = 9'd324,
    parameter [8:0] AWB_G_GAIN = 9'd256,
    parameter [8:0] AWB_B_GAIN = 9'd307,

    parameter signed [11:0] CCM_M_RR = 12'sd326,
    parameter signed [11:0] CCM_M_RG = -12'sd56,
    parameter signed [11:0] CCM_M_RB = -12'sd11,
    parameter signed [11:0] CCM_M_GR = -12'sd24,
    parameter signed [11:0] CCM_M_GG = 12'sd290,
    parameter signed [11:0] CCM_M_GB = -12'sd10,
    parameter signed [11:0] CCM_M_BR = -12'sd24,
    parameter signed [11:0] CCM_M_BG = -12'sd48,
    parameter signed [11:0] CCM_M_BB = 12'sd327,

    parameter integer PRECNR_ENABLE = 1,
    parameter [9:0] PRECNR_GAIN_Q8 = 10'd256
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
    output wire [23:0] out_rgb,

    output wire        tap0_de,
    output wire [23:0] tap0_rgb,
    output wire        tap1_de,
    output wire [23:0] tap1_rgb,
    output wire        tap2_de,
    output wire [23:0] tap2_rgb,
    output wire        tap3_de,
    output wire [23:0] tap3_rgb,
    output wire        tap4_de,
    output wire [23:0] tap4_rgb,
    output wire        tap5_de,
    output wire [23:0] tap5_rgb
);

    wire        awb_vsync_w;
    wire        awb_hsync_w;
    wire        awb_de_w;
    wire [10:0] awb_x_w;
    wire [10:0] awb_y_w;
    wire [23:0] awb_rgb_w;

    wire        ccm_vsync_w;
    wire        ccm_hsync_w;
    wire        ccm_de_w;
    wire [10:0] ccm_x_w;
    wire [10:0] ccm_y_w;
    wire [23:0] ccm_rgb_w;

    rgb_awb_gain_stage #(
        .R_GAIN(AWB_R_GAIN),
        .G_GAIN(AWB_G_GAIN),
        .B_GAIN(AWB_B_GAIN)
    ) u_awb_gain_stage (
        .clk(clk),
        .rst_n(rst_n),
        .in_vsync(in_vsync),
        .in_hsync(in_hsync),
        .in_de(in_de),
        .in_x(in_x),
        .in_y(in_y),
        .in_rgb(in_rgb),
        .out_vsync(awb_vsync_w),
        .out_hsync(awb_hsync_w),
        .out_de(awb_de_w),
        .out_x(awb_x_w),
        .out_y(awb_y_w),
        .out_rgb(awb_rgb_w)
    );

    rgb_ccm_3x3_stage #(
        .M_RR(CCM_M_RR),
        .M_RG(CCM_M_RG),
        .M_RB(CCM_M_RB),
        .M_GR(CCM_M_GR),
        .M_GG(CCM_M_GG),
        .M_GB(CCM_M_GB),
        .M_BR(CCM_M_BR),
        .M_BG(CCM_M_BG),
        .M_BB(CCM_M_BB)
    ) u_ccm_3x3_stage (
        .clk(clk),
        .rst_n(rst_n),
        .in_vsync(awb_vsync_w),
        .in_hsync(awb_hsync_w),
        .in_de(awb_de_w),
        .in_x(awb_x_w),
        .in_y(awb_y_w),
        .in_rgb(awb_rgb_w),
        .out_vsync(ccm_vsync_w),
        .out_hsync(ccm_hsync_w),
        .out_de(ccm_de_w),
        .out_x(ccm_x_w),
        .out_y(ccm_y_w),
        .out_rgb(ccm_rgb_w)
    );

    rgb_precnr_chroma_gain_stage #(
        .ENABLE(PRECNR_ENABLE),
        .GAIN_Q8(PRECNR_GAIN_Q8)
    ) u_precnr_chroma_gain_stage (
        .clk(clk),
        .rst_n(rst_n),
        .in_vsync(ccm_vsync_w),
        .in_hsync(ccm_hsync_w),
        .in_de(ccm_de_w),
        .in_x(ccm_x_w),
        .in_y(ccm_y_w),
        .in_rgb(ccm_rgb_w),
        .out_vsync(out_vsync),
        .out_hsync(out_hsync),
        .out_de(out_de),
        .out_x(out_x),
        .out_y(out_y),
        .out_rgb(out_rgb)
    );

    assign tap0_de  = awb_de_w;
    assign tap0_rgb = awb_rgb_w;
    assign tap1_de  = ccm_de_w;
    assign tap1_rgb = ccm_rgb_w;
    assign tap2_de  = out_de;
    assign tap2_rgb = out_rgb;
    assign tap3_de  = out_de;
    assign tap3_rgb = out_rgb;
    assign tap4_de  = out_de;
    assign tap4_rgb = out_rgb;
    assign tap5_de  = out_de;
    assign tap5_rgb = out_rgb;

endmodule
