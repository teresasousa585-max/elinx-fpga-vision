`timescale 1ns/1ns

module rgb_video_pipeline
#(
    parameter H_DISP = 1280,
    parameter V_DISP = 720,
    parameter integer EXTERNAL_LATENCY = 179
)
(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        in_frame_start,
    input  wire        in_frame_end,
    input  wire        in_hs,
    input  wire        in_vs,
    input  wire        in_de,
    input  wire [10:0] in_x,
    input  wire [10:0] in_y,
    input  wire [7:0]  in_raw8,
    input  wire [23:0] in_rgb888,
    input  wire [1:0]  active_color_mode,
    input  wire [3:0]  active_stage_view,
    input  wire [1:0]  active_skin_level,
    input  wire [1:0]  active_color_temp,
    output wire        out_frame_start,
    output wire        out_frame_end,
    output wire        out_hs,
    output wire        out_vs,
    output wire        out_de,
    output wire [10:0] out_x,
    output wire [10:0] out_y,
    output wire [7:0]  out_raw8,
    output wire [23:0] out_rgb888
);

wire        delayed_frame_start_w;
wire        delayed_frame_end_w;
wire        delayed_hs_w;
wire        delayed_vs_w;
wire        delayed_de_w;
wire [10:0] delayed_x_w;
wire [10:0] delayed_y_w;
wire [7:0]  delayed_raw8_w;
wire [23:0] delayed_rgb888_w;
wire        vip_vs_w;
wire        vip_hs_w;
wire        vip_de_w;
wire [23:0] vip_rgb_w;
wire [10:0] vip_x_w;
wire [10:0] vip_y_w;

video_bundle_delay
#(
    .LATENCY (EXTERNAL_LATENCY)
)
u_rgb_sideband_delay
(
    .clk             (clk),
    .rst_n           (rst_n),
    .in_frame_start  (in_frame_start),
    .in_frame_end    (in_frame_end),
    .in_hs           (in_hs),
    .in_vs           (in_vs),
    .in_de           (in_de),
    .in_x            (in_x),
    .in_y            (in_y),
    .in_raw8         (in_raw8),
    .in_rgb888       (in_rgb888),
    .out_frame_start (delayed_frame_start_w),
    .out_frame_end   (delayed_frame_end_w),
    .out_hs          (delayed_hs_w),
    .out_vs          (delayed_vs_w),
    .out_de          (delayed_de_w),
    .out_x           (delayed_x_w),
    .out_y           (delayed_y_w),
    .out_raw8        (delayed_raw8_w),
    .out_rgb888      (delayed_rgb888_w)
);

vip_raw2rgb
#(
    .H_DISP                    (H_DISP),
    .V_DISP                    (V_DISP),
    .BAYER_MODE                (0),
    .BLC_EN                    (1),
    .BLC_OFFSET_R              (8'd8),
    .BLC_OFFSET_GR             (8'd8),
    .BLC_OFFSET_GB             (8'd8),
    .BLC_OFFSET_B              (8'd8),
    .RAW_PRE_GAIN_EN           (1),
    .RAW_PRE_GAIN_R            (9'd257),
    .RAW_PRE_GAIN_GR           (9'd256),
    .RAW_PRE_GAIN_GB           (9'd256),
    .RAW_PRE_GAIN_B            (9'd254),
    .AWB_R_GAIN                (9'd324),
    .AWB_G_GAIN                (9'd256),
    .AWB_B_GAIN                (9'd307),
    .CCM_RR                    (12'sd326),
    .CCM_RG                    (-12'sd56),
    .CCM_RB                    (-12'sd11),
    .CCM_GR                    (-12'sd24),
    .CCM_GG                    (12'sd290),
    .CCM_GB                    (-12'sd10),
    .CCM_BR                    (-12'sd24),
    .CCM_BG                    (-12'sd48),
    .CCM_BB                    (12'sd327),
    .POST_CCM_EN               (1),
    .POST_CCM_RR               (12'sd296),
    .POST_CCM_RG               (12'sd0),
    .POST_CCM_RB               (-12'sd40),
    .POST_CCM_GR               (-12'sd36),
    .POST_CCM_GG               (12'sd303),
    .POST_CCM_GB               (-12'sd11),
    .POST_CCM_BR               (-12'sd45),
    .POST_CCM_BG               (12'sd0),
    .POST_CCM_BB               (12'sd301),
    .PRECNR_CHROMA_GAIN_EN     (1),
    .PRECNR_CHROMA_GAIN_Q8     (10'd256),
    .FLATTEN_MODE              (2'd0),
    .FLAT_SUPPORT_EN           (1),
    .DELTA_SAFE_FLATTEN_EN     (0),
    .CHROMA_SMEAR_FLATTEN_EN   (0),
    .LUMA_BILATERAL_EN         (1),
    .LUMA_BILATERAL_TH         (8'd12),
    .GAMMA_EN                  (1),
    .GAMMA_MODE                (2),
    .GAMMA_LOW_CHROMA_TH       (8'd12),
    .TONE_EN                   (1),
    .TONE_PROFILE              (4'd1),
    .TUNE_EN                   (1),
    .TUNE_SAT_POS_SHIFT        (4'd4),
    .TUNE_SAT_NEG_SHIFT        (4'd6),
    .TUNE_LIFT_SHIFT           (4'd0),
    .TUNE_R_OFFSET             (9'sd0),
    .TUNE_G_OFFSET             (9'sd0),
    .TUNE_B_OFFSET             (9'sd0),
    .COLOR_TEMP_COOL_R_OFFSET  (-9'sd8),
    .COLOR_TEMP_COOL_G_OFFSET  (9'sd0),
    .COLOR_TEMP_COOL_B_OFFSET  (9'sd10),
    .COLOR_TEMP_WARM_R_OFFSET  (9'sd10),
    .COLOR_TEMP_WARM_G_OFFSET  (9'sd0),
    .COLOR_TEMP_WARM_B_OFFSET  (-9'sd8),
    .OUTPUT_BLACK_MASK_LEFT_PX (0),
    .OUTPUT_BLACK_MASK_RIGHT_PX(0),
    .OUTPUT_BLACK_MASK_TOP_PX  (0),
    .OUTPUT_BLACK_MASK_BOTTOM_PX(0)
)
u_vip_raw2rgb
(
    .clk                       (clk),
    .rst_n                     (rst_n),
    .pre_frame_vsync           (in_vs),
    .pre_frame_hsync           (in_hs),
    .pre_frame_de              (in_de),
    .pre_raw                   (in_raw8),
    .xpos                      (in_x),
    .ypos                      (in_y),
    .runtime_color_mode_sel    (active_color_mode),
    .runtime_stage56_mode_sel  (active_stage_view),
    .runtime_skin_level_sel    (active_skin_level),
    .runtime_color_temp_sel    (active_color_temp),
    .post_frame_vsync          (vip_vs_w),
    .post_frame_hsync          (vip_hs_w),
    .post_frame_de             (vip_de_w),
    .post_rgb                  (vip_rgb_w),
    .post_xpos                 (vip_x_w),
    .post_ypos                 (vip_y_w),
    .mon_pre_vsync             (),
    .mon_pre_hsync             (),
    .mon_pre_de                (),
    .mon_pre_raw               (),
    .mon_pre_xpos              (),
    .mon_pre_ypos              (),
    .mon_core_vsync            (),
    .mon_core_hsync            (),
    .mon_core_de               (),
    .mon_core_rgb              (),
    .mon_core_xpos             (),
    .mon_core_ypos             ()
);

assign out_frame_start = delayed_frame_start_w;
assign out_frame_end   = delayed_frame_end_w;
assign out_hs          = vip_hs_w;
assign out_vs          = vip_vs_w;
assign out_de          = vip_de_w;
assign out_x           = vip_x_w;
assign out_y           = vip_y_w;
assign out_raw8        = delayed_raw8_w;
assign out_rgb888      = vip_rgb_w;

endmodule
