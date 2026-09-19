`timescale 1ns/1ns

module vip_raw2rgb
#(
    parameter H_DISP        = 1280,
    parameter V_DISP        = 720,
    parameter BAYER_MODE    = 0,
    parameter BLC_EN        = 1,
    parameter BLC_OFFSET_R  = 8'd8,
    parameter BLC_OFFSET_GR = 8'd8,
    parameter BLC_OFFSET_GB = 8'd8,
    parameter BLC_OFFSET_B  = 8'd8,
    parameter RAW_PRE_GAIN_EN = 0,
    parameter [8:0] RAW_PRE_GAIN_R  = 9'd256,
    parameter [8:0] RAW_PRE_GAIN_GR = 9'd256,
    parameter [8:0] RAW_PRE_GAIN_GB = 9'd256,
    parameter [8:0] RAW_PRE_GAIN_B  = 9'd256,
    parameter AWB_R_GAIN    = 9'd256,
    parameter AWB_G_GAIN    = 9'd256,
    parameter AWB_B_GAIN    = 9'd256,
    parameter signed [11:0] CCM_RR = 12'sd256,
    parameter signed [11:0] CCM_RG = 12'sd0,
    parameter signed [11:0] CCM_RB = 12'sd0,
    parameter signed [11:0] CCM_GR = 12'sd0,
    parameter signed [11:0] CCM_GG = 12'sd256,
    parameter signed [11:0] CCM_GB = 12'sd0,
    parameter signed [11:0] CCM_BR = 12'sd0,
    parameter signed [11:0] CCM_BG = 12'sd0,
    parameter signed [11:0] CCM_BB = 12'sd256,
    parameter POST_CCM_EN   = 0,
    parameter signed [11:0] POST_CCM_RR = 12'sd256,
    parameter signed [11:0] POST_CCM_RG = 12'sd0,
    parameter signed [11:0] POST_CCM_RB = 12'sd0,
    parameter signed [11:0] POST_CCM_GR = 12'sd0,
    parameter signed [11:0] POST_CCM_GG = 12'sd256,
    parameter signed [11:0] POST_CCM_GB = 12'sd0,
    parameter signed [11:0] POST_CCM_BR = 12'sd0,
    parameter signed [11:0] POST_CCM_BG = 12'sd0,
    parameter signed [11:0] POST_CCM_BB = 12'sd256,
    parameter PRECNR_CHROMA_GAIN_EN = 0,
    parameter [9:0] PRECNR_CHROMA_GAIN_Q8 = 10'd256,
    parameter [1:0] FLATTEN_MODE = 2'd0,
    parameter FLAT_SUPPORT_EN = 1,
    parameter DELTA_SAFE_FLATTEN_EN = 0,
    parameter integer CHROMA_SMEAR_FLATTEN_EN = 0,
    parameter LUMA_BILATERAL_EN = 0,
    parameter [7:0] LUMA_BILATERAL_TH = 8'd8,
    parameter GAMMA_EN = 1,
    parameter integer GAMMA_MODE = 1,
    parameter [7:0] GAMMA_LOW_CHROMA_TH = 8'd12,
    parameter TONE_EN  = 0,
    parameter [3:0] TONE_PROFILE = 4'd0,
    parameter TUNE_EN  = 1,
    parameter [3:0] TUNE_SAT_POS_SHIFT = 4'd2,
    parameter [3:0] TUNE_SAT_NEG_SHIFT = 4'd3,
    parameter [3:0] TUNE_LIFT_SHIFT    = 4'd4,
    parameter signed [8:0] TUNE_R_OFFSET = 9'sd12,
    parameter signed [8:0] TUNE_G_OFFSET = 9'sd6,
    parameter signed [8:0] TUNE_B_OFFSET = -9'sd10,
    parameter signed [8:0] COLOR_TEMP_COOL_R_OFFSET = -9'sd8,
    parameter signed [8:0] COLOR_TEMP_COOL_G_OFFSET =  9'sd0,
    parameter signed [8:0] COLOR_TEMP_COOL_B_OFFSET =  9'sd10,
    parameter signed [8:0] COLOR_TEMP_WARM_R_OFFSET =  9'sd10,
    parameter signed [8:0] COLOR_TEMP_WARM_G_OFFSET =  9'sd0,
    parameter signed [8:0] COLOR_TEMP_WARM_B_OFFSET = -9'sd8,
    parameter integer OUTPUT_BLACK_MASK_LEFT_PX = 0,
    parameter integer OUTPUT_BLACK_MASK_RIGHT_PX = 0,
    parameter integer OUTPUT_BLACK_MASK_TOP_PX  = 0,
    parameter integer OUTPUT_BLACK_MASK_BOTTOM_PX = 0
)
(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        pre_frame_vsync,
    input  wire        pre_frame_hsync,
    input  wire        pre_frame_de,
    input  wire [7:0]  pre_raw,
    input  wire [10:0] xpos,
    input  wire [10:0] ypos,
    input  wire [1:0]  runtime_color_mode_sel,
    input  wire [3:0]  runtime_stage56_mode_sel,
    input  wire [1:0]  runtime_skin_level_sel,
    input  wire [1:0]  runtime_color_temp_sel,

    output wire        post_frame_vsync,
    output wire        post_frame_hsync,
    output wire        post_frame_de,
    output wire [23:0] post_rgb,
    output wire [10:0] post_xpos,
    output wire [10:0] post_ypos,

    output wire        mon_pre_vsync,
    output wire        mon_pre_hsync,
    output wire        mon_pre_de,
    output wire [7:0]  mon_pre_raw,
    output wire [10:0] mon_pre_xpos,
    output wire [10:0] mon_pre_ypos,
    output wire        mon_core_vsync,
    output wire        mon_core_hsync,
    output wire        mon_core_de,
    output wire [23:0] mon_core_rgb,
    output wire [10:0] mon_core_xpos,
    output wire [10:0] mon_core_ypos
);

localparam integer PIPELINE_LATENCY = 175;
localparam [10:0] H_DISP_U11 = H_DISP;
localparam [10:0] V_DISP_U11 = V_DISP;
localparam [10:0] OUTPUT_BLACK_MASK_LEFT_U11 = OUTPUT_BLACK_MASK_LEFT_PX;
localparam [10:0] OUTPUT_BLACK_MASK_RIGHT_U11 = OUTPUT_BLACK_MASK_RIGHT_PX;
localparam [10:0] OUTPUT_BLACK_MASK_TOP_U11 = OUTPUT_BLACK_MASK_TOP_PX;
localparam [10:0] OUTPUT_BLACK_MASK_BOTTOM_U11 = OUTPUT_BLACK_MASK_BOTTOM_PX;
localparam FLATTEN_NATIVE = 2'd0;
localparam FLATTEN_SLIGHT = 2'd1;
localparam FLATTEN_FLAT   = 2'd2;
localparam [3:0] STAGE56_VIEW_RAW = 4'd0;
localparam [3:0] STAGE56_VIEW_RPG = 4'd1;
localparam [3:0] STAGE56_VIEW_DEB = 4'd2;
localparam [3:0] STAGE56_VIEW_AWB = 4'd3;
localparam [3:0] STAGE56_VIEW_CCM = 4'd4;
localparam [3:0] STAGE56_VIEW_PCG = 4'd5;
localparam [3:0] STAGE56_VIEW_FCD = 4'd6;
localparam [3:0] STAGE56_VIEW_GMA = 4'd7;
localparam [3:0] STAGE56_VIEW_TON = 4'd8;
localparam [3:0] STAGE56_VIEW_LBF = 4'd9;
localparam [3:0] STAGE56_VIEW_PCC = 4'd10;
localparam [3:0] STAGE56_VIEW_TUN = 4'd11;
localparam [3:0] STAGE56_VIEW_FINAL = 4'd12;
localparam [3:0] STAGE56_VIEW_LAST = STAGE56_VIEW_FINAL;
// Current line-window implementation is causal. Early stages expose startup
// bands on the left/top side. Later stages inherit the accumulated visible
// safety mask; they do not enlarge the final board-visible black border.
localparam [10:0] THEORY_MASK_NONE_U11 = 11'd0;
localparam [10:0] THEORY_WIN5_LEFT_U11 = 11'd5;
localparam [10:0] THEORY_WIN5_TOP_U11 = 11'd4;
localparam [10:0] THEORY_WIN5_RIGHT_U11 = 11'd0;
localparam [10:0] THEORY_WIN5_BOTTOM_U11 = 11'd0;
localparam [10:0] THEORY_DEB_MASK_LEFT_U11 = THEORY_WIN5_LEFT_U11;
localparam [10:0] THEORY_DEB_MASK_TOP_U11 = THEORY_WIN5_TOP_U11;
localparam [10:0] THEORY_DEB_MASK_RIGHT_U11 = THEORY_WIN5_RIGHT_U11;
localparam [10:0] THEORY_DEB_MASK_BOTTOM_U11 = THEORY_WIN5_BOTTOM_U11;
localparam [10:0] THEORY_LBF_MASK_LEFT_U11 = THEORY_DEB_MASK_LEFT_U11;
localparam [10:0] THEORY_LBF_MASK_TOP_U11 = THEORY_DEB_MASK_TOP_U11;
localparam [10:0] THEORY_LBF_MASK_RIGHT_U11 = THEORY_DEB_MASK_RIGHT_U11;
localparam [10:0] THEORY_LBF_MASK_BOTTOM_U11 = THEORY_DEB_MASK_BOTTOM_U11;
localparam [1:0] COLOR_MODE_LIGHT = 2'd0;
localparam [1:0] COLOR_MODE_BALANCED = 2'd1;
localparam [1:0] COLOR_MODE_VIVID = 2'd2;
localparam [1:0] SKIN_LEVEL_OFF = 2'd0;
localparam [1:0] SKIN_LEVEL_STRONG = 2'd1;
localparam [1:0] SKIN_LEVEL_VERYHIGH = 2'd2;
localparam [1:0] COLOR_TEMP_NEUTRAL = 2'd0;
localparam [1:0] COLOR_TEMP_COOL = 2'd1;
localparam [1:0] COLOR_TEMP_WARM = 2'd2;
localparam [3:0] COLOR_MODE_LIGHT_TUNE_SAT_POS_SHIFT = 4'd7;
localparam [3:0] COLOR_MODE_LIGHT_TUNE_SAT_NEG_SHIFT = 4'd7;
localparam [3:0] COLOR_MODE_LIGHT_TUNE_LIFT_SHIFT    = 4'd5;
localparam signed [8:0] COLOR_MODE_LIGHT_TUNE_R_OFFSET = 9'sd0;
localparam signed [8:0] COLOR_MODE_LIGHT_TUNE_G_OFFSET = 9'sd0;
localparam signed [8:0] COLOR_MODE_LIGHT_TUNE_B_OFFSET = 9'sd0;
localparam [3:0] COLOR_MODE_VIVID_TUNE_SAT_POS_SHIFT = 4'd2;
localparam [3:0] COLOR_MODE_VIVID_TUNE_SAT_NEG_SHIFT = 4'd4;
localparam [3:0] COLOR_MODE_VIVID_TUNE_LIFT_SHIFT    = 4'd0;
localparam signed [8:0] COLOR_MODE_VIVID_TUNE_R_OFFSET = 9'sd8;
localparam signed [8:0] COLOR_MODE_VIVID_TUNE_G_OFFSET = 9'sd0;
localparam signed [8:0] COLOR_MODE_VIVID_TUNE_B_OFFSET = 9'sd6;

localparam EFFECTIVE_LUMA_BILATERAL_EN =
    (FLATTEN_MODE == FLATTEN_NATIVE) ? LUMA_BILATERAL_EN : 1;
localparam [7:0] EFFECTIVE_LUMA_BILATERAL_TH =
    (FLATTEN_MODE == FLATTEN_SLIGHT) ? 8'd24 :
    ((FLATTEN_MODE == FLATTEN_FLAT) ? 8'd24 : LUMA_BILATERAL_TH);

wire [1:0] cfg_runtime_color_mode_sel =
    (runtime_color_mode_sel <= COLOR_MODE_VIVID) ? runtime_color_mode_sel : COLOR_MODE_BALANCED;
wire [1:0] cfg_runtime_skin_level_sel =
    (runtime_skin_level_sel <= SKIN_LEVEL_VERYHIGH) ? runtime_skin_level_sel : SKIN_LEVEL_OFF;
wire [1:0] cfg_runtime_color_temp_sel =
    (runtime_color_temp_sel <= COLOR_TEMP_WARM) ? runtime_color_temp_sel : COLOR_TEMP_NEUTRAL;
wire [3:0] stage56_runtime_view_sel_w =
    (runtime_stage56_mode_sel <= STAGE56_VIEW_LAST) ? runtime_stage56_mode_sel : STAGE56_VIEW_RAW;

function [10:0] max_u11;
    input [10:0] a;
    input [10:0] b;
    begin
        max_u11 = (a >= b) ? a : b;
    end
endfunction

function [10:0] stage56_theory_mask_left;
    input [3:0] stage_sel;
    begin
        case (stage_sel)
            STAGE56_VIEW_RAW,
            STAGE56_VIEW_RPG:
                stage56_theory_mask_left = THEORY_MASK_NONE_U11;
            STAGE56_VIEW_DEB,
            STAGE56_VIEW_AWB,
            STAGE56_VIEW_CCM,
            STAGE56_VIEW_PCG,
            STAGE56_VIEW_FCD,
            STAGE56_VIEW_GMA,
            STAGE56_VIEW_TON:
                stage56_theory_mask_left = THEORY_DEB_MASK_LEFT_U11;
            default:
                stage56_theory_mask_left = THEORY_LBF_MASK_LEFT_U11;
        endcase
    end
endfunction

function [10:0] stage56_theory_mask_right;
    input [3:0] stage_sel;
    begin
        case (stage_sel)
            STAGE56_VIEW_RAW,
            STAGE56_VIEW_RPG:
                stage56_theory_mask_right = THEORY_MASK_NONE_U11;
            STAGE56_VIEW_DEB,
            STAGE56_VIEW_AWB,
            STAGE56_VIEW_CCM,
            STAGE56_VIEW_PCG,
            STAGE56_VIEW_FCD,
            STAGE56_VIEW_GMA,
            STAGE56_VIEW_TON:
                stage56_theory_mask_right = THEORY_DEB_MASK_RIGHT_U11;
            default:
                stage56_theory_mask_right = THEORY_LBF_MASK_RIGHT_U11;
        endcase
    end
endfunction

function [10:0] stage56_theory_mask_top;
    input [3:0] stage_sel;
    begin
        case (stage_sel)
            STAGE56_VIEW_RAW,
            STAGE56_VIEW_RPG:
                stage56_theory_mask_top = THEORY_MASK_NONE_U11;
            STAGE56_VIEW_DEB,
            STAGE56_VIEW_AWB,
            STAGE56_VIEW_CCM,
            STAGE56_VIEW_PCG,
            STAGE56_VIEW_FCD,
            STAGE56_VIEW_GMA,
            STAGE56_VIEW_TON:
                stage56_theory_mask_top = THEORY_DEB_MASK_TOP_U11;
            default:
                stage56_theory_mask_top = THEORY_LBF_MASK_TOP_U11;
        endcase
    end
endfunction

function [10:0] stage56_theory_mask_bottom;
    input [3:0] stage_sel;
    begin
        case (stage_sel)
            STAGE56_VIEW_RAW,
            STAGE56_VIEW_RPG:
                stage56_theory_mask_bottom = THEORY_MASK_NONE_U11;
            STAGE56_VIEW_DEB,
            STAGE56_VIEW_AWB,
            STAGE56_VIEW_CCM,
            STAGE56_VIEW_PCG,
            STAGE56_VIEW_FCD,
            STAGE56_VIEW_GMA,
            STAGE56_VIEW_TON:
                stage56_theory_mask_bottom = THEORY_DEB_MASK_BOTTOM_U11;
            default:
                stage56_theory_mask_bottom = THEORY_LBF_MASK_BOTTOM_U11;
        endcase
    end
endfunction

function [10:0] stage56_output_mask_left;
    input [3:0] stage_sel;
    begin
        case (stage_sel)
            STAGE56_VIEW_RAW,
            STAGE56_VIEW_RPG:
                stage56_output_mask_left = THEORY_MASK_NONE_U11;
            default:
                stage56_output_mask_left = THEORY_DEB_MASK_LEFT_U11;
        endcase
    end
endfunction

function [10:0] stage56_output_mask_right;
    input [3:0] stage_sel;
    begin
        case (stage_sel)
            STAGE56_VIEW_RAW,
            STAGE56_VIEW_RPG:
                stage56_output_mask_right = THEORY_MASK_NONE_U11;
            default:
                stage56_output_mask_right = THEORY_DEB_MASK_RIGHT_U11;
        endcase
    end
endfunction

function [10:0] stage56_output_mask_top;
    input [3:0] stage_sel;
    begin
        case (stage_sel)
            STAGE56_VIEW_RAW,
            STAGE56_VIEW_RPG:
                stage56_output_mask_top = THEORY_MASK_NONE_U11;
            default:
                stage56_output_mask_top = THEORY_DEB_MASK_TOP_U11;
        endcase
    end
endfunction

function [10:0] stage56_output_mask_bottom;
    input [3:0] stage_sel;
    begin
        case (stage_sel)
            STAGE56_VIEW_RAW,
            STAGE56_VIEW_RPG:
                stage56_output_mask_bottom = THEORY_MASK_NONE_U11;
            default:
                stage56_output_mask_bottom = THEORY_DEB_MASK_BOTTOM_U11;
        endcase
    end
endfunction

wire        row_even_w;
wire        col_even_w;
wire        frame_clr_pulse_w;
wire [7:0]  raw_blc_w;
wire        raw_pre_gain_de_w;
wire        raw_pre_gain_row_even_w;
wire        raw_pre_gain_col_even_w;
wire [7:0]  raw_pre_gain_w;
// Keep the historical tap names alive so the existing actual RTL TB can probe
// the RAW-domain stream without being rewritten for this structural swap.
wire        edge_rgb_vld_w;
wire [23:0] edge_rgb_w;
wire        debayer_sel_de_w;
wire [23:0] debayer_sel_rgb_w;
wire        core_de_w;
wire [23:0] core_rgb_w;
wire        awb_de_w;
wire [23:0] awb_rgb_w;
wire        ccm_de_w;
wire [23:0] ccm_rgb_w;
wire        precnr_de_w;
wire [23:0] precnr_rgb_w;
wire        luma_bilat_de_w;
wire [23:0] luma_bilat_rgb_w;
wire        gamma_de_w;
wire [23:0] gamma_rgb_w;
wire        tone_de_w;
wire [23:0] tone_rgb_w;
wire        post_ccm_de_w;
wire [23:0] post_ccm_rgb_w;
wire        tune_src_de_w;
wire [23:0] tune_src_rgb_w;
wire        tune_light_de_w;
wire [23:0] tune_light_rgb_w;
wire        tune_balanced_de_w;
wire [23:0] tune_balanced_rgb_w;
wire        tune_vivid_de_w;
wire [23:0] tune_vivid_rgb_w;
wire        tune_mux_de_w;
wire [23:0] tune_mux_rgb_w;
wire        tune_de_w;
wire [23:0] tune_rgb_w;
wire        flat_chroma_de_w;
wire [23:0] flat_chroma_rgb_w;
wire        skin_smooth_de_w;
wire [23:0] skin_smooth_rgb_w;
wire        color_temp_de_w;
wire [23:0] color_temp_rgb_w;
wire [10:0] post_stream_xpos_w;
wire [10:0] post_stream_ypos_w;
wire [10:0] post_xpos_w;
wire [10:0] post_ypos_w;
wire        post_border_mask_w;
wire [10:0] post_mask_xpos_w;
wire [10:0] post_mask_ypos_w;
wire [10:0] output_black_right_start_w;
wire [10:0] output_black_bottom_start_w;
wire [10:0] stage56_theory_mask_left_w;
wire [10:0] stage56_theory_mask_right_w;
wire [10:0] stage56_theory_mask_top_w;
wire [10:0] stage56_theory_mask_bottom_w;
wire [10:0] stage56_output_mask_left_w;
wire [10:0] stage56_output_mask_right_w;
wire [10:0] stage56_output_mask_top_w;
wire [10:0] stage56_output_mask_bottom_w;
wire [10:0] stage56_effective_mask_left_w;
wire [10:0] stage56_effective_mask_right_w;
wire [10:0] stage56_effective_mask_top_w;
wire [10:0] stage56_effective_mask_bottom_w;
wire [10:0] stage56_theory_mask_right_start_w;
wire [10:0] stage56_theory_mask_bottom_start_w;
wire [10:0] stage56_effective_mask_right_start_w;
wire [10:0] stage56_effective_mask_bottom_start_w;
wire        post_processing_mask_w;
wire        post_pcg_fallback_mask_w;
wire        stage56_view_de_next_w;
wire [23:0] stage56_view_rgb_next_w;
wire        stage56_post_de_next_w;
wire        stage56_post_vsync_next_w;
wire        stage56_post_hsync_next_w;
wire        stage56_post_border_mask_next_w;
wire [10:0] stage56_post_xpos_next_w;
wire [10:0] stage56_post_ypos_next_w;
wire [10:0] stage56_post_mask_xpos_next_w;
wire [10:0] stage56_post_mask_ypos_next_w;
wire        pcg_view_de_w;
wire [23:0] pcg_view_rgb_w;
wire        stage56_aligned_view_de_w;
wire [23:0] stage56_aligned_view_rgb_w;

// These tap-to-post delays are calibrated against the vendor-library
// ModelSim latency probe so every preview stage shares the same final
// display timing and OSD coordinates as the full chain.
// The RGB core keeps each algorithm's latency local. These delays bring every
// preview tap to the same post-color-temp timing point before the stage56 mux.
localparam integer STAGE56_ALIGN_RAW = 176;
localparam integer STAGE56_ALIGN_RPG = 165;
localparam integer STAGE56_ALIGN_DEB = 155;
localparam integer STAGE56_ALIGN_AWB = 154;
localparam integer STAGE56_ALIGN_CCM = 152;
localparam integer STAGE56_ALIGN_PCG = 149;
localparam integer STAGE56_ALIGN_GMA = 144;
localparam integer STAGE56_ALIGN_TON = 137;
localparam integer STAGE56_ALIGN_LBF = 90;
localparam integer STAGE56_ALIGN_PCC = 88;
localparam integer STAGE56_ALIGN_TUN = 87;
localparam integer STAGE56_ALIGN_FCD = 11;
localparam integer STAGE56_ALIGN_FINAL = 0;

// Stage58 keeps the recovered stage56 mainline, but reattaches the stage57
// runtime controls with the lightest possible touch: color mode branches at
// vivid_tune, skin level adds a post-tune luma-only smoother, and color temp
// offsets are applied just before the final display mask.
reg  [1:0] runtime_color_mode_s0_r;
reg  [1:0] runtime_skin_level_s0_r;
reg  [1:0] runtime_color_temp_s0_r;
(* synthesis, probe_port, keep, preserve, noprune, syn_preserve = 1, syn_keep = 1, altera_attribute = "-name AUTO_SHIFT_REGISTER_RECOGNITION OFF" *) reg post_frame_vsync_r;
(* synthesis, probe_port, keep, preserve, noprune, syn_preserve = 1, syn_keep = 1, altera_attribute = "-name AUTO_SHIFT_REGISTER_RECOGNITION OFF" *) reg post_frame_hsync_r;
reg         post_frame_de_r;
reg  [23:0] post_rgb_r;
reg  [10:0] post_xpos_r;
reg  [10:0] post_ypos_r;
reg  [10:0] post_stream_x_r;
reg  [10:0] post_stream_y_r;
reg         debayer_guard_prev_vld_r;
reg  [23:0] debayer_guard_prev_rgb_r;
reg  [10:0] debayer_guard_prev_x_r;
reg  [10:0] debayer_guard_prev_y_r;
reg         debayer_guard_de_r;
reg  [23:0] debayer_guard_rgb_r;
reg  [10:0] debayer_guard_x_r;
reg  [10:0] debayer_guard_y_r;
reg  [10:0] debayer_out_x_r;
reg  [10:0] debayer_out_y_r;
(* preserve, syn_preserve = 1 *) reg pre_vsync_d0_r;
// Local frame-clear replicas are intentionally not preserved. This allows
// the placer to duplicate/pack each control net close to its consumer instead
// of forcing three high-fanout preserved routes across the RGB region.
reg frame_clr_debayer_r;
reg frame_clr_luma_r;
reg frame_clr_flat_chroma_r;
reg frame_clr_skin_r;
(* synthesis, probe_port, keep, preserve, noprune, syn_preserve = 1, syn_keep = 1, altera_attribute = "-name AUTO_SHIFT_REGISTER_RECOGNITION OFF" *) reg        vsync_pipe_r [0:PIPELINE_LATENCY];
(* synthesis, probe_port, keep, preserve, noprune, syn_preserve = 1, syn_keep = 1, altera_attribute = "-name AUTO_SHIFT_REGISTER_RECOGNITION OFF" *) reg        hsync_pipe_r [0:PIPELINE_LATENCY];
integer pipe_idx;
    reg  [23:0] stage56_view_mux_rgb_r;
    reg         stage56_view_mux_de_r;
    reg  [7:0]  stage56_view_delay_r;
    // Split the frame-latched stage source mux from the fixed-tap output mux.
    // Without this boundary, STA can time any selected source through the
    // delay-0 bypass even though the stage and delay decoders are correlated.
    (* preserve, syn_preserve = 1 *) reg         stage56_selected_in_de_r;
    (* preserve, syn_preserve = 1 *) reg  [23:0] stage56_selected_in_rgb_r;
    (* preserve, syn_preserve = 1 *) reg  [7:0]  stage56_selected_delay_r;
    (* preserve, syn_preserve = 1 *) reg         stage56_pcg_fallback_align_de_r;
    (* preserve, syn_preserve = 1 *) reg  [23:0] stage56_pcg_fallback_align_rgb_r;
    (* preserve, syn_preserve = 1 *) reg         stage56_sync_align_vsync_r;
    (* preserve, syn_preserve = 1 *) reg         stage56_sync_align_hsync_r;
    (* preserve, syn_preserve = 1 *) reg [3:0] stage56_runtime_view_sel_q_r;
    reg  [23:0] stage56_view_rgb_r;
    reg         stage56_view_de_r;
    // Preserve this complete local boundary so the shared selected-delay mux
    // and PCG fallback cannot collapse back into the stage56 output register.
    (* preserve, syn_preserve = 1 *) reg         stage56_boundary_de_r;
    (* preserve, syn_preserve = 1 *) reg  [23:0] stage56_boundary_rgb_r;
    (* preserve, syn_preserve = 1 *) reg         stage56_boundary_pcg_de_r;
    (* preserve, syn_preserve = 1 *) reg  [23:0] stage56_boundary_pcg_rgb_r;
    (* preserve, syn_preserve = 1 *) reg         stage56_boundary_vsync_r;
    (* preserve, syn_preserve = 1 *) reg         stage56_boundary_hsync_r;
    (* preserve, syn_preserve = 1 *) reg         stage56_boundary_border_mask_r;
    (* preserve, syn_preserve = 1 *) reg         stage56_boundary_pcg_fallback_mask_r;
    (* preserve, syn_preserve = 1 *) reg  [10:0] stage56_boundary_xpos_r;
    (* preserve, syn_preserve = 1 *) reg  [10:0] stage56_boundary_ypos_r;
    reg         stage56_post_de_r;
    (* synthesis, probe_port, keep, preserve, noprune, syn_preserve = 1, syn_keep = 1, altera_attribute = "-name AUTO_SHIFT_REGISTER_RECOGNITION OFF" *) reg stage56_post_vsync_r;
    (* synthesis, probe_port, keep, preserve, noprune, syn_preserve = 1, syn_keep = 1, altera_attribute = "-name AUTO_SHIFT_REGISTER_RECOGNITION OFF" *) reg stage56_post_hsync_r;
    reg         stage56_post_border_mask_r;
    reg  [10:0] stage56_post_xpos_r;
    reg  [10:0] stage56_post_ypos_r;
    reg  [10:0] stage56_post_mask_xpos_r;
    reg  [10:0] stage56_post_mask_ypos_r;

assign row_even_w  = ~ypos[0];
assign col_even_w  = ~xpos[0];
assign frame_clr_pulse_w = pre_frame_vsync & ~pre_vsync_d0_r;

assign mon_pre_vsync = pre_frame_vsync;
assign mon_pre_hsync = pre_frame_hsync;
assign mon_pre_de    = pre_frame_de;
assign mon_pre_raw   = pre_raw;
assign mon_pre_xpos  = xpos;
assign mon_pre_ypos  = ypos;

raw_bayer_blc
#(
    .BAYER_MODE (BAYER_MODE),
    .ENABLE     (BLC_EN),
    .OFFSET_R   (BLC_OFFSET_R),
    .OFFSET_GR  (BLC_OFFSET_GR),
    .OFFSET_GB  (BLC_OFFSET_GB),
    .OFFSET_B   (BLC_OFFSET_B)
)
u_raw_bayer_blc
(
    .row_even   (row_even_w),
    .col_even   (col_even_w),
    .din        (pre_raw),
    .dout       (raw_blc_w)
);

// Move white-axis correction into RAW Bayer domain before the 5x5 demosaic.
raw_bayer_plane_gain
#(
    .BAYER_MODE (BAYER_MODE),
    .ENABLE     (RAW_PRE_GAIN_EN),
    .R_GAIN     (RAW_PRE_GAIN_R),
    .GR_GAIN    (RAW_PRE_GAIN_GR),
    .GB_GAIN    (RAW_PRE_GAIN_GB),
    .B_GAIN     (RAW_PRE_GAIN_B)
)
u_raw_bayer_plane_gain
(
    .clk         (clk),
    .rst_n       (rst_n),
    .frame_clr   (frame_clr_debayer_r),
    .in_de       (pre_frame_de),
    .in_row_even (row_even_w),
    .in_col_even (col_even_w),
    .din         (raw_blc_w),
    .out_de      (raw_pre_gain_de_w),
    .out_row_even(raw_pre_gain_row_even_w),
    .out_col_even(raw_pre_gain_col_even_w),
    .dout        (raw_pre_gain_w)
);

debayer_edge_rgb888_8bit
#(
    .H_DISP     (H_DISP),
    .V_DISP     (V_DISP),
    .BAYER_MODE (BAYER_MODE)
)
u_debayer_edge_rgb888_8bit
(
    .clk      (clk),
    .rst_n    (rst_n),
    .frame_clr(frame_clr_debayer_r),
    .din_vld  (raw_pre_gain_de_w),
    .din      (raw_pre_gain_w),
    .row_even (raw_pre_gain_row_even_w),
    .col_even (raw_pre_gain_col_even_w),
    .rgb_vld  (edge_rgb_vld_w),
    .rgb888   (edge_rgb_w)
);

assign debayer_sel_de_w  = edge_rgb_vld_w;
assign debayer_sel_rgb_w = edge_rgb_w;

assign core_de_w  = debayer_guard_de_r;
assign core_rgb_w = debayer_guard_de_r ? debayer_guard_rgb_r : 24'd0;

isp_rgb_pipeline_core
#(
    .H_DISP(H_DISP),
    .V_DISP(V_DISP),
    .AWB_R_GAIN(AWB_R_GAIN),
    .AWB_G_GAIN(AWB_G_GAIN),
    .AWB_B_GAIN(AWB_B_GAIN),
    .CCM_M_RR(CCM_RR),
    .CCM_M_RG(CCM_RG),
    .CCM_M_RB(CCM_RB),
    .CCM_M_GR(CCM_GR),
    .CCM_M_GG(CCM_GG),
    .CCM_M_GB(CCM_GB),
    .CCM_M_BR(CCM_BR),
    .CCM_M_BG(CCM_BG),
    .CCM_M_BB(CCM_BB),
    .PRECNR_ENABLE(PRECNR_CHROMA_GAIN_EN),
    .PRECNR_GAIN_Q8(PRECNR_CHROMA_GAIN_Q8)
)
u_refactored_rgb_pipeline_core
(
    .clk       (clk),
    .rst_n     (rst_n),
    .in_vsync  (pre_frame_vsync),
    .in_hsync  (pre_frame_hsync),
    .in_de     (core_de_w),
    .in_x      (debayer_guard_x_r),
    .in_y      (debayer_guard_y_r),
    .in_rgb    (core_rgb_w),
    .out_vsync (),
    .out_hsync (),
    .out_de    (),
    .out_x     (),
    .out_y     (),
    .out_rgb   (),
    .tap0_de   (awb_de_w),
    .tap0_rgb  (awb_rgb_w),
    .tap1_de   (ccm_de_w),
    .tap1_rgb  (ccm_rgb_w),
    .tap2_de   (precnr_de_w),
    .tap2_rgb  (precnr_rgb_w),
    .tap3_de   (),
    .tap3_rgb  (),
    .tap4_de   (),
    .tap4_rgb  (),
    .tap5_de   (),
    .tap5_rgb  ()
);

rgb_gamma_lut
#(
    .ENABLE (GAMMA_EN),
    .MODE   (GAMMA_MODE),
    .LOW_CHROMA_TH(GAMMA_LOW_CHROMA_TH)
)
u_rgb_gamma_lut
(
    .clk    (clk),
    .rst_n  (rst_n),
    .in_de  (precnr_de_w),
    .in_rgb (precnr_rgb_w),
    .out_de (gamma_de_w),
    .out_rgb(gamma_rgb_w)
);

rgb_luma_tone_lut
#(
    .ENABLE  (TONE_EN),
    .PROFILE (TONE_PROFILE)
)
u_rgb_luma_tone_lut
(
    .clk    (clk),
    .rst_n  (rst_n),
    .in_de  (gamma_de_w),
    .in_rgb (gamma_rgb_w),
    .out_de (tone_de_w),
    .out_rgb(tone_rgb_w)
);

rgb_luma_bilateral_3x3
#(
    .H_DISP   (H_DISP),
    .V_DISP   (V_DISP),
    .FLATTEN_MODE (FLATTEN_MODE),
    .DELTA_SAFE_FLATTEN_EN (DELTA_SAFE_FLATTEN_EN),
    .CHROMA_SMEAR_FLATTEN_EN (CHROMA_SMEAR_FLATTEN_EN),
    .ENABLE   (EFFECTIVE_LUMA_BILATERAL_EN),
    .RANGE_TH (EFFECTIVE_LUMA_BILATERAL_TH)
)
u_rgb_luma_bilateral_3x3
(
    .clk      (clk),
    .rst_n    (rst_n),
    .frame_clr(frame_clr_luma_r),
    .in_de    (tone_de_w),
    .in_rgb   (tone_rgb_w),
    .cfg_runtime_bypass_en(1'b0),
    .out_de   (luma_bilat_de_w),
    .out_rgb  (luma_bilat_rgb_w)
);

rgb_ccm_3x3
#(
    .M_RR (POST_CCM_RR),
    .M_RG (POST_CCM_RG),
    .M_RB (POST_CCM_RB),
    .M_GR (POST_CCM_GR),
    .M_GG (POST_CCM_GG),
    .M_GB (POST_CCM_GB),
    .M_BR (POST_CCM_BR),
    .M_BG (POST_CCM_BG),
    .M_BB (POST_CCM_BB)
)
u_rgb_post_ccm_3x3
(
    .clk    (clk),
    .rst_n  (rst_n),
    .in_de  (luma_bilat_de_w),
    .in_rgb (luma_bilat_rgb_w),
    .out_de (post_ccm_de_w),
    .out_rgb(post_ccm_rgb_w)
);

assign tune_src_de_w  = (POST_CCM_EN != 0) ? post_ccm_de_w : luma_bilat_de_w;
assign tune_src_rgb_w = (POST_CCM_EN != 0) ? post_ccm_rgb_w : luma_bilat_rgb_w;

rgb_vivid_tune
#(
    .ENABLE        (TUNE_EN),
    .SAT_POS_SHIFT (COLOR_MODE_LIGHT_TUNE_SAT_POS_SHIFT),
    .SAT_NEG_SHIFT (COLOR_MODE_LIGHT_TUNE_SAT_NEG_SHIFT),
    .LIFT_SHIFT    (COLOR_MODE_LIGHT_TUNE_LIFT_SHIFT),
    .R_OFFSET      (COLOR_MODE_LIGHT_TUNE_R_OFFSET),
    .G_OFFSET      (COLOR_MODE_LIGHT_TUNE_G_OFFSET),
    .B_OFFSET      (COLOR_MODE_LIGHT_TUNE_B_OFFSET)
)
u_rgb_vivid_tune_light
(
    .clk    (clk),
    .rst_n  (rst_n),
    .in_de  (tune_src_de_w),
    .in_rgb (tune_src_rgb_w),
    .out_de (tune_light_de_w),
    .out_rgb(tune_light_rgb_w)
);

rgb_vivid_tune
#(
    .ENABLE        (TUNE_EN),
    .SAT_POS_SHIFT (TUNE_SAT_POS_SHIFT),
    .SAT_NEG_SHIFT (TUNE_SAT_NEG_SHIFT),
    .LIFT_SHIFT    (TUNE_LIFT_SHIFT),
    .R_OFFSET      (TUNE_R_OFFSET),
    .G_OFFSET      (TUNE_G_OFFSET),
    .B_OFFSET      (TUNE_B_OFFSET)
)
u_rgb_vivid_tune_balanced
(
    .clk    (clk),
    .rst_n  (rst_n),
    .in_de  (tune_src_de_w),
    .in_rgb (tune_src_rgb_w),
    .out_de (tune_balanced_de_w),
    .out_rgb(tune_balanced_rgb_w)
);

rgb_vivid_tune
#(
    .ENABLE        (TUNE_EN),
    .SAT_POS_SHIFT (COLOR_MODE_VIVID_TUNE_SAT_POS_SHIFT),
    .SAT_NEG_SHIFT (COLOR_MODE_VIVID_TUNE_SAT_NEG_SHIFT),
    .LIFT_SHIFT    (COLOR_MODE_VIVID_TUNE_LIFT_SHIFT),
    .R_OFFSET      (COLOR_MODE_VIVID_TUNE_R_OFFSET),
    .G_OFFSET      (COLOR_MODE_VIVID_TUNE_G_OFFSET),
    .B_OFFSET      (COLOR_MODE_VIVID_TUNE_B_OFFSET)
)
u_rgb_vivid_tune_vivid
(
    .clk    (clk),
    .rst_n  (rst_n),
    .in_de  (tune_src_de_w),
    .in_rgb (tune_src_rgb_w),
    .out_de (tune_vivid_de_w),
    .out_rgb(tune_vivid_rgb_w)
);

assign tune_mux_de_w =
    (runtime_color_mode_s0_r == COLOR_MODE_LIGHT) ? tune_light_de_w :
    ((runtime_color_mode_s0_r == COLOR_MODE_VIVID) ? tune_vivid_de_w : tune_balanced_de_w);
assign tune_mux_rgb_w =
    (runtime_color_mode_s0_r == COLOR_MODE_LIGHT) ? tune_light_rgb_w :
    ((runtime_color_mode_s0_r == COLOR_MODE_VIVID) ? tune_vivid_rgb_w : tune_balanced_rgb_w);
assign tune_de_w  = tune_mux_de_w;
assign tune_rgb_w = tune_mux_rgb_w;

rgb_flat_chroma_denoise_5x5
#(
    .H_DISP(H_DISP),
    .V_DISP(V_DISP),
    .ENABLE(FLAT_SUPPORT_EN),
    .Y_RANGE_TH(8'd8),
    .CHROMA_RANGE_TH(8'd16),
    .ALPHA_Q8(9'd224),
    .DELTA_CLAMP(8'd16),
    .NEUTRAL_GUARD_ENABLE(1),
    .NEUTRAL_OUTWARD_CAP(8'd2),
    .NEUTRAL_SAT_TH(8'd42),
    .NEUTRAL_CHROMA_TH(8'd18),
    .STARTUP_BYPASS_LEFT_PX(11'd5),
    .STARTUP_BYPASS_TOP_PX(11'd4)
)
u_rgb_flat_chroma_denoise_5x5
(
    .clk      (clk),
    .rst_n    (rst_n),
    .frame_clr(frame_clr_flat_chroma_r),
    .in_de    (tune_de_w),
    .in_rgb   (tune_rgb_w),
    .out_de   (flat_chroma_de_w),
    .out_rgb  (flat_chroma_rgb_w)
);

rgb_skin_smooth_y_only
#(
    .H_DISP           (H_DISP),
    .V_DISP           (V_DISP)
)
u_rgb_skin_smooth_y_only
(
    .clk                       (clk),
    .rst_n                     (rst_n),
    .frame_clr                 (frame_clr_skin_r),
    .in_de                     (flat_chroma_de_w),
    .in_rgb                    (flat_chroma_rgb_w),
    .cfg_runtime_skin_level_sel(runtime_skin_level_s0_r),
    .out_de                    (skin_smooth_de_w),
    .out_rgb                   (skin_smooth_rgb_w)
);

rgb_color_temp_offset
#(
    .COOL_R_OFFSET (COLOR_TEMP_COOL_R_OFFSET),
    .COOL_G_OFFSET (COLOR_TEMP_COOL_G_OFFSET),
    .COOL_B_OFFSET (COLOR_TEMP_COOL_B_OFFSET),
    .WARM_R_OFFSET (COLOR_TEMP_WARM_R_OFFSET),
    .WARM_G_OFFSET (COLOR_TEMP_WARM_G_OFFSET),
    .WARM_B_OFFSET (COLOR_TEMP_WARM_B_OFFSET)
)
u_rgb_color_temp_offset
(
    .clk                       (clk),
    .rst_n                     (rst_n),
    .in_de                     (skin_smooth_de_w),
    .in_rgb                    (skin_smooth_rgb_w),
    .cfg_runtime_color_temp_sel(runtime_color_temp_s0_r),
    .out_de                    (color_temp_de_w),
    .out_rgb                   (color_temp_rgb_w)
);

assign post_stream_xpos_w = stage56_aligned_view_de_w ? post_stream_x_r : 11'd0;
assign post_stream_ypos_w = stage56_aligned_view_de_w ? post_stream_y_r : 11'd0;

// PCG is also the calibrated border-fallback source, so keep one fixed
// aligned copy. All other preview modes share the delay bank below.
stream_rgb_delay_pipe
#(
    .LATENCY (STAGE56_ALIGN_PCG)
)
u_stage56_view_pcg_delay
(
    .clk      (clk),
    .rst_n    (rst_n),
    .frame_clr(frame_clr_pulse_w),
    .in_de    (precnr_de_w),
    .in_rgb   (precnr_rgb_w),
    .out_de   (pcg_view_de_w),
    .out_rgb  (pcg_view_rgb_w)
);

// stage56_runtime_view_sel_q_r is frame-latched by the unified profile
// controller. Select only the active tap before storage, then use a reviewed
// fixed delay tap to reach the common post-color-temperature timing point.
always @(*) begin
    stage56_view_mux_de_r  = color_temp_de_w;
    stage56_view_mux_rgb_r = color_temp_rgb_w;
    stage56_view_delay_r   = STAGE56_ALIGN_FINAL;

    case (stage56_runtime_view_sel_q_r)
        STAGE56_VIEW_RAW: begin
            stage56_view_mux_de_r  = pre_frame_de;
            stage56_view_mux_rgb_r = {pre_raw, pre_raw, pre_raw};
            stage56_view_delay_r   = STAGE56_ALIGN_RAW;
        end
        STAGE56_VIEW_RPG: begin
            stage56_view_mux_de_r  = raw_pre_gain_de_w;
            stage56_view_mux_rgb_r = {raw_pre_gain_w, raw_pre_gain_w, raw_pre_gain_w};
            stage56_view_delay_r   = STAGE56_ALIGN_RPG;
        end
        STAGE56_VIEW_DEB: begin
            stage56_view_mux_de_r  = core_de_w;
            stage56_view_mux_rgb_r = core_rgb_w;
            stage56_view_delay_r   = STAGE56_ALIGN_DEB;
        end
        STAGE56_VIEW_AWB: begin
            stage56_view_mux_de_r  = awb_de_w;
            stage56_view_mux_rgb_r = awb_rgb_w;
            stage56_view_delay_r   = STAGE56_ALIGN_AWB;
        end
        STAGE56_VIEW_CCM: begin
            stage56_view_mux_de_r  = ccm_de_w;
            stage56_view_mux_rgb_r = ccm_rgb_w;
            stage56_view_delay_r   = STAGE56_ALIGN_CCM;
        end
        STAGE56_VIEW_PCG: begin
            stage56_view_mux_de_r  = pcg_view_de_w;
            stage56_view_mux_rgb_r = pcg_view_rgb_w;
            stage56_view_delay_r   = STAGE56_ALIGN_FINAL;
        end
        STAGE56_VIEW_FCD: begin
            stage56_view_mux_de_r  = flat_chroma_de_w;
            stage56_view_mux_rgb_r = flat_chroma_rgb_w;
            stage56_view_delay_r   = STAGE56_ALIGN_FCD;
        end
        STAGE56_VIEW_GMA: begin
            stage56_view_mux_de_r  = gamma_de_w;
            stage56_view_mux_rgb_r = gamma_rgb_w;
            stage56_view_delay_r   = STAGE56_ALIGN_GMA;
        end
        STAGE56_VIEW_TON: begin
            stage56_view_mux_de_r  = tone_de_w;
            stage56_view_mux_rgb_r = tone_rgb_w;
            stage56_view_delay_r   = STAGE56_ALIGN_TON;
        end
        STAGE56_VIEW_LBF: begin
            stage56_view_mux_de_r  = luma_bilat_de_w;
            stage56_view_mux_rgb_r = luma_bilat_rgb_w;
            stage56_view_delay_r   = STAGE56_ALIGN_LBF;
        end
        STAGE56_VIEW_PCC: begin
            stage56_view_mux_de_r  = post_ccm_de_w;
            stage56_view_mux_rgb_r = post_ccm_rgb_w;
            stage56_view_delay_r   = STAGE56_ALIGN_PCC;
        end
        STAGE56_VIEW_TUN: begin
            stage56_view_mux_de_r  = tune_de_w;
            stage56_view_mux_rgb_r = tune_rgb_w;
            stage56_view_delay_r   = STAGE56_ALIGN_TUN;
        end
        default: begin
            stage56_view_mux_de_r  = color_temp_de_w;
            stage56_view_mux_rgb_r = color_temp_rgb_w;
            stage56_view_delay_r   = STAGE56_ALIGN_FINAL;
        end
    endcase
end

stream_rgb_selected_delay_pipe
#(
    .MAX_LATENCY (STAGE56_ALIGN_RAW)
)
u_stage56_selected_view_delay
(
    .clk         (clk),
    .rst_n       (rst_n),
    .frame_clr   (frame_clr_pulse_w),
    .delay_cycles(stage56_selected_delay_r),
    .in_de       (stage56_selected_in_de_r),
    .in_rgb      (stage56_selected_in_rgb_r),
    .out_de      (stage56_aligned_view_de_w),
    .out_rgb     (stage56_aligned_view_rgb_w)
);

// The selected source token is a real pipeline boundary. Pixel payload does
// not need asynchronous reset because the registered DE remains authoritative.
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        stage56_selected_in_de_r <= 1'b0;
        stage56_selected_delay_r <= STAGE56_ALIGN_FINAL;
        stage56_pcg_fallback_align_de_r <= 1'b0;
        stage56_sync_align_vsync_r <= 1'b0;
        stage56_sync_align_hsync_r <= 1'b0;
    end else begin
        stage56_selected_in_de_r <= frame_clr_pulse_w
                                  ? 1'b0 : stage56_view_mux_de_r;
        stage56_selected_delay_r <= stage56_view_delay_r;
        stage56_pcg_fallback_align_de_r <= frame_clr_pulse_w
                                         ? 1'b0 : pcg_view_de_w;
        stage56_sync_align_vsync_r <= vsync_pipe_r[PIPELINE_LATENCY];
        stage56_sync_align_hsync_r <= hsync_pipe_r[PIPELINE_LATENCY];
    end
end

always @(posedge clk) begin
    stage56_selected_in_rgb_r <= stage56_view_mux_rgb_r;
    stage56_pcg_fallback_align_rgb_r <= pcg_view_rgb_w;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pre_vsync_d0_r <= 1'b0;
        runtime_color_mode_s0_r <= COLOR_MODE_BALANCED;
        runtime_skin_level_s0_r <= SKIN_LEVEL_OFF;
        runtime_color_temp_s0_r <= COLOR_TEMP_NEUTRAL;
        for (pipe_idx = 0; pipe_idx <= PIPELINE_LATENCY; pipe_idx = pipe_idx + 1) begin
            vsync_pipe_r[pipe_idx] <= 1'b0;
            hsync_pipe_r[pipe_idx] <= 1'b0;
        end
        debayer_guard_prev_vld_r <= 1'b0;
        debayer_guard_prev_rgb_r <= 24'd0;
        debayer_guard_prev_x_r <= 11'd0;
        debayer_guard_prev_y_r <= 11'd0;
        debayer_guard_de_r <= 1'b0;
        debayer_guard_rgb_r <= 24'd0;
        debayer_guard_x_r <= 11'd0;
        debayer_guard_y_r <= 11'd0;
        debayer_out_x_r <= 11'd0;
        debayer_out_y_r <= 11'd0;
        stage56_view_rgb_r <= 24'd0;
        stage56_view_de_r <= 1'b0;
        stage56_boundary_de_r <= 1'b0;
        stage56_boundary_rgb_r <= 24'd0;
        stage56_boundary_pcg_de_r <= 1'b0;
        stage56_boundary_pcg_rgb_r <= 24'd0;
        stage56_boundary_vsync_r <= 1'b0;
        stage56_boundary_hsync_r <= 1'b0;
        stage56_boundary_border_mask_r <= 1'b0;
        stage56_boundary_pcg_fallback_mask_r <= 1'b0;
        stage56_boundary_xpos_r <= 11'd0;
        stage56_boundary_ypos_r <= 11'd0;
        stage56_runtime_view_sel_q_r <= STAGE56_VIEW_RAW;
        stage56_post_de_r <= 1'b0;
        stage56_post_vsync_r <= 1'b0;
        stage56_post_hsync_r <= 1'b0;
        stage56_post_border_mask_r <= 1'b0;
        stage56_post_xpos_r <= 11'd0;
        stage56_post_ypos_r <= 11'd0;
        stage56_post_mask_xpos_r <= 11'd0;
        stage56_post_mask_ypos_r <= 11'd0;
        post_frame_vsync_r <= 1'b0;
        post_frame_hsync_r <= 1'b0;
        post_frame_de_r <= 1'b0;
        post_rgb_r <= 24'd0;
        post_xpos_r <= 11'd0;
        post_ypos_r <= 11'd0;
        post_stream_x_r <= 11'd0;
        post_stream_y_r <= 11'd0;
        frame_clr_debayer_r <= 1'b0;
        frame_clr_luma_r <= 1'b0;
        frame_clr_flat_chroma_r <= 1'b0;
        frame_clr_skin_r <= 1'b0;
    end else begin
        pre_vsync_d0_r <= pre_frame_vsync;
        runtime_color_mode_s0_r <= cfg_runtime_color_mode_sel;
        runtime_skin_level_s0_r <= cfg_runtime_skin_level_sel;
        runtime_color_temp_s0_r <= cfg_runtime_color_temp_sel;
        frame_clr_debayer_r <= frame_clr_pulse_w;
        frame_clr_luma_r <= frame_clr_pulse_w;
        frame_clr_flat_chroma_r <= frame_clr_pulse_w;
        frame_clr_skin_r <= frame_clr_pulse_w;
        vsync_pipe_r[0] <= pre_frame_vsync;
        hsync_pipe_r[0] <= pre_frame_hsync;
        for (pipe_idx = 1; pipe_idx <= PIPELINE_LATENCY; pipe_idx = pipe_idx + 1) begin
            vsync_pipe_r[pipe_idx] <= vsync_pipe_r[pipe_idx-1];
            hsync_pipe_r[pipe_idx] <= hsync_pipe_r[pipe_idx-1];
        end
        if (frame_clr_pulse_w) begin
            debayer_out_x_r <= 11'd0;
            debayer_out_y_r <= 11'd0;
            debayer_guard_prev_vld_r <= 1'b0;
            debayer_guard_prev_rgb_r <= 24'd0;
            debayer_guard_prev_x_r <= 11'd0;
            debayer_guard_prev_y_r <= 11'd0;
            debayer_guard_de_r <= 1'b0;
            debayer_guard_rgb_r <= 24'd0;
            debayer_guard_x_r <= 11'd0;
            debayer_guard_y_r <= 11'd0;
        end else if (debayer_sel_de_w) begin
            if (debayer_out_x_r == H_DISP-1) begin
                debayer_out_x_r <= 11'd0;
                if (debayer_out_y_r == V_DISP-1)
                    debayer_out_y_r <= 11'd0;
                else
                    debayer_out_y_r <= debayer_out_y_r + 11'd1;
            end else begin
                debayer_out_x_r <= debayer_out_x_r + 11'd1;
            end
        end
        if (!frame_clr_pulse_w) begin
            debayer_guard_de_r <= debayer_guard_prev_vld_r;
            if (debayer_guard_prev_vld_r) begin
                debayer_guard_rgb_r <= debayer_guard_prev_rgb_r;
                debayer_guard_x_r <= debayer_guard_prev_x_r;
                debayer_guard_y_r <= debayer_guard_prev_y_r;
            end else begin
                debayer_guard_rgb_r <= 24'd0;
                debayer_guard_x_r <= 11'd0;
                debayer_guard_y_r <= 11'd0;
            end

            if (debayer_sel_de_w) begin
                debayer_guard_prev_vld_r <= 1'b1;
                debayer_guard_prev_rgb_r <= debayer_sel_rgb_w;
                debayer_guard_prev_x_r <= debayer_out_x_r;
                debayer_guard_prev_y_r <= debayer_out_y_r;
            end else begin
                debayer_guard_prev_vld_r <= 1'b0;
                debayer_guard_prev_rgb_r <= 24'd0;
                debayer_guard_prev_x_r <= 11'd0;
                debayer_guard_prev_y_r <= 11'd0;
            end
        end
        stage56_runtime_view_sel_q_r <= stage56_runtime_view_sel_w;
        stage56_boundary_de_r <= stage56_aligned_view_de_w;
        stage56_boundary_rgb_r <= stage56_aligned_view_rgb_w;
        stage56_boundary_pcg_de_r <= stage56_pcg_fallback_align_de_r;
        stage56_boundary_pcg_rgb_r <= stage56_pcg_fallback_align_de_r ?
                                      stage56_pcg_fallback_align_rgb_r : 24'd0;
        stage56_boundary_vsync_r <= stage56_sync_align_vsync_r;
        stage56_boundary_hsync_r <= stage56_sync_align_hsync_r;
        stage56_boundary_border_mask_r <= post_border_mask_w;
        stage56_boundary_pcg_fallback_mask_r <= post_pcg_fallback_mask_w;
        stage56_boundary_xpos_r <= post_xpos_w;
        stage56_boundary_ypos_r <= post_ypos_w;
        stage56_view_de_r <= stage56_view_de_next_w;
        stage56_view_rgb_r <= stage56_view_rgb_next_w;
        if (frame_clr_pulse_w) begin
            post_stream_x_r <= 11'd0;
            post_stream_y_r <= 11'd0;
        end else if (stage56_aligned_view_de_w) begin
            if (post_stream_x_r == (H_DISP_U11 - 11'd1)) begin
                post_stream_x_r <= 11'd0;
                if (post_stream_y_r == (V_DISP_U11 - 11'd1))
                    post_stream_y_r <= 11'd0;
                else
                    post_stream_y_r <= post_stream_y_r + 11'd1;
            end else begin
                post_stream_x_r <= post_stream_x_r + 11'd1;
            end
        end else begin
            post_stream_x_r <= 11'd0;
        end
        stage56_post_de_r <= stage56_post_de_next_w;
        stage56_post_vsync_r <= stage56_post_vsync_next_w;
        stage56_post_hsync_r <= stage56_post_hsync_next_w;
        stage56_post_border_mask_r <= stage56_post_border_mask_next_w;
        stage56_post_xpos_r <= stage56_post_xpos_next_w;
        stage56_post_ypos_r <= stage56_post_ypos_next_w;
        stage56_post_mask_xpos_r <= stage56_post_mask_xpos_next_w;
        stage56_post_mask_ypos_r <= stage56_post_mask_ypos_next_w;

        post_frame_vsync_r <= stage56_post_vsync_r;
        post_frame_hsync_r <= stage56_post_hsync_r;
        post_frame_de_r <= stage56_post_de_r;
        post_xpos_r <= stage56_post_xpos_r;
        post_ypos_r <= stage56_post_ypos_r;
        if (!stage56_post_de_r ||
            stage56_post_border_mask_r ||
            !stage56_view_de_r) begin
            post_rgb_r <= 24'd0;
        end else begin
            post_rgb_r <= stage56_view_rgb_r;
        end
    end
end

assign post_xpos_w = post_stream_xpos_w;
assign post_ypos_w = post_stream_ypos_w;
assign post_mask_xpos_w = post_xpos_w;
assign post_mask_ypos_w = post_ypos_w;
assign output_black_right_start_w =
    H_DISP_U11 - OUTPUT_BLACK_MASK_RIGHT_U11;
assign output_black_bottom_start_w =
    V_DISP_U11 - OUTPUT_BLACK_MASK_BOTTOM_U11;
assign stage56_theory_mask_left_w =
    stage56_theory_mask_left(stage56_runtime_view_sel_q_r);
assign stage56_theory_mask_right_w =
    stage56_theory_mask_right(stage56_runtime_view_sel_q_r);
assign stage56_theory_mask_top_w =
    stage56_theory_mask_top(stage56_runtime_view_sel_q_r);
assign stage56_theory_mask_bottom_w =
    stage56_theory_mask_bottom(stage56_runtime_view_sel_q_r);
assign stage56_output_mask_left_w =
    stage56_output_mask_left(stage56_runtime_view_sel_q_r);
assign stage56_output_mask_right_w =
    stage56_output_mask_right(stage56_runtime_view_sel_q_r);
assign stage56_output_mask_top_w =
    stage56_output_mask_top(stage56_runtime_view_sel_q_r);
assign stage56_output_mask_bottom_w =
    stage56_output_mask_bottom(stage56_runtime_view_sel_q_r);
assign stage56_effective_mask_left_w =
    max_u11(OUTPUT_BLACK_MASK_LEFT_U11, stage56_output_mask_left_w);
assign stage56_effective_mask_right_w =
    max_u11(OUTPUT_BLACK_MASK_RIGHT_U11, stage56_output_mask_right_w);
assign stage56_effective_mask_top_w =
    max_u11(OUTPUT_BLACK_MASK_TOP_U11, stage56_output_mask_top_w);
assign stage56_effective_mask_bottom_w =
    max_u11(OUTPUT_BLACK_MASK_BOTTOM_U11, stage56_output_mask_bottom_w);
assign stage56_theory_mask_right_start_w =
    H_DISP_U11 - stage56_theory_mask_right_w;
assign stage56_theory_mask_bottom_start_w =
    V_DISP_U11 - stage56_theory_mask_bottom_w;
assign stage56_effective_mask_right_start_w =
    H_DISP_U11 - stage56_effective_mask_right_w;
assign stage56_effective_mask_bottom_start_w =
    V_DISP_U11 - stage56_effective_mask_bottom_w;
assign post_processing_mask_w =
    ((stage56_theory_mask_left_w != 11'd0) &&
     (post_mask_xpos_w < stage56_theory_mask_left_w)) ||
    ((stage56_theory_mask_right_w != 11'd0) &&
     (post_mask_xpos_w >= stage56_theory_mask_right_start_w)) ||
    ((stage56_theory_mask_top_w != 11'd0) &&
     (post_mask_ypos_w < stage56_theory_mask_top_w)) ||
    ((stage56_theory_mask_bottom_w != 11'd0) &&
     (post_mask_ypos_w >= stage56_theory_mask_bottom_start_w));
assign post_border_mask_w =
    ((stage56_effective_mask_left_w != 11'd0) &&
     (post_mask_xpos_w < stage56_effective_mask_left_w)) ||
    ((stage56_effective_mask_right_w != 11'd0) &&
     (post_mask_xpos_w >= stage56_effective_mask_right_start_w)) ||
    ((stage56_effective_mask_top_w != 11'd0) &&
     (post_mask_ypos_w < stage56_effective_mask_top_w)) ||
    ((stage56_effective_mask_bottom_w != 11'd0) &&
     (post_mask_ypos_w >= stage56_effective_mask_bottom_start_w));
assign post_pcg_fallback_mask_w = post_processing_mask_w && !post_border_mask_w;
assign stage56_view_de_next_w = stage56_boundary_de_r;
assign stage56_view_rgb_next_w =
    (stage56_boundary_pcg_fallback_mask_r && stage56_boundary_pcg_de_r) ?
        stage56_boundary_pcg_rgb_r :
    (stage56_boundary_de_r ? stage56_boundary_rgb_r : 24'd0);
assign stage56_post_de_next_w = stage56_view_de_next_w;
assign stage56_post_vsync_next_w = stage56_boundary_vsync_r;
assign stage56_post_hsync_next_w = stage56_boundary_hsync_r;
assign stage56_post_border_mask_next_w = stage56_boundary_border_mask_r;
assign stage56_post_xpos_next_w = stage56_boundary_xpos_r;
assign stage56_post_ypos_next_w = stage56_boundary_ypos_r;
assign stage56_post_mask_xpos_next_w = stage56_boundary_xpos_r;
assign stage56_post_mask_ypos_next_w = stage56_boundary_ypos_r;
assign post_frame_vsync = post_frame_vsync_r;
assign post_frame_hsync = post_frame_hsync_r;
assign post_frame_de    = post_frame_de_r;
assign post_rgb         = post_rgb_r;
assign post_xpos        = post_xpos_r;
assign post_ypos        = post_ypos_r;

assign mon_core_vsync = post_frame_vsync;
assign mon_core_hsync = post_frame_hsync;
assign mon_core_de    = post_frame_de;
assign mon_core_rgb   = post_rgb;
assign mon_core_xpos  = post_xpos;
assign mon_core_ypos  = post_ypos;

endmodule
