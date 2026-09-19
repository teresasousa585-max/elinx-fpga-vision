module rgb_luma_bilateral_3x3
#(
    parameter H_DISP = 1280,
    parameter V_DISP = 720,
    parameter [1:0] FLATTEN_MODE = 2'd0,
    parameter DELTA_SAFE_FLATTEN_EN = 0,
    parameter integer CHROMA_SMEAR_FLATTEN_EN = 0,
    parameter ENABLE = 1,
    parameter [7:0] RANGE_TH = 8'd8
)
(
    input   wire            clk,
    input   wire            rst_n,
    input   wire            frame_clr,
    input   wire            in_de,
    input   wire    [23:0]  in_rgb,
    input   wire            cfg_runtime_bypass_en,

    output  wire            out_de,
    output  wire    [23:0]  out_rgb
);

    function [7:0] clip_u8;
        input signed [19:0] value;
        begin
            if (value < 20'sd0)
                clip_u8 = 8'd0;
            else if (value > 20'sd255)
                clip_u8 = 8'd255;
            else
                clip_u8 = value[7:0];
        end
    endfunction

    function [7:0] quant_chroma_u8;
        input [7:0] value;
        reg [8:0] rounded;
        begin
            rounded = {1'b0, value} + 9'd2;
            quant_chroma_u8 = (rounded[8] || (rounded[7:0] > 8'd252)) ? 8'd252 : {rounded[7:2], 2'b00};
        end
    endfunction

    function [8:0] clip_q8;
        input signed [12:0] value;
        begin
            if (value < 13'sd0)
                clip_q8 = 9'd0;
            else if (value > 13'sd256)
                clip_q8 = 9'd256;
            else
                clip_q8 = value[8:0];
        end
    endfunction

    function [8:0] min_q8;
        input [8:0] a;
        input [8:0] b;
        begin
            min_q8 = (a < b) ? a : b;
        end
    endfunction

    localparam [1:0] FLATTEN_NATIVE = 2'd0;
    localparam [1:0] FLATTEN_SLIGHT = 2'd1;
    localparam [1:0] FLATTEN_FLAT   = 2'd2;
    localparam       STAGE19_CANDIDATE_EN = (CHROMA_SMEAR_FLATTEN_EN >= 12);
    localparam       STAGE18_PY_TARGET_EN = (CHROMA_SMEAR_FLATTEN_EN >= 11) && !STAGE19_CANDIDATE_EN;
    localparam       STAGE17_ARCH_TARGET_EN = (CHROMA_SMEAR_FLATTEN_EN >= 10) && !STAGE18_PY_TARGET_EN && !STAGE19_CANDIDATE_EN;
    localparam       STAGE16_ARCH_BLOCK_RECON_EN = (CHROMA_SMEAR_FLATTEN_EN >= 9) && !STAGE17_ARCH_TARGET_EN && !STAGE18_PY_TARGET_EN && !STAGE19_CANDIDATE_EN;
    localparam       STAGE15_ARCH_RECON_EN = (CHROMA_SMEAR_FLATTEN_EN >= 8) && !STAGE16_ARCH_BLOCK_RECON_EN && !STAGE17_ARCH_TARGET_EN && !STAGE18_PY_TARGET_EN && !STAGE19_CANDIDATE_EN;
    localparam       STAGE12_BOLD_EN = (CHROMA_SMEAR_FLATTEN_EN >= 5) && !STAGE18_PY_TARGET_EN && !STAGE19_CANDIDATE_EN;
    localparam       STAGE13_MEDIAN_TARGET_EN = (CHROMA_SMEAR_FLATTEN_EN >= 6) && !STAGE15_ARCH_RECON_EN && !STAGE18_PY_TARGET_EN && !STAGE19_CANDIDATE_EN;
    localparam       STAGE14_DELTA_RGB_EN = (CHROMA_SMEAR_FLATTEN_EN >= 7) && !STAGE15_ARCH_RECON_EN && !STAGE18_PY_TARGET_EN && !STAGE19_CANDIDATE_EN;
    localparam [7:0] STAGE19_YELLOW_TH = 8'd10;
    localparam [7:0] STAGE19_YELLOW_MIN_AMT = 8'd6;
    localparam [7:0] STAGE19_RG_MAX = 8'd48;
    localparam [7:0] STAGE19_Y_MIN = 8'd24;
    localparam [7:0] STAGE19_Y_MAX = 8'd246;
    localparam [7:0] STAGE19_ALPHA_MAX = 8'd48;
    localparam [7:0] STAGE19_DARK_Y_MIN = 8'd40;
    localparam [7:0] STAGE19_DARK_BDELTA_MIN = 8'd20;
    localparam       CHROMA_FILTER_EN = (FLATTEN_MODE != FLATTEN_NATIVE);
    localparam [7:0] CHROMA_RANGE_TH =
        (FLATTEN_MODE == FLATTEN_SLIGHT) ? 8'd12 :
        ((FLATTEN_MODE == FLATTEN_FLAT) ? 8'd16 : 8'd0);
    localparam [7:0] FLAT_DARK_Y_TH =
        (FLATTEN_MODE == FLATTEN_SLIGHT) ? 8'd255 :
        ((FLATTEN_MODE == FLATTEN_FLAT) ? 8'd255 : 8'd0);
    localparam [7:0] FLAT_LOCAL_DIFF_TH =
        (FLATTEN_MODE == FLATTEN_SLIGHT) ? ((STAGE16_ARCH_BLOCK_RECON_EN) ? 8'd255 : 8'd48) :
        ((FLATTEN_MODE == FLATTEN_FLAT) ? ((STAGE16_ARCH_BLOCK_RECON_EN) ? 8'd255 : 8'd56) : 8'd0);
    localparam [8:0] FLAT_Y_ALPHA_Q8 =
        (FLATTEN_MODE == FLATTEN_SLIGHT) ? (STAGE18_PY_TARGET_EN ? 9'd0 : (STAGE17_ARCH_TARGET_EN ? 9'd64 : (STAGE16_ARCH_BLOCK_RECON_EN ? 9'd0 : (STAGE14_DELTA_RGB_EN ? 9'd32 : (STAGE12_BOLD_EN ? 9'd64 : 9'd0))))) :
        ((FLATTEN_MODE == FLATTEN_FLAT) ? (STAGE18_PY_TARGET_EN ? 9'd0 : (STAGE17_ARCH_TARGET_EN ? 9'd96 : (STAGE16_ARCH_BLOCK_RECON_EN ? 9'd0 : (STAGE14_DELTA_RGB_EN ? 9'd160 : (STAGE12_BOLD_EN ? 9'd96 : 9'd0))))) : 9'd256);
    localparam [8:0] FLAT_CHROMA_ALPHA_Q8 =
        (FLATTEN_MODE == FLATTEN_SLIGHT) ? (STAGE18_PY_TARGET_EN ? 9'd224 : (STAGE17_ARCH_TARGET_EN ? 9'd224 : (STAGE16_ARCH_BLOCK_RECON_EN ? 9'd192 : 9'd224))) :
        ((FLATTEN_MODE == FLATTEN_FLAT) ? (STAGE18_PY_TARGET_EN ? 9'd232 : (STAGE17_ARCH_TARGET_EN ? 9'd256 : (STAGE16_ARCH_BLOCK_RECON_EN ? 9'd224 : (STAGE14_DELTA_RGB_EN ? 9'd256 : 9'd232)))) : 9'd256);
    localparam [8:0] FLAT_SMEAR_ALPHA_Q8 =
        (FLATTEN_MODE == FLATTEN_SLIGHT) ? (STAGE18_PY_TARGET_EN ? 9'd192 : (STAGE17_ARCH_TARGET_EN ? 9'd192 : (STAGE16_ARCH_BLOCK_RECON_EN ? 9'd128 : 9'd192))) :
        ((FLATTEN_MODE == FLATTEN_FLAT) ? (STAGE18_PY_TARGET_EN ? 9'd208 : (STAGE17_ARCH_TARGET_EN ? 9'd208 : (STAGE16_ARCH_BLOCK_RECON_EN ? 9'd128 : (STAGE14_DELTA_RGB_EN ? 9'd160 : 9'd208)))) : 9'd0);
    localparam [8:0] FLAT_LOW2_ALPHA_Q8 =
        (FLATTEN_MODE == FLATTEN_SLIGHT) ? (STAGE18_PY_TARGET_EN ? 9'd0 : 9'd96) :
        ((FLATTEN_MODE == FLATTEN_FLAT) ? (STAGE18_PY_TARGET_EN ? 9'd0 : 9'd160) : 9'd0);
    localparam [8:0] FLAT_LOW4_ALPHA_Q8 =
        (FLATTEN_MODE == FLATTEN_SLIGHT) ? (STAGE18_PY_TARGET_EN ? 9'd96 : (STAGE17_ARCH_TARGET_EN ? 9'd96 : (STAGE13_MEDIAN_TARGET_EN ? 9'd192 : 9'd64))) :
        ((FLATTEN_MODE == FLATTEN_FLAT) ? (STAGE18_PY_TARGET_EN ? 9'd160 : (STAGE17_ARCH_TARGET_EN ? 9'd160 : (STAGE14_DELTA_RGB_EN ? 9'd0 : (STAGE13_MEDIAN_TARGET_EN ? 9'd64 : 9'd160)))) : 9'd0);
    localparam [8:0] FLAT_SNAP_ALPHA_Q8 =
        (FLATTEN_MODE == FLATTEN_SLIGHT) ? (STAGE18_PY_TARGET_EN ? 9'd96 : (STAGE17_ARCH_TARGET_EN ? 9'd96 : (STAGE16_ARCH_BLOCK_RECON_EN ? 9'd64 : (STAGE14_DELTA_RGB_EN ? 9'd64 : 9'd96)))) :
        ((FLATTEN_MODE == FLATTEN_FLAT) ? (STAGE18_PY_TARGET_EN ? 9'd112 : (STAGE17_ARCH_TARGET_EN ? 9'd112 : (STAGE16_ARCH_BLOCK_RECON_EN ? 9'd64 : (STAGE13_MEDIAN_TARGET_EN ? 9'd96 : 9'd112)))) : 9'd0);
    localparam [7:0] FLAT_NEUTRAL_TH =
        (FLATTEN_MODE == FLATTEN_SLIGHT) ? (STAGE18_PY_TARGET_EN ? 8'd24 : (STAGE17_ARCH_TARGET_EN ? 8'd24 : (STAGE16_ARCH_BLOCK_RECON_EN ? 8'd20 : (STAGE14_DELTA_RGB_EN ? 8'd24 : (STAGE13_MEDIAN_TARGET_EN ? 8'd20 : 8'd24))))) :
        ((FLATTEN_MODE == FLATTEN_FLAT) ? (STAGE18_PY_TARGET_EN ? 8'd28 : (STAGE17_ARCH_TARGET_EN ? 8'd28 : (STAGE16_ARCH_BLOCK_RECON_EN ? 8'd28 : (STAGE14_DELTA_RGB_EN ? 8'd16 : (STAGE13_MEDIAN_TARGET_EN ? 8'd20 : 8'd28))))) : 8'd0);
    localparam [7:0] FLAT_BLACK_Y_TH =
        (FLATTEN_MODE == FLATTEN_SLIGHT) ? (STAGE18_PY_TARGET_EN ? 8'd112 : (STAGE17_ARCH_TARGET_EN ? 8'd128 : (STAGE16_ARCH_BLOCK_RECON_EN ? 8'd80 : 8'd112))) :
        ((FLATTEN_MODE == FLATTEN_FLAT) ? (STAGE18_PY_TARGET_EN ? 8'd112 : (STAGE17_ARCH_TARGET_EN ? 8'd160 : (STAGE16_ARCH_BLOCK_RECON_EN ? 8'd96 : (STAGE14_DELTA_RGB_EN ? 8'd96 : (STAGE13_MEDIAN_TARGET_EN ? 8'd160 : 8'd112))))) : 8'd0);
    localparam [8:0] FLAT_QUANT_ALPHA_Q8 =
        (FLATTEN_MODE == FLATTEN_SLIGHT) ? (STAGE18_PY_TARGET_EN ? 9'd96 : (STAGE17_ARCH_TARGET_EN ? 9'd96 : (STAGE16_ARCH_BLOCK_RECON_EN ? 9'd32 : 9'd64))) :
        ((FLATTEN_MODE == FLATTEN_FLAT) ? (STAGE18_PY_TARGET_EN ? 9'd128 : (STAGE17_ARCH_TARGET_EN ? 9'd128 : (STAGE14_DELTA_RGB_EN ? 9'd64 : 9'd128))) : 9'd0);
    localparam [7:0] STAGE17_FLAT_SUPPORT_TH =
        (FLATTEN_MODE == FLATTEN_SLIGHT) ? (STAGE18_PY_TARGET_EN ? 8'd64 : 8'd64) :
        ((FLATTEN_MODE == FLATTEN_FLAT) ? (STAGE18_PY_TARGET_EN ? 8'd48 : 8'd48) : 8'd255);
    // Preserve the original RGB base when delta-safe flatten is requested so
    // the flatten stage behaves like the Python target model instead of fully
    // re-synthesizing RGB from flattened YCbCr.
    localparam       DIRECT_YCBCR_RGB =
        (FLATTEN_MODE != FLATTEN_NATIVE) &&
        !STAGE14_DELTA_RGB_EN &&
        (DELTA_SAFE_FLATTEN_EN == 0);
    localparam integer BILATERAL_EXTRA_LATENCY = 5;

    reg         de_s0_r;
    reg  [23:0] rgb_s0_r;
    reg         rgb2ycc_prod_de_r;
    reg  [23:0] rgb2ycc_prod_rgb_r;
    reg  [15:0] rgb2ycc_r_y_r;
    reg  [15:0] rgb2ycc_g_y_r;
    reg  [15:0] rgb2ycc_b_y_r;
    reg  [15:0] rgb2ycc_r_cb_r;
    reg  [15:0] rgb2ycc_g_cb_r;
    reg  [15:0] rgb2ycc_b_cb_r;
    reg  [15:0] rgb2ycc_r_cr_r;
    reg  [15:0] rgb2ycc_g_cr_r;
    reg  [15:0] rgb2ycc_b_cr_r;
    reg         rgb2ycc_de_r;
    reg  [23:0] rgb2ycc_rgb_r;
    reg  [7:0]  rgb2ycc_y_r;
    reg  [7:0]  rgb2ycc_cb_r;
    reg  [7:0]  rgb2ycc_cr_r;
    reg         y_cross_align_de_d1_r;
    reg         y_cross_align_de_d2_r;
    reg  [7:0]  y_cross_align_center_d1_r;
    reg  [7:0]  y_cross_align_center_d2_r;
    reg  [7:0]  y_cross_align_filtered_d1_r;
    reg  [7:0]  y_cross_align_filtered_d2_r;
    reg         rgb_cross_align_de_d1_r;
    reg         rgb_cross_align_de_d2_r;
    reg  [23:0] rgb_cross_align_d1_r;
    reg  [23:0] rgb_cross_align_d2_r;
    reg [BILATERAL_EXTRA_LATENCY-1:0] cb_de_align_r;
    reg [BILATERAL_EXTRA_LATENCY-1:0] cr_de_align_r;
    reg [BILATERAL_EXTRA_LATENCY-1:0] rgb_de_align_r;
    reg [BILATERAL_EXTRA_LATENCY*8-1:0] cb_center_align_r;
    reg [BILATERAL_EXTRA_LATENCY*8-1:0] cr_center_align_r;
    reg [BILATERAL_EXTRA_LATENCY*8-1:0] cb_filtered_align_r;
    reg [BILATERAL_EXTRA_LATENCY*8-1:0] cr_filtered_align_r;
    reg [BILATERAL_EXTRA_LATENCY*24-1:0] rgb_center_align_r;
    reg         bilat_de_s1_r;
    reg  [7:0]  y_center_s1_r;
    reg  [7:0]  y_filtered_s1_r;
    reg  [7:0]  cb_center_s1_r;
    reg  [7:0]  cr_center_s1_r;
    reg  [7:0]  cb_filtered_s1_r;
    reg  [7:0]  cr_filtered_s1_r;
    reg  [7:0]  cb_low2_s1_r;
    reg  [7:0]  cr_low2_s1_r;
    reg  [7:0]  cb_low4_s1_r;
    reg  [7:0]  cr_low4_s1_r;
    reg  [7:0]  flat_support_s1_r;
    reg  [7:0]  r_center_s1_r;
    reg  [7:0]  g_center_s1_r;
    reg  [7:0]  b_center_s1_r;
    reg         apply_de_s2_r;
    reg  [7:0]  y_center_s2_r;
    reg  [7:0]  cb_center_s2_r;
    reg  [7:0]  cr_center_s2_r;
    reg  [7:0]  y_flat_s2_r;
    reg  [7:0]  cb_mix_s2_r;
    reg  [7:0]  cr_mix_s2_r;
    reg  [7:0]  cb_low2_s2_r;
    reg  [7:0]  cr_low2_s2_r;
    reg  [7:0]  cb_low4_s2_r;
    reg  [7:0]  cr_low4_s2_r;
    reg  [8:0]  py_base_gate_s2_r;
    reg         flatten_gate_s2_r;
    reg         native_luma_gate_s2_r;
    reg  [7:0]  r_center_s2_r;
    reg  [7:0]  g_center_s2_r;
    reg  [7:0]  b_center_s2_r;
    reg  [7:0]  stage19_r_s2_r;
    reg  [7:0]  stage19_g_s2_r;
    reg  [7:0]  stage19_b_s2_r;
    reg  [7:0]  stage19_y_s2_r;
    reg  [7:0]  stage19_rg_diff_s2_r;
    reg  [7:0]  stage19_b_delta_s2_r;
    reg         apply_de_s3_r;
    reg  [7:0]  y_center_s3_r;
    reg  [7:0]  cb_center_s3_r;
    reg  [7:0]  cr_center_s3_r;
    reg  [7:0]  y_flat_s3_r;
    reg  [7:0]  cb_smear_s3_r;
    reg  [7:0]  cr_smear_s3_r;
    reg  [7:0]  cb_low2_s3_r;
    reg  [7:0]  cr_low2_s3_r;
    reg  [7:0]  cb_low4_s3_r;
    reg  [7:0]  cr_low4_s3_r;
    reg  [8:0]  py_base_gate_s3_r;
    reg         flatten_gate_s3_r;
    reg         native_luma_gate_s3_r;
    reg  [7:0]  r_center_s3_r;
    reg  [7:0]  g_center_s3_r;
    reg  [7:0]  b_center_s3_r;
    reg  [7:0]  stage19_r_s3_r;
    reg  [7:0]  stage19_g_s3_r;
    reg  [7:0]  stage19_b_s3_r;
    reg  [7:0]  stage19_b_delta_s3_r;
    reg  [7:0]  stage19_alpha_s3_r;
    reg         apply_de_s4_r;
    reg  [7:0]  y_center_s4_r;
    reg  [7:0]  cb_center_s4_r;
    reg  [7:0]  cr_center_s4_r;
    reg  [7:0]  y_flat_s4_r;
    reg  [7:0]  cb_low2_mix_s4_r;
    reg  [7:0]  cr_low2_mix_s4_r;
    reg  [7:0]  cb_low4_s4_r;
    reg  [7:0]  cr_low4_s4_r;
    reg  [8:0]  py_base_gate_s4_r;
    reg         flatten_gate_s4_r;
    reg         native_luma_gate_s4_r;
    reg         black_neutral_gate_s4_r;
    reg  [7:0]  r_center_s4_r;
    reg  [7:0]  g_center_s4_r;
    reg  [7:0]  b_center_s4_r;
    reg  [23:0] stage19_rgb_s4_r;
    reg         apply_de_s5_r;
    reg  [7:0]  y_center_s5_r;
    reg  [7:0]  cb_center_s5_r;
    reg  [7:0]  cr_center_s5_r;
    reg  [7:0]  y_flat_s5_r;
    reg  [7:0]  cb_low4_mix_s5_r;
    reg  [7:0]  cr_low4_mix_s5_r;
    reg  [8:0]  py_base_gate_s5_r;
    reg         flatten_gate_s5_r;
    reg         native_luma_gate_s5_r;
    reg         black_neutral_gate_s5_r;
    reg  [7:0]  r_center_s5_r;
    reg  [7:0]  g_center_s5_r;
    reg  [7:0]  b_center_s5_r;
    reg  [23:0] stage19_rgb_s5_r;
    reg         apply_de_s6_r;
    reg  [7:0]  y_center_s6_r;
    reg  [7:0]  cb_center_s6_r;
    reg  [7:0]  cr_center_s6_r;
    reg  [7:0]  y_flat_s6_r;
    reg  [7:0]  cb_pre_quant_s6_r;
    reg  [7:0]  cr_pre_quant_s6_r;
    reg  [8:0]  py_base_gate_s6_r;
    reg         flatten_gate_s6_r;
    reg         native_luma_gate_s6_r;
    reg         black_neutral_gate_s6_r;
    reg  [7:0]  r_center_s6_r;
    reg  [7:0]  g_center_s6_r;
    reg  [7:0]  b_center_s6_r;
    reg  [23:0] stage19_rgb_s6_r;
    reg         apply_de_s7_r;
    reg  [7:0]  y_center_s7_r;
    reg  [7:0]  cb_center_s7_r;
    reg  [7:0]  cr_center_s7_r;
    reg  [7:0]  y_out_s7_r;
    reg  [7:0]  cb_out_s7_r;
    reg  [7:0]  cr_out_s7_r;
    reg  [7:0]  r_center_s7_r;
    reg  [7:0]  g_center_s7_r;
    reg  [7:0]  b_center_s7_r;
    reg  [23:0] stage19_rgb_s7_r;
    reg         apply_de_s8_r;
    reg  [7:0]  r_center_s8_r;
    reg  [7:0]  g_center_s8_r;
    reg  [7:0]  b_center_s8_r;
    reg signed [8:0]  y_apply_delta_s8_r;
    reg signed [18:0] r_term_s8_r;
    reg signed [18:0] g_cb_term_s8_r;
    reg signed [18:0] g_cr_term_s8_r;
    reg signed [18:0] b_term_s8_r;
    reg  [23:0] stage19_rgb_s8_r;
    reg         apply_de_s9_r;
    reg signed [19:0] out_r_sum_s9_r;
    reg signed [19:0] out_g_sum_s9_r;
    reg signed [19:0] out_b_sum_s9_r;
    reg  [23:0] stage19_rgb_s9_r;
    reg  [23:0] bypass_rgb_s9_r;
    reg         apply_de_s10_r;
    reg  [23:0] filtered_rgb_s10_r;
    reg  [23:0] bypass_rgb_s10_r;
    reg         out_de_r;
    reg  [23:0] out_rgb_r;
    wire runtime_bypass_en_w = (cfg_runtime_bypass_en === 1'b1);

    wire [7:0] in_r_w = rgb_s0_r[23:16];
    wire [7:0] in_g_w = rgb_s0_r[15:8];
    wire [7:0] in_b_w = rgb_s0_r[7:0];

    wire [15:0] r_y_w  = in_r_w * 8'd77;
    wire [15:0] g_y_w  = in_g_w * 8'd150;
    wire [15:0] b_y_w  = in_b_w * 8'd29;
    wire [15:0] r_cb_w = in_r_w * 8'd43;
    wire [15:0] g_cb_w = in_g_w * 8'd85;
    wire [15:0] b_cb_w = in_b_w << 7;
    wire [15:0] r_cr_w = in_r_w << 7;
    wire [15:0] g_cr_w = in_g_w * 8'd107;
    wire [15:0] b_cr_w = in_b_w * 8'd21;

    wire [15:0] y_acc_w = rgb2ycc_r_y_r + rgb2ycc_g_y_r + rgb2ycc_b_y_r;
    wire signed [17:0] cb_acc_w =
        $signed({2'b00, rgb2ycc_b_cb_r}) -
        $signed({2'b00, rgb2ycc_r_cb_r}) -
        $signed({2'b00, rgb2ycc_g_cb_r}) +
        18'sd32768;
    wire signed [17:0] cr_acc_w =
        $signed({2'b00, rgb2ycc_r_cr_r}) -
        $signed({2'b00, rgb2ycc_g_cr_r}) -
        $signed({2'b00, rgb2ycc_b_cr_r}) +
        18'sd32768;

    wire [7:0] rgb2ycc_y_w  = y_acc_w[15:8];
    wire [7:0] rgb2ycc_cb_w = clip_u8(cb_acc_w >>> 8);
    wire [7:0] rgb2ycc_cr_w = clip_u8(cr_acc_w >>> 8);

    wire        y_de_w;
    wire        cb_de_w;
    wire        cr_de_w;
    wire        rgb_de_w;
    wire        r_de_w;
    wire        g_de_w;
    wire        b_de_w;
    wire        y_center_dly_de_w;
    wire        y_filtered_dly_de_w;
    wire        cb_center_dly_de_w;
    wire        cr_center_dly_de_w;
    wire        cb_smear_de_w;
    wire        cr_smear_de_w;
    wire        flat_support_de_w;
    wire        rgb_dly_de_w;
    wire        r_dly_de_w;
    wire        g_dly_de_w;
    wire        b_dly_de_w;
    wire [7:0]  y_center_w;
    wire [7:0]  y_filtered_w;
    wire [7:0]  cb_center_w;
    wire [7:0]  cb_filtered_w;
    wire [7:0]  cr_center_w;
    wire [7:0]  cr_filtered_w;
    wire [23:0] rgb_center_w;
    wire [7:0]  r_center_w;
    wire [7:0]  g_center_w;
    wire [7:0]  b_center_w;
    wire [7:0]  y_center_dly_w;
    wire [7:0]  y_filtered_dly_w;
    wire [7:0]  cb_center_dly_w;
    wire [7:0]  cr_center_dly_w;
    wire [7:0]  cb_filtered_dly_w;
    wire [7:0]  cr_filtered_dly_w;
    wire [7:0]  cb_low2_w;
    wire [7:0]  cr_low2_w;
    wire [7:0]  cb_low4_w;
    wire [7:0]  cr_low4_w;
    wire [7:0]  flat_support_w;
    wire [23:0] rgb_center_dly_w;
    wire [7:0]  r_center_dly_w;
    wire [7:0]  g_center_dly_w;
    wire [7:0]  b_center_dly_w;
    wire [7:0]  y_center_dly_unused_w;
    wire [7:0]  y_filtered_dly_unused_w;
    wire [7:0]  cb_center_dly_unused_w;
    wire [7:0]  cr_center_dly_unused_w;
    wire [7:0]  flat_support_center_unused_w;
    wire [7:0]  flat_support_box2_unused_w;
    wire [7:0]  r_dly_unused_w;
    wire [7:0]  g_dly_unused_w;
    wire [7:0]  b_dly_unused_w;

    stream_plane_bilateral_5x5
    #(
        .H_DISP   (H_DISP),
        .V_DISP   (V_DISP),
        .ENABLE   (ENABLE),
        .RANGE_TH (RANGE_TH)
    )
    u_y_bilateral
    (
        .clk          (clk),
        .rst_n        (rst_n),
        .frame_clr    (frame_clr),
        .din_vld      (rgb2ycc_de_r),
        .din          (rgb2ycc_y_r),
        .out_vld      (y_de_w),
        .out_center   (y_center_w),
        .out_filtered (y_filtered_w)
    );

    stream_plane_cross5_5x5
    #(
        .H_DISP   (H_DISP),
        .V_DISP   (V_DISP),
        .TARGET_MODE (STAGE18_PY_TARGET_EN ? 2'd3 : (STAGE13_MEDIAN_TARGET_EN ? FLATTEN_MODE : FLATTEN_NATIVE))
    )
    u_cb_cross5
    (
        .clk          (clk),
        .rst_n        (rst_n),
        .frame_clr    (frame_clr),
        .din_vld      (rgb2ycc_de_r),
        .din          (rgb2ycc_cb_r),
        .out_vld      (cb_de_w),
        .out_center   (cb_center_w),
        .out_target   (cb_filtered_w),
        .out_blur     ()
    );

    stream_plane_cross5_5x5
    #(
        .H_DISP   (H_DISP),
        .V_DISP   (V_DISP),
        .TARGET_MODE (STAGE18_PY_TARGET_EN ? 2'd3 : (STAGE13_MEDIAN_TARGET_EN ? FLATTEN_MODE : FLATTEN_NATIVE))
    )
    u_cr_cross5
    (
        .clk          (clk),
        .rst_n        (rst_n),
        .frame_clr    (frame_clr),
        .din_vld      (rgb2ycc_de_r),
        .din          (rgb2ycc_cr_r),
        .out_vld      (cr_de_w),
        .out_center   (cr_center_w),
        .out_target   (cr_filtered_w),
        .out_blur     ()
    );

    generate
    if (DIRECT_YCBCR_RGB) begin : gen_direct_rgb_first_align
        assign rgb_de_w = y_de_w;
        assign rgb_center_w = 24'd0;
    end else begin : gen_native_rgb_first_align
        stream_rgb_center_delay_5x5
        #(
            .H_DISP (H_DISP),
            .V_DISP (V_DISP)
        )
        u_rgb_delay
        (
            .clk            (clk),
            .rst_n          (rst_n),
            .frame_clr      (frame_clr),
            .din_vld        (rgb2ycc_de_r),
            .din_rgb        (rgb2ycc_rgb_r),
            .out_vld        (rgb_de_w),
            .out_center_rgb (rgb_center_w)
        );
    end
    endgenerate

    wire y_de_aligned_w = y_de_w;
    wire [7:0] y_center_aligned_w = y_center_w;
    wire [7:0] y_filtered_aligned_w = y_filtered_w;
    wire cb_de_aligned_w = cb_de_align_r[BILATERAL_EXTRA_LATENCY-1];
    wire cr_de_aligned_w = cr_de_align_r[BILATERAL_EXTRA_LATENCY-1];
    wire rgb_de_delay_aligned_w = rgb_de_align_r[BILATERAL_EXTRA_LATENCY-1];
    wire [7:0] cb_center_aligned_w =
        cb_center_align_r[BILATERAL_EXTRA_LATENCY*8-1:(BILATERAL_EXTRA_LATENCY-1)*8];
    wire [7:0] cr_center_aligned_w =
        cr_center_align_r[BILATERAL_EXTRA_LATENCY*8-1:(BILATERAL_EXTRA_LATENCY-1)*8];
    wire [7:0] cb_filtered_aligned_w =
        cb_filtered_align_r[BILATERAL_EXTRA_LATENCY*8-1:(BILATERAL_EXTRA_LATENCY-1)*8];
    wire [7:0] cr_filtered_aligned_w =
        cr_filtered_align_r[BILATERAL_EXTRA_LATENCY*8-1:(BILATERAL_EXTRA_LATENCY-1)*8];
    wire [23:0] rgb_center_delay_aligned_w =
        rgb_center_align_r[BILATERAL_EXTRA_LATENCY*24-1:(BILATERAL_EXTRA_LATENCY-1)*24];
    wire rgb_de_aligned_w = DIRECT_YCBCR_RGB ? rgb_de_w : rgb_de_delay_aligned_w;
    wire [23:0] rgb_center_aligned_w = DIRECT_YCBCR_RGB ? 24'd0 : rgb_center_delay_aligned_w;

    assign r_de_w = rgb_de_aligned_w;
    assign g_de_w = rgb_de_aligned_w;
    assign b_de_w = rgb_de_aligned_w;
    assign r_center_w = rgb_center_aligned_w[23:16];
    assign g_center_w = rgb_center_aligned_w[15:8];
    assign b_center_w = rgb_center_aligned_w[7:0];

    wire stage1_de_w = y_de_aligned_w & cb_de_aligned_w & cr_de_aligned_w & r_de_w & g_de_w & b_de_w;
    wire signed [8:0] flat_seed_y_delta_w =
        $signed({1'b0, y_filtered_aligned_w}) - $signed({1'b0, y_center_aligned_w});
    wire [8:0] flat_seed_y_abs_w =
        flat_seed_y_delta_w[8] ? (~flat_seed_y_delta_w + 9'd1) : flat_seed_y_delta_w;
    wire [7:0] flat_support_seed_w =
        ((STAGE17_ARCH_TARGET_EN || STAGE18_PY_TARGET_EN) &&
         (FLATTEN_MODE != FLATTEN_NATIVE) &&
         (flat_seed_y_abs_w <= {1'b0, FLAT_LOCAL_DIFF_TH}) &&
         (y_center_aligned_w <= FLAT_DARK_Y_TH)) ? 8'd255 : 8'd0;

    stream_plane_delay4_3x3
    #(
        .H_DISP   (H_DISP),
        .V_DISP   (V_DISP)
    )
    u_y_center_delay4
    (
        .clk          (clk),
        .rst_n        (rst_n),
        .frame_clr    (frame_clr),
        .din_vld      (stage1_de_w),
        .din          (y_center_aligned_w),
        .out_vld      (y_center_dly_de_w),
        .out_center   (y_center_dly_w)
    );

    stream_plane_delay4_3x3
    #(
        .H_DISP   (H_DISP),
        .V_DISP   (V_DISP)
    )
    u_y_filtered_delay4
    (
        .clk          (clk),
        .rst_n        (rst_n),
        .frame_clr    (frame_clr),
        .din_vld      (stage1_de_w),
        .din          (y_filtered_aligned_w),
        .out_vld      (y_filtered_dly_de_w),
        .out_center   (y_filtered_dly_w)
    );

    stream_plane_delay4_3x3
    #(
        .H_DISP   (H_DISP),
        .V_DISP   (V_DISP)
    )
    u_cb_center_delay4
    (
        .clk          (clk),
        .rst_n        (rst_n),
        .frame_clr    (frame_clr),
        .din_vld      (stage1_de_w),
        .din          (cb_center_aligned_w),
        .out_vld      (cb_center_dly_de_w),
        .out_center   (cb_center_dly_w)
    );

    stream_plane_delay4_3x3
    #(
        .H_DISP   (H_DISP),
        .V_DISP   (V_DISP)
    )
    u_cr_center_delay4
    (
        .clk          (clk),
        .rst_n        (rst_n),
        .frame_clr    (frame_clr),
        .din_vld      (stage1_de_w),
        .din          (cr_center_aligned_w),
        .out_vld      (cr_center_dly_de_w),
        .out_center   (cr_center_dly_w)
    );

    generate
    if (STAGE16_ARCH_BLOCK_RECON_EN || STAGE18_PY_TARGET_EN) begin : gen_stage16_box_recon
        stream_plane_box4_align
        #(
            .H_DISP   (H_DISP),
            .V_DISP   (V_DISP),
            .ENABLE   (CHROMA_FILTER_EN)
        )
        u_cb_large_recon
        (
            .clk        (clk),
            .rst_n      (rst_n),
            .frame_clr  (frame_clr),
            .din_vld    (stage1_de_w),
            .din        (cb_filtered_aligned_w),
            .out_vld    (cb_smear_de_w),
            .out_center (cb_filtered_dly_w),
            .out_box2   (cb_low2_w),
            .out_box4   (cb_low4_w)
        );

        stream_plane_box4_align
        #(
            .H_DISP   (H_DISP),
            .V_DISP   (V_DISP),
            .ENABLE   (CHROMA_FILTER_EN)
        )
        u_cr_large_recon
        (
            .clk        (clk),
            .rst_n      (rst_n),
            .frame_clr  (frame_clr),
            .din_vld    (stage1_de_w),
            .din        (cr_filtered_aligned_w),
            .out_vld    (cr_smear_de_w),
            .out_center (cr_filtered_dly_w),
            .out_box2   (cr_low2_w),
            .out_box4   (cr_low4_w)
        );
    end else begin : gen_stage10_blur_recon
        stream_plane_blur4_align
        #(
            .H_DISP   (H_DISP),
            .V_DISP   (V_DISP),
            .ENABLE   (CHROMA_FILTER_EN)
        )
        u_cb_large_recon
        (
            .clk          (clk),
            .rst_n        (rst_n),
            .frame_clr    (frame_clr),
            .din_vld      (stage1_de_w),
            .din          (cb_filtered_aligned_w),
            .out_vld      (cb_smear_de_w),
            .out_center   (cb_filtered_dly_w),
            .out_blur2    (cb_low2_w),
            .out_blur4    (cb_low4_w)
        );

        stream_plane_blur4_align
        #(
            .H_DISP   (H_DISP),
            .V_DISP   (V_DISP),
            .ENABLE   (CHROMA_FILTER_EN)
        )
        u_cr_large_recon
        (
            .clk          (clk),
            .rst_n        (rst_n),
            .frame_clr    (frame_clr),
            .din_vld      (stage1_de_w),
            .din          (cr_filtered_aligned_w),
            .out_vld      (cr_smear_de_w),
            .out_center   (cr_filtered_dly_w),
            .out_blur2    (cr_low2_w),
            .out_blur4    (cr_low4_w)
        );
    end
    endgenerate

    stream_plane_box4_align
    #(
        .H_DISP   (H_DISP),
        .V_DISP   (V_DISP),
        .ENABLE   (STAGE17_ARCH_TARGET_EN || STAGE18_PY_TARGET_EN)
    )
    u_flat_support_box4
    (
        .clk        (clk),
        .rst_n      (rst_n),
        .frame_clr  (frame_clr),
        .din_vld    (stage1_de_w),
        .din        (flat_support_seed_w),
        .out_vld    (flat_support_de_w),
        .out_center (flat_support_center_unused_w),
        .out_box2   (flat_support_box2_unused_w),
        .out_box4   (flat_support_w)
    );

    generate
    if (DIRECT_YCBCR_RGB) begin : gen_direct_rgb_final_align
        assign rgb_dly_de_w = y_center_dly_de_w;
        assign rgb_center_dly_w = 24'd0;
    end else begin : gen_native_rgb_final_align
        stream_rgb_delay4_3x3
        #(
            .H_DISP   (H_DISP),
            .V_DISP   (V_DISP)
        )
        u_rgb_delay4
        (
            .clk            (clk),
            .rst_n          (rst_n),
            .frame_clr      (frame_clr),
            .din_vld        (stage1_de_w),
            .din_rgb        ({r_center_w, g_center_w, b_center_w}),
            .out_vld        (rgb_dly_de_w),
            .out_center_rgb (rgb_center_dly_w)
        );
    end
    endgenerate

    assign r_dly_de_w = rgb_dly_de_w;
    assign g_dly_de_w = rgb_dly_de_w;
    assign b_dly_de_w = rgb_dly_de_w;
    assign r_center_dly_w = rgb_center_dly_w[23:16];
    assign g_center_dly_w = rgb_center_dly_w[15:8];
    assign b_center_dly_w = rgb_center_dly_w[7:0];

    wire bilat_de_w =
        y_center_dly_de_w & y_filtered_dly_de_w &
        cb_center_dly_de_w & cr_center_dly_de_w &
        cb_smear_de_w & cr_smear_de_w &
        ((STAGE17_ARCH_TARGET_EN || STAGE18_PY_TARGET_EN) ? flat_support_de_w : 1'b1) &
        r_dly_de_w & g_dly_de_w & b_dly_de_w;
    wire signed [8:0] y_delta_s1_w = $signed({1'b0, y_filtered_s1_r}) - $signed({1'b0, y_center_s1_r});
    wire [8:0] y_delta_abs_s1_w = y_delta_s1_w[8] ? (~y_delta_s1_w + 9'd1) : y_delta_s1_w;
    wire stage17_flat_support_gate_s1_w =
        !(STAGE17_ARCH_TARGET_EN || STAGE18_PY_TARGET_EN) || (flat_support_s1_r >= STAGE17_FLAT_SUPPORT_TH);
    wire flatten_gate_s1_w =
        (FLATTEN_MODE != FLATTEN_NATIVE) &&
        (y_center_s1_r <= FLAT_DARK_Y_TH) &&
        (y_delta_abs_s1_w <= {1'b0, FLAT_LOCAL_DIFF_TH}) &&
        stage17_flat_support_gate_s1_w;

    wire signed [18:0] y_mix_delta_s1_w =
        y_delta_s1_w * $signed({1'b0, FLAT_Y_ALPHA_Q8});
    wire signed [8:0] cb_filter_delta_s1_w =
        $signed({1'b0, cb_filtered_s1_r}) - $signed({1'b0, cb_center_s1_r});
    wire signed [8:0] cr_filter_delta_s1_w =
        $signed({1'b0, cr_filtered_s1_r}) - $signed({1'b0, cr_center_s1_r});
    wire [8:0] cb_filter_abs_s1_w =
        cb_filter_delta_s1_w[8] ? (~cb_filter_delta_s1_w + 9'd1) : cb_filter_delta_s1_w;
    wire [8:0] cr_filter_abs_s1_w =
        cr_filter_delta_s1_w[8] ? (~cr_filter_delta_s1_w + 9'd1) : cr_filter_delta_s1_w;
    wire [9:0] py_speckle_mag_s1_w =
        {1'b0, cb_filter_abs_s1_w} + {1'b0, cr_filter_abs_s1_w};
    wire signed [8:0] cb_target_sat_delta_s1_w = $signed({1'b0, cb_filtered_s1_r}) - 9'sd128;
    wire signed [8:0] cr_target_sat_delta_s1_w = $signed({1'b0, cr_filtered_s1_r}) - 9'sd128;
    wire [8:0] cb_target_sat_abs_s1_w =
        cb_target_sat_delta_s1_w[8] ? (~cb_target_sat_delta_s1_w + 9'd1) : cb_target_sat_delta_s1_w;
    wire [8:0] cr_target_sat_abs_s1_w =
        cr_target_sat_delta_s1_w[8] ? (~cr_target_sat_delta_s1_w + 9'd1) : cr_target_sat_delta_s1_w;
    wire [9:0] py_target_sat_s1_w =
        {1'b0, cb_target_sat_abs_s1_w} + {1'b0, cr_target_sat_abs_s1_w};
    wire [7:0] py_dark_span_s1_w =
        (y_center_s1_r < 8'd192) ? (8'd192 - y_center_s1_r) : 8'd0;
    wire [8:0] py_flat_gate_s1_w =
        clip_q8($signed({2'b00, FLAT_LOCAL_DIFF_TH, 3'b000}) - $signed({1'b0, y_delta_abs_s1_w, 3'b000}));
    wire [8:0] py_dark_gate_s1_w =
        clip_q8(13'sd160 + $signed({6'b000000, py_dark_span_s1_w[7:1]}));
    wire [8:0] py_bright_guard_s1_w =
        ((y_center_s1_r > 8'd224) && (py_target_sat_s1_w <= {1'b0, FLAT_NEUTRAL_TH, 1'b0})) ? 9'd128 :
        (((y_center_s1_r > 8'd208) && (py_target_sat_s1_w <= {1'b0, FLAT_NEUTRAL_TH, 1'b0})) ? 9'd192 : 9'd256);
    wire [8:0] py_base_gate_s1_w =
        min_q8(min_q8(py_flat_gate_s1_w, py_dark_gate_s1_w), py_bright_guard_s1_w);
    wire [8:0] py_speckle_boost_s1_w = {1'b0, py_speckle_mag_s1_w[9:2]};
    wire [8:0] chroma_alpha_s1_w =
        STAGE18_PY_TARGET_EN ?
        min_q8(FLAT_CHROMA_ALPHA_Q8, clip_q8($signed({4'b0000, py_base_gate_s1_w}) + $signed({4'b0000, py_speckle_boost_s1_w}))) :
        FLAT_CHROMA_ALPHA_Q8;
    wire signed [18:0] cb_mix_delta_s1_w =
        cb_filter_delta_s1_w * $signed({1'b0, chroma_alpha_s1_w});
    wire signed [18:0] cr_mix_delta_s1_w =
        cr_filter_delta_s1_w * $signed({1'b0, chroma_alpha_s1_w});
    wire [7:0] y_flat_s1_w = clip_u8($signed({1'b0, y_center_s1_r}) + ((y_mix_delta_s1_w + 19'sd128) >>> 8));
    wire [7:0] cb_mix_s1_w = clip_u8($signed({1'b0, cb_center_s1_r}) + ((cb_mix_delta_s1_w + 19'sd128) >>> 8));
    wire [7:0] cr_mix_s1_w = clip_u8($signed({1'b0, cr_center_s1_r}) + ((cr_mix_delta_s1_w + 19'sd128) >>> 8));
    wire native_luma_gate_s1_w = (FLATTEN_MODE == FLATTEN_NATIVE) && (ENABLE != 0);
    wire [7:0] stage19_min_rg_s1_w =
        (r_center_s1_r <= g_center_s1_r) ? r_center_s1_r : g_center_s1_r;
    wire [7:0] stage19_max_rg_s1_w =
        (r_center_s1_r >= g_center_s1_r) ? r_center_s1_r : g_center_s1_r;
    wire [7:0] stage19_rg_diff_s1_w = stage19_max_rg_s1_w - stage19_min_rg_s1_w;
    wire [7:0] stage19_b_delta_s1_w =
        (stage19_min_rg_s1_w > b_center_s1_r) ? (stage19_min_rg_s1_w - b_center_s1_r) : 8'd0;
    wire [7:0] stage19_yellow_amt_s2_w =
        (stage19_b_delta_s2_r > STAGE19_YELLOW_TH) ? (stage19_b_delta_s2_r - STAGE19_YELLOW_TH) : 8'd0;
    wire stage19_dark_guard_s2_w =
        (stage19_y_s2_r >= STAGE19_DARK_Y_MIN) ||
        (stage19_b_delta_s2_r >= STAGE19_DARK_BDELTA_MIN);
    wire stage19_gate_s2_w =
        (stage19_yellow_amt_s2_w >= STAGE19_YELLOW_MIN_AMT) &&
        (stage19_rg_diff_s2_r <= STAGE19_RG_MAX) &&
        (stage19_y_s2_r >= STAGE19_Y_MIN) &&
        (stage19_y_s2_r <= STAGE19_Y_MAX) &&
        stage19_dark_guard_s2_w;
    wire [9:0] stage19_alpha_pre_s2_w = {2'b00, stage19_yellow_amt_s2_w} << 2;
    wire [7:0] stage19_alpha_s2_w =
        stage19_gate_s2_w ?
        ((stage19_alpha_pre_s2_w > {2'b00, STAGE19_ALPHA_MAX}) ? STAGE19_ALPHA_MAX : stage19_alpha_pre_s2_w[7:0]) :
        8'd0;
    wire [15:0] stage19_b_add_acc_s3_w = (stage19_b_delta_s3_r * stage19_alpha_s3_r) + 16'd128;
    wire [7:0] stage19_b_add_s3_w = stage19_b_add_acc_s3_w[15:8];
    wire [8:0] stage19_b_out_sum_s3_w = {1'b0, stage19_b_s3_r} + {1'b0, stage19_b_add_s3_w};
    wire [7:0] stage19_b_out_s3_w = stage19_b_out_sum_s3_w[8] ? 8'd255 : stage19_b_out_sum_s3_w[7:0];

    wire signed [8:0] cb_smear_delta_s2_w =
        $signed({1'b0, cb_low2_s2_r}) - $signed({1'b0, cb_mix_s2_r});
    wire signed [8:0] cr_smear_delta_s2_w =
        $signed({1'b0, cr_low2_s2_r}) - $signed({1'b0, cr_mix_s2_r});
    wire [8:0] cb_smear_abs_s2_w =
        cb_smear_delta_s2_w[8] ? (~cb_smear_delta_s2_w + 9'd1) : cb_smear_delta_s2_w;
    wire [8:0] cr_smear_abs_s2_w =
        cr_smear_delta_s2_w[8] ? (~cr_smear_delta_s2_w + 9'd1) : cr_smear_delta_s2_w;
    wire [9:0] py_smear_mag_s2_w =
        {1'b0, cb_smear_abs_s2_w} + {1'b0, cr_smear_abs_s2_w};
    wire [8:0] py_smear_boost_s2_w = {1'b0, py_smear_mag_s2_w[9:2]};
    wire [8:0] smear_alpha_s2_w =
        STAGE18_PY_TARGET_EN ?
        min_q8(FLAT_SMEAR_ALPHA_Q8, clip_q8($signed({4'b0000, py_base_gate_s2_r}) + $signed({4'b0000, py_smear_boost_s2_w}))) :
        FLAT_SMEAR_ALPHA_Q8;
    wire signed [18:0] cb_smear_mix_delta_s2_w =
        cb_smear_delta_s2_w * $signed({1'b0, smear_alpha_s2_w});
    wire signed [18:0] cr_smear_mix_delta_s2_w =
        cr_smear_delta_s2_w * $signed({1'b0, smear_alpha_s2_w});
    wire [7:0] cb_smear_mix_s2_w =
        clip_u8($signed({1'b0, cb_mix_s2_r}) + ((cb_smear_mix_delta_s2_w + 19'sd128) >>> 8));
    wire [7:0] cr_smear_mix_s2_w =
        clip_u8($signed({1'b0, cr_mix_s2_r}) + ((cr_smear_mix_delta_s2_w + 19'sd128) >>> 8));

    wire signed [8:0] cb_low2_delta_s3_w =
        $signed({1'b0, cb_low2_s3_r}) - $signed({1'b0, cb_smear_s3_r});
    wire signed [8:0] cr_low2_delta_s3_w =
        $signed({1'b0, cr_low2_s3_r}) - $signed({1'b0, cr_smear_s3_r});
    wire signed [10:0] cb_low2_scaled_s3_w =
        STAGE18_PY_TARGET_EN ? 11'sd0 :
        ((FLATTEN_MODE == FLATTEN_SLIGHT) ? (STAGE16_ARCH_BLOCK_RECON_EN ? 11'sd0 : (STAGE14_DELTA_RGB_EN ? ((cb_low2_delta_s3_w >>> 1) + (cb_low2_delta_s3_w >>> 2)) : ((cb_low2_delta_s3_w >>> 2) + (cb_low2_delta_s3_w >>> 3)))) :
        ((FLATTEN_MODE == FLATTEN_FLAT) ? (STAGE16_ARCH_BLOCK_RECON_EN ? (cb_low2_delta_s3_w >>> 2) : (STAGE14_DELTA_RGB_EN ? cb_low2_delta_s3_w : (STAGE13_MEDIAN_TARGET_EN ? ((cb_low2_delta_s3_w >>> 1) + (cb_low2_delta_s3_w >>> 2) + (cb_low2_delta_s3_w >>> 3)) : ((cb_low2_delta_s3_w >>> 1) + (cb_low2_delta_s3_w >>> 3))))) : 11'sd0));
    wire signed [10:0] cr_low2_scaled_s3_w =
        STAGE18_PY_TARGET_EN ? 11'sd0 :
        ((FLATTEN_MODE == FLATTEN_SLIGHT) ? (STAGE16_ARCH_BLOCK_RECON_EN ? 11'sd0 : (STAGE14_DELTA_RGB_EN ? ((cr_low2_delta_s3_w >>> 1) + (cr_low2_delta_s3_w >>> 2)) : ((cr_low2_delta_s3_w >>> 2) + (cr_low2_delta_s3_w >>> 3)))) :
        ((FLATTEN_MODE == FLATTEN_FLAT) ? (STAGE16_ARCH_BLOCK_RECON_EN ? (cr_low2_delta_s3_w >>> 2) : (STAGE14_DELTA_RGB_EN ? cr_low2_delta_s3_w : (STAGE13_MEDIAN_TARGET_EN ? ((cr_low2_delta_s3_w >>> 1) + (cr_low2_delta_s3_w >>> 2) + (cr_low2_delta_s3_w >>> 3)) : ((cr_low2_delta_s3_w >>> 1) + (cr_low2_delta_s3_w >>> 3))))) : 11'sd0));
    wire signed [10:0] cb_low2_sum_s3_w = $signed({3'b000, cb_smear_s3_r}) + cb_low2_scaled_s3_w;
    wire signed [10:0] cr_low2_sum_s3_w = $signed({3'b000, cr_smear_s3_r}) + cr_low2_scaled_s3_w;
    wire [7:0] cb_low2_mix_s3_w = clip_u8({{9{cb_low2_sum_s3_w[10]}}, cb_low2_sum_s3_w});
    wire [7:0] cr_low2_mix_s3_w = clip_u8({{9{cr_low2_sum_s3_w[10]}}, cr_low2_sum_s3_w});
    wire black_neutral_gate_s3_w =
        flatten_gate_s3_r &&
        (y_center_s3_r <= FLAT_BLACK_Y_TH);

    wire signed [8:0] cb_low4_delta_s4_w =
        $signed({1'b0, cb_low4_s4_r}) - $signed({1'b0, cb_low2_mix_s4_r});
    wire signed [8:0] cr_low4_delta_s4_w =
        $signed({1'b0, cr_low4_s4_r}) - $signed({1'b0, cr_low2_mix_s4_r});
    wire signed [8:0] cb_low2_sat_delta_s4_w = $signed({1'b0, cb_low2_mix_s4_r}) - 9'sd128;
    wire signed [8:0] cr_low2_sat_delta_s4_w = $signed({1'b0, cr_low2_mix_s4_r}) - 9'sd128;
    wire [8:0] cb_low2_sat_abs_s4_w =
        cb_low2_sat_delta_s4_w[8] ? (~cb_low2_sat_delta_s4_w + 9'd1) : cb_low2_sat_delta_s4_w;
    wire [8:0] cr_low2_sat_abs_s4_w =
        cr_low2_sat_delta_s4_w[8] ? (~cr_low2_sat_delta_s4_w + 9'd1) : cr_low2_sat_delta_s4_w;
    wire [9:0] chroma_sat_s4_w =
        {1'b0, cb_low2_sat_abs_s4_w} + {1'b0, cr_low2_sat_abs_s4_w};
    wire [8:0] py_neutral_gate_s4_w =
        clip_q8($signed({1'b0, FLAT_NEUTRAL_TH, 4'b0000}) - $signed({chroma_sat_s4_w, 3'b000}));
    wire [8:0] py_low4_alpha_s4_w =
        black_neutral_gate_s4_r ? min_q8(FLAT_LOW4_ALPHA_Q8, min_q8(py_base_gate_s4_r, py_neutral_gate_s4_w)) : 9'd0;
    wire signed [10:0] cb_low4_scaled_s4_w =
        STAGE18_PY_TARGET_EN ? 11'sd0 :
        ((FLATTEN_MODE == FLATTEN_SLIGHT) ? (STAGE16_ARCH_BLOCK_RECON_EN ? 11'sd0 : (STAGE13_MEDIAN_TARGET_EN ? ((cb_low4_delta_s4_w >>> 1) + (cb_low4_delta_s4_w >>> 2)) : (cb_low4_delta_s4_w >>> 2))) :
        ((FLATTEN_MODE == FLATTEN_FLAT) ? (STAGE16_ARCH_BLOCK_RECON_EN ? (cb_low4_delta_s4_w >>> 2) : (STAGE14_DELTA_RGB_EN ? 11'sd0 : (STAGE13_MEDIAN_TARGET_EN ? (cb_low4_delta_s4_w >>> 2) : ((cb_low4_delta_s4_w >>> 1) + (cb_low4_delta_s4_w >>> 3))))) : 11'sd0));
    wire signed [10:0] cr_low4_scaled_s4_w =
        STAGE18_PY_TARGET_EN ? 11'sd0 :
        ((FLATTEN_MODE == FLATTEN_SLIGHT) ? (STAGE16_ARCH_BLOCK_RECON_EN ? 11'sd0 : (STAGE13_MEDIAN_TARGET_EN ? ((cr_low4_delta_s4_w >>> 1) + (cr_low4_delta_s4_w >>> 2)) : (cr_low4_delta_s4_w >>> 2))) :
        ((FLATTEN_MODE == FLATTEN_FLAT) ? (STAGE16_ARCH_BLOCK_RECON_EN ? (cr_low4_delta_s4_w >>> 2) : (STAGE14_DELTA_RGB_EN ? 11'sd0 : (STAGE13_MEDIAN_TARGET_EN ? (cr_low4_delta_s4_w >>> 2) : ((cr_low4_delta_s4_w >>> 1) + (cr_low4_delta_s4_w >>> 3))))) : 11'sd0));
    wire signed [10:0] cb_low4_sum_s4_w = $signed({3'b000, cb_low2_mix_s4_r}) + cb_low4_scaled_s4_w;
    wire signed [10:0] cr_low4_sum_s4_w = $signed({3'b000, cr_low2_mix_s4_r}) + cr_low4_scaled_s4_w;
    wire signed [18:0] cb_low4_mix_delta_s4_dyn_w =
        cb_low4_delta_s4_w * $signed({1'b0, py_low4_alpha_s4_w});
    wire signed [18:0] cr_low4_mix_delta_s4_dyn_w =
        cr_low4_delta_s4_w * $signed({1'b0, py_low4_alpha_s4_w});
    wire [7:0] cb_low4_mix_dyn_s4_w =
        clip_u8($signed({1'b0, cb_low2_mix_s4_r}) + ((cb_low4_mix_delta_s4_dyn_w + 19'sd128) >>> 8));
    wire [7:0] cr_low4_mix_dyn_s4_w =
        clip_u8($signed({1'b0, cr_low2_mix_s4_r}) + ((cr_low4_mix_delta_s4_dyn_w + 19'sd128) >>> 8));
    wire [7:0] cb_low4_mix_s4_w =
        STAGE18_PY_TARGET_EN ?
        (black_neutral_gate_s4_r ? cb_low4_mix_dyn_s4_w : cb_low2_mix_s4_r) :
        (black_neutral_gate_s4_r ? clip_u8({{9{cb_low4_sum_s4_w[10]}}, cb_low4_sum_s4_w}) : cb_low2_mix_s4_r);
    wire [7:0] cr_low4_mix_s4_w =
        STAGE18_PY_TARGET_EN ?
        (black_neutral_gate_s4_r ? cr_low4_mix_dyn_s4_w : cr_low2_mix_s4_r) :
        (black_neutral_gate_s4_r ? clip_u8({{9{cr_low4_sum_s4_w[10]}}, cr_low4_sum_s4_w}) : cr_low2_mix_s4_r);

    wire signed [8:0] cb_mix_neutral_delta_s5_w = 9'sd128 - $signed({1'b0, cb_low4_mix_s5_r});
    wire signed [8:0] cr_mix_neutral_delta_s5_w = 9'sd128 - $signed({1'b0, cr_low4_mix_s5_r});
    wire signed [18:0] cb_snap_delta_s5_w =
        cb_mix_neutral_delta_s5_w * $signed({1'b0, FLAT_SNAP_ALPHA_Q8});
    wire signed [18:0] cr_snap_delta_s5_w =
        cr_mix_neutral_delta_s5_w * $signed({1'b0, FLAT_SNAP_ALPHA_Q8});
    wire [7:0] cb_snap_s5_w = clip_u8($signed({1'b0, cb_low4_mix_s5_r}) + ((cb_snap_delta_s5_w + 19'sd128) >>> 8));
    wire [7:0] cr_snap_s5_w = clip_u8($signed({1'b0, cr_low4_mix_s5_r}) + ((cr_snap_delta_s5_w + 19'sd128) >>> 8));
    wire signed [8:0] cb_sat_delta_s5_w = $signed({1'b0, cb_low4_mix_s5_r}) - 9'sd128;
    wire signed [8:0] cr_sat_delta_s5_w = $signed({1'b0, cr_low4_mix_s5_r}) - 9'sd128;
    wire [8:0] cb_sat_abs_s5_w = cb_sat_delta_s5_w[8] ? (~cb_sat_delta_s5_w + 9'd1) : cb_sat_delta_s5_w;
    wire [8:0] cr_sat_abs_s5_w = cr_sat_delta_s5_w[8] ? (~cr_sat_delta_s5_w + 9'd1) : cr_sat_delta_s5_w;
    wire [9:0] chroma_sat_s5_w = {1'b0, cb_sat_abs_s5_w} + {1'b0, cr_sat_abs_s5_w};
    wire [8:0] py_neutral_gate_s5_w =
        clip_q8($signed({1'b0, FLAT_NEUTRAL_TH, 4'b0000}) - $signed({chroma_sat_s5_w, 3'b000}));
    wire [8:0] snap_alpha_s5_w =
        STAGE18_PY_TARGET_EN ?
        min_q8(FLAT_SNAP_ALPHA_Q8, min_q8(py_base_gate_s5_r, py_neutral_gate_s5_w)) :
        FLAT_SNAP_ALPHA_Q8;
    wire snap_gate_s5_w =
        STAGE18_PY_TARGET_EN ?
        (snap_alpha_s5_w != 9'd0) :
        ((FLAT_SNAP_ALPHA_Q8 != 9'd0) && (chroma_sat_s5_w <= {2'b00, FLAT_NEUTRAL_TH}));
    wire signed [18:0] cb_snap_delta_s5_sel_w =
        cb_mix_neutral_delta_s5_w * $signed({1'b0, snap_alpha_s5_w});
    wire signed [18:0] cr_snap_delta_s5_sel_w =
        cr_mix_neutral_delta_s5_w * $signed({1'b0, snap_alpha_s5_w});
    wire [7:0] cb_snap_s5_sel_w =
        clip_u8($signed({1'b0, cb_low4_mix_s5_r}) + ((cb_snap_delta_s5_sel_w + 19'sd128) >>> 8));
    wire [7:0] cr_snap_s5_sel_w =
        clip_u8($signed({1'b0, cr_low4_mix_s5_r}) + ((cr_snap_delta_s5_sel_w + 19'sd128) >>> 8));
    wire [7:0] cb_flat_pre_quant_s5_w =
        snap_gate_s5_w ? (STAGE18_PY_TARGET_EN ? cb_snap_s5_sel_w : cb_snap_s5_w) : cb_low4_mix_s5_r;
    wire [7:0] cr_flat_pre_quant_s5_w =
        snap_gate_s5_w ? (STAGE18_PY_TARGET_EN ? cr_snap_s5_sel_w : cr_snap_s5_w) : cr_low4_mix_s5_r;

    wire [7:0] cb_quant_s6_w = quant_chroma_u8(cb_pre_quant_s6_r);
    wire [7:0] cr_quant_s6_w = quant_chroma_u8(cr_pre_quant_s6_r);
    wire signed [8:0] cb_quant_delta_s6_w =
        $signed({1'b0, cb_quant_s6_w}) - $signed({1'b0, cb_pre_quant_s6_r});
    wire signed [8:0] cr_quant_delta_s6_w =
        $signed({1'b0, cr_quant_s6_w}) - $signed({1'b0, cr_pre_quant_s6_r});
    wire signed [18:0] cb_quant_mix_delta_s6_w =
        cb_quant_delta_s6_w * $signed({1'b0, FLAT_QUANT_ALPHA_Q8});
    wire signed [18:0] cr_quant_mix_delta_s6_w =
        cr_quant_delta_s6_w * $signed({1'b0, FLAT_QUANT_ALPHA_Q8});
    wire signed [8:0] cb_pre_quant_sat_delta_s6_w = $signed({1'b0, cb_pre_quant_s6_r}) - 9'sd128;
    wire signed [8:0] cr_pre_quant_sat_delta_s6_w = $signed({1'b0, cr_pre_quant_s6_r}) - 9'sd128;
    wire [8:0] cb_pre_quant_sat_abs_s6_w =
        cb_pre_quant_sat_delta_s6_w[8] ? (~cb_pre_quant_sat_delta_s6_w + 9'd1) : cb_pre_quant_sat_delta_s6_w;
    wire [8:0] cr_pre_quant_sat_abs_s6_w =
        cr_pre_quant_sat_delta_s6_w[8] ? (~cr_pre_quant_sat_delta_s6_w + 9'd1) : cr_pre_quant_sat_delta_s6_w;
    wire [9:0] chroma_sat_s6_w =
        {1'b0, cb_pre_quant_sat_abs_s6_w} + {1'b0, cr_pre_quant_sat_abs_s6_w};
    wire [8:0] py_neutral_gate_s6_w =
        clip_q8($signed({1'b0, FLAT_NEUTRAL_TH, 4'b0000}) - $signed({chroma_sat_s6_w, 3'b000}));
    wire [8:0] quant_alpha_s6_w =
        STAGE18_PY_TARGET_EN ?
        min_q8(FLAT_QUANT_ALPHA_Q8, min_q8(py_base_gate_s6_r, py_neutral_gate_s6_w)) :
        FLAT_QUANT_ALPHA_Q8;
    wire signed [18:0] cb_quant_mix_delta_s6_sel_w =
        cb_quant_delta_s6_w * $signed({1'b0, quant_alpha_s6_w});
    wire signed [18:0] cr_quant_mix_delta_s6_sel_w =
        cr_quant_delta_s6_w * $signed({1'b0, quant_alpha_s6_w});
    wire [7:0] cb_flat_quant_s6_w =
        black_neutral_gate_s6_r ? clip_u8($signed({1'b0, cb_pre_quant_s6_r}) + (((STAGE18_PY_TARGET_EN ? cb_quant_mix_delta_s6_sel_w : cb_quant_mix_delta_s6_w) + 19'sd128) >>> 8)) : cb_pre_quant_s6_r;
    wire [7:0] cr_flat_quant_s6_w =
        black_neutral_gate_s6_r ? clip_u8($signed({1'b0, cr_pre_quant_s6_r}) + (((STAGE18_PY_TARGET_EN ? cr_quant_mix_delta_s6_sel_w : cr_quant_mix_delta_s6_w) + 19'sd128) >>> 8)) : cr_pre_quant_s6_r;
    wire [7:0] y_out_ycbcr_s6_w =
        STAGE18_PY_TARGET_EN ? y_center_s6_r :
        (native_luma_gate_s6_r ? y_flat_s6_r :
        (flatten_gate_s6_r ? y_flat_s6_r : y_center_s6_r));
    wire [7:0] cb_out_ycbcr_s6_w = flatten_gate_s6_r ? cb_flat_quant_s6_w : cb_center_s6_r;
    wire [7:0] cr_out_ycbcr_s6_w = flatten_gate_s6_r ? cr_flat_quant_s6_w : cr_center_s6_r;

    wire signed [8:0] y_apply_delta_s7_w =
        DIRECT_YCBCR_RGB ? $signed({1'b0, y_out_s7_r}) :
        ($signed({1'b0, y_out_s7_r}) - $signed({1'b0, y_center_s7_r}));
    wire signed [8:0] cb_apply_delta_s7_w =
        DIRECT_YCBCR_RGB ? ($signed({1'b0, cb_out_s7_r}) - 9'sd128) :
        ($signed({1'b0, cb_out_s7_r}) - $signed({1'b0, cb_center_s7_r}));
    wire signed [8:0] cr_apply_delta_s7_w =
        DIRECT_YCBCR_RGB ? ($signed({1'b0, cr_out_s7_r}) - 9'sd128) :
        ($signed({1'b0, cr_out_s7_r}) - $signed({1'b0, cr_center_s7_r}));
    wire signed [18:0] r_term_s7_w    = cr_apply_delta_s7_w * 10'sd359;
    wire signed [18:0] g_cb_term_s7_w = cb_apply_delta_s7_w * 8'sd88;
    wire signed [18:0] g_cr_term_s7_w = cr_apply_delta_s7_w * 9'sd183;
    wire signed [18:0] b_term_s7_w    = cb_apply_delta_s7_w * 10'sd454;

    wire signed [19:0] out_r_base_s8_w = DIRECT_YCBCR_RGB ? 20'sd0 : $signed({1'b0, r_center_s8_r});
    wire signed [19:0] out_g_base_s8_w = DIRECT_YCBCR_RGB ? 20'sd0 : $signed({1'b0, g_center_s8_r});
    wire signed [19:0] out_b_base_s8_w = DIRECT_YCBCR_RGB ? 20'sd0 : $signed({1'b0, b_center_s8_r});
    wire signed [19:0] out_r_sum_s8_w = out_r_base_s8_w + y_apply_delta_s8_r + (r_term_s8_r >>> 8);
    wire signed [19:0] out_g_sum_s8_w = out_g_base_s8_w + y_apply_delta_s8_r - (g_cb_term_s8_r >>> 8) - (g_cr_term_s8_r >>> 8);
    wire signed [19:0] out_b_sum_s8_w = out_b_base_s8_w + y_apply_delta_s8_r + (b_term_s8_r >>> 8);
    wire [7:0] out_r_w = clip_u8(out_r_sum_s9_r);
    wire [7:0] out_g_w = clip_u8(out_g_sum_s9_r);
    wire [7:0] out_b_w = clip_u8(out_b_sum_s9_r);
    wire [23:0] filtered_rgb_s9_w =
        (CHROMA_SMEAR_FLATTEN_EN >= 12) ? stage19_rgb_s9_r : {out_r_w, out_g_w, out_b_w};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            de_s0_r <= 1'b0;
            rgb_s0_r <= 24'd0;
            rgb2ycc_prod_de_r <= 1'b0;
            rgb2ycc_prod_rgb_r <= 24'd0;
            rgb2ycc_r_y_r <= 16'd0;
            rgb2ycc_g_y_r <= 16'd0;
            rgb2ycc_b_y_r <= 16'd0;
            rgb2ycc_r_cb_r <= 16'd0;
            rgb2ycc_g_cb_r <= 16'd0;
            rgb2ycc_b_cb_r <= 16'd0;
            rgb2ycc_r_cr_r <= 16'd0;
            rgb2ycc_g_cr_r <= 16'd0;
            rgb2ycc_b_cr_r <= 16'd0;
            rgb2ycc_de_r <= 1'b0;
            rgb2ycc_rgb_r <= 24'd0;
            rgb2ycc_y_r <= 8'd0;
            rgb2ycc_cb_r <= 8'd0;
            rgb2ycc_cr_r <= 8'd0;
            y_cross_align_de_d1_r <= 1'b0;
            y_cross_align_de_d2_r <= 1'b0;
            y_cross_align_center_d1_r <= 8'd0;
            y_cross_align_center_d2_r <= 8'd0;
            y_cross_align_filtered_d1_r <= 8'd0;
            y_cross_align_filtered_d2_r <= 8'd0;
            rgb_cross_align_de_d1_r <= 1'b0;
            rgb_cross_align_de_d2_r <= 1'b0;
            rgb_cross_align_d1_r <= 24'd0;
            rgb_cross_align_d2_r <= 24'd0;
            cb_de_align_r <= {BILATERAL_EXTRA_LATENCY{1'b0}};
            cr_de_align_r <= {BILATERAL_EXTRA_LATENCY{1'b0}};
            rgb_de_align_r <= {BILATERAL_EXTRA_LATENCY{1'b0}};
            cb_center_align_r <= {(BILATERAL_EXTRA_LATENCY*8){1'b0}};
            cr_center_align_r <= {(BILATERAL_EXTRA_LATENCY*8){1'b0}};
            cb_filtered_align_r <= {(BILATERAL_EXTRA_LATENCY*8){1'b0}};
            cr_filtered_align_r <= {(BILATERAL_EXTRA_LATENCY*8){1'b0}};
            rgb_center_align_r <= {(BILATERAL_EXTRA_LATENCY*24){1'b0}};
            bilat_de_s1_r <= 1'b0;
            y_center_s1_r <= 8'd0;
            y_filtered_s1_r <= 8'd0;
            cb_center_s1_r <= 8'd0;
            cr_center_s1_r <= 8'd0;
            cb_filtered_s1_r <= 8'd0;
            cr_filtered_s1_r <= 8'd0;
            cb_low2_s1_r <= 8'd0;
            cr_low2_s1_r <= 8'd0;
            cb_low4_s1_r <= 8'd0;
            cr_low4_s1_r <= 8'd0;
            flat_support_s1_r <= 8'd0;
            r_center_s1_r <= 8'd0;
            g_center_s1_r <= 8'd0;
            b_center_s1_r <= 8'd0;
            apply_de_s2_r <= 1'b0;
            y_center_s2_r <= 8'd0;
            cb_center_s2_r <= 8'd0;
            cr_center_s2_r <= 8'd0;
            y_flat_s2_r <= 8'd0;
            cb_mix_s2_r <= 8'd0;
            cr_mix_s2_r <= 8'd0;
            cb_low2_s2_r <= 8'd0;
            cr_low2_s2_r <= 8'd0;
            cb_low4_s2_r <= 8'd0;
            cr_low4_s2_r <= 8'd0;
            py_base_gate_s2_r <= 9'd0;
            flatten_gate_s2_r <= 1'b0;
            native_luma_gate_s2_r <= 1'b0;
            r_center_s2_r <= 8'd0;
            g_center_s2_r <= 8'd0;
            b_center_s2_r <= 8'd0;
            stage19_r_s2_r <= 8'd0;
            stage19_g_s2_r <= 8'd0;
            stage19_b_s2_r <= 8'd0;
            stage19_y_s2_r <= 8'd0;
            stage19_rg_diff_s2_r <= 8'd0;
            stage19_b_delta_s2_r <= 8'd0;
            apply_de_s3_r <= 1'b0;
            y_center_s3_r <= 8'd0;
            cb_center_s3_r <= 8'd0;
            cr_center_s3_r <= 8'd0;
            y_flat_s3_r <= 8'd0;
            cb_smear_s3_r <= 8'd0;
            cr_smear_s3_r <= 8'd0;
            cb_low2_s3_r <= 8'd0;
            cr_low2_s3_r <= 8'd0;
            cb_low4_s3_r <= 8'd0;
            cr_low4_s3_r <= 8'd0;
            py_base_gate_s3_r <= 9'd0;
            flatten_gate_s3_r <= 1'b0;
            native_luma_gate_s3_r <= 1'b0;
            r_center_s3_r <= 8'd0;
            g_center_s3_r <= 8'd0;
            b_center_s3_r <= 8'd0;
            stage19_r_s3_r <= 8'd0;
            stage19_g_s3_r <= 8'd0;
            stage19_b_s3_r <= 8'd0;
            stage19_b_delta_s3_r <= 8'd0;
            stage19_alpha_s3_r <= 8'd0;
            apply_de_s4_r <= 1'b0;
            y_center_s4_r <= 8'd0;
            cb_center_s4_r <= 8'd0;
            cr_center_s4_r <= 8'd0;
            y_flat_s4_r <= 8'd0;
            cb_low2_mix_s4_r <= 8'd0;
            cr_low2_mix_s4_r <= 8'd0;
            cb_low4_s4_r <= 8'd0;
            cr_low4_s4_r <= 8'd0;
            py_base_gate_s4_r <= 9'd0;
            flatten_gate_s4_r <= 1'b0;
            native_luma_gate_s4_r <= 1'b0;
            black_neutral_gate_s4_r <= 1'b0;
            r_center_s4_r <= 8'd0;
            g_center_s4_r <= 8'd0;
            b_center_s4_r <= 8'd0;
            stage19_rgb_s4_r <= 24'd0;
            apply_de_s5_r <= 1'b0;
            y_center_s5_r <= 8'd0;
            cb_center_s5_r <= 8'd0;
            cr_center_s5_r <= 8'd0;
            y_flat_s5_r <= 8'd0;
            cb_low4_mix_s5_r <= 8'd0;
            cr_low4_mix_s5_r <= 8'd0;
            py_base_gate_s5_r <= 9'd0;
            flatten_gate_s5_r <= 1'b0;
            native_luma_gate_s5_r <= 1'b0;
            black_neutral_gate_s5_r <= 1'b0;
            r_center_s5_r <= 8'd0;
            g_center_s5_r <= 8'd0;
            b_center_s5_r <= 8'd0;
            stage19_rgb_s5_r <= 24'd0;
            apply_de_s6_r <= 1'b0;
            y_center_s6_r <= 8'd0;
            cb_center_s6_r <= 8'd0;
            cr_center_s6_r <= 8'd0;
            y_flat_s6_r <= 8'd0;
            cb_pre_quant_s6_r <= 8'd0;
            cr_pre_quant_s6_r <= 8'd0;
            py_base_gate_s6_r <= 9'd0;
            flatten_gate_s6_r <= 1'b0;
            native_luma_gate_s6_r <= 1'b0;
            black_neutral_gate_s6_r <= 1'b0;
            r_center_s6_r <= 8'd0;
            g_center_s6_r <= 8'd0;
            b_center_s6_r <= 8'd0;
            stage19_rgb_s6_r <= 24'd0;
            apply_de_s7_r <= 1'b0;
            y_center_s7_r <= 8'd0;
            cb_center_s7_r <= 8'd0;
            cr_center_s7_r <= 8'd0;
            y_out_s7_r <= 8'd0;
            cb_out_s7_r <= 8'd0;
            cr_out_s7_r <= 8'd0;
            r_center_s7_r <= 8'd0;
            g_center_s7_r <= 8'd0;
            b_center_s7_r <= 8'd0;
            stage19_rgb_s7_r <= 24'd0;
            apply_de_s8_r <= 1'b0;
            r_center_s8_r <= 8'd0;
            g_center_s8_r <= 8'd0;
            b_center_s8_r <= 8'd0;
            y_apply_delta_s8_r <= 9'sd0;
            r_term_s8_r <= 19'sd0;
            g_cb_term_s8_r <= 19'sd0;
            g_cr_term_s8_r <= 19'sd0;
            b_term_s8_r <= 19'sd0;
            stage19_rgb_s8_r <= 24'd0;
            apply_de_s9_r <= 1'b0;
            out_r_sum_s9_r <= 20'sd0;
            out_g_sum_s9_r <= 20'sd0;
            out_b_sum_s9_r <= 20'sd0;
            stage19_rgb_s9_r <= 24'd0;
            bypass_rgb_s9_r <= 24'd0;
            apply_de_s10_r <= 1'b0;
            filtered_rgb_s10_r <= 24'd0;
            bypass_rgb_s10_r <= 24'd0;
            out_de_r <= 1'b0;
            out_rgb_r <= 24'd0;
        end else if (frame_clr) begin
            de_s0_r <= 1'b0;
            rgb_s0_r <= 24'd0;
            rgb2ycc_prod_de_r <= 1'b0;
            rgb2ycc_prod_rgb_r <= 24'd0;
            rgb2ycc_r_y_r <= 16'd0;
            rgb2ycc_g_y_r <= 16'd0;
            rgb2ycc_b_y_r <= 16'd0;
            rgb2ycc_r_cb_r <= 16'd0;
            rgb2ycc_g_cb_r <= 16'd0;
            rgb2ycc_b_cb_r <= 16'd0;
            rgb2ycc_r_cr_r <= 16'd0;
            rgb2ycc_g_cr_r <= 16'd0;
            rgb2ycc_b_cr_r <= 16'd0;
            rgb2ycc_de_r <= 1'b0;
            rgb2ycc_rgb_r <= 24'd0;
            rgb2ycc_y_r <= 8'd0;
            rgb2ycc_cb_r <= 8'd0;
            rgb2ycc_cr_r <= 8'd0;
            y_cross_align_de_d1_r <= 1'b0;
            y_cross_align_de_d2_r <= 1'b0;
            y_cross_align_center_d1_r <= 8'd0;
            y_cross_align_center_d2_r <= 8'd0;
            y_cross_align_filtered_d1_r <= 8'd0;
            y_cross_align_filtered_d2_r <= 8'd0;
            rgb_cross_align_de_d1_r <= 1'b0;
            rgb_cross_align_de_d2_r <= 1'b0;
            rgb_cross_align_d1_r <= 24'd0;
            rgb_cross_align_d2_r <= 24'd0;
            cb_de_align_r <= {BILATERAL_EXTRA_LATENCY{1'b0}};
            cr_de_align_r <= {BILATERAL_EXTRA_LATENCY{1'b0}};
            rgb_de_align_r <= {BILATERAL_EXTRA_LATENCY{1'b0}};
            cb_center_align_r <= {(BILATERAL_EXTRA_LATENCY*8){1'b0}};
            cr_center_align_r <= {(BILATERAL_EXTRA_LATENCY*8){1'b0}};
            cb_filtered_align_r <= {(BILATERAL_EXTRA_LATENCY*8){1'b0}};
            cr_filtered_align_r <= {(BILATERAL_EXTRA_LATENCY*8){1'b0}};
            rgb_center_align_r <= {(BILATERAL_EXTRA_LATENCY*24){1'b0}};
            bilat_de_s1_r <= 1'b0;
            y_center_s1_r <= 8'd0;
            y_filtered_s1_r <= 8'd0;
            cb_center_s1_r <= 8'd0;
            cr_center_s1_r <= 8'd0;
            cb_filtered_s1_r <= 8'd0;
            cr_filtered_s1_r <= 8'd0;
            cb_low2_s1_r <= 8'd0;
            cr_low2_s1_r <= 8'd0;
            cb_low4_s1_r <= 8'd0;
            cr_low4_s1_r <= 8'd0;
            flat_support_s1_r <= 8'd0;
            r_center_s1_r <= 8'd0;
            g_center_s1_r <= 8'd0;
            b_center_s1_r <= 8'd0;
            apply_de_s2_r <= 1'b0;
            y_center_s2_r <= 8'd0;
            cb_center_s2_r <= 8'd0;
            cr_center_s2_r <= 8'd0;
            y_flat_s2_r <= 8'd0;
            cb_mix_s2_r <= 8'd0;
            cr_mix_s2_r <= 8'd0;
            cb_low2_s2_r <= 8'd0;
            cr_low2_s2_r <= 8'd0;
            cb_low4_s2_r <= 8'd0;
            cr_low4_s2_r <= 8'd0;
            py_base_gate_s2_r <= 9'd0;
            flatten_gate_s2_r <= 1'b0;
            native_luma_gate_s2_r <= 1'b0;
            r_center_s2_r <= 8'd0;
            g_center_s2_r <= 8'd0;
            b_center_s2_r <= 8'd0;
            stage19_r_s2_r <= 8'd0;
            stage19_g_s2_r <= 8'd0;
            stage19_b_s2_r <= 8'd0;
            stage19_y_s2_r <= 8'd0;
            stage19_rg_diff_s2_r <= 8'd0;
            stage19_b_delta_s2_r <= 8'd0;
            apply_de_s3_r <= 1'b0;
            y_center_s3_r <= 8'd0;
            cb_center_s3_r <= 8'd0;
            cr_center_s3_r <= 8'd0;
            y_flat_s3_r <= 8'd0;
            cb_smear_s3_r <= 8'd0;
            cr_smear_s3_r <= 8'd0;
            cb_low2_s3_r <= 8'd0;
            cr_low2_s3_r <= 8'd0;
            cb_low4_s3_r <= 8'd0;
            cr_low4_s3_r <= 8'd0;
            py_base_gate_s3_r <= 9'd0;
            flatten_gate_s3_r <= 1'b0;
            native_luma_gate_s3_r <= 1'b0;
            r_center_s3_r <= 8'd0;
            g_center_s3_r <= 8'd0;
            b_center_s3_r <= 8'd0;
            stage19_r_s3_r <= 8'd0;
            stage19_g_s3_r <= 8'd0;
            stage19_b_s3_r <= 8'd0;
            stage19_b_delta_s3_r <= 8'd0;
            stage19_alpha_s3_r <= 8'd0;
            apply_de_s4_r <= 1'b0;
            y_center_s4_r <= 8'd0;
            cb_center_s4_r <= 8'd0;
            cr_center_s4_r <= 8'd0;
            y_flat_s4_r <= 8'd0;
            cb_low2_mix_s4_r <= 8'd0;
            cr_low2_mix_s4_r <= 8'd0;
            cb_low4_s4_r <= 8'd0;
            cr_low4_s4_r <= 8'd0;
            py_base_gate_s4_r <= 9'd0;
            flatten_gate_s4_r <= 1'b0;
            native_luma_gate_s4_r <= 1'b0;
            black_neutral_gate_s4_r <= 1'b0;
            r_center_s4_r <= 8'd0;
            g_center_s4_r <= 8'd0;
            b_center_s4_r <= 8'd0;
            stage19_rgb_s4_r <= 24'd0;
            apply_de_s5_r <= 1'b0;
            y_center_s5_r <= 8'd0;
            cb_center_s5_r <= 8'd0;
            cr_center_s5_r <= 8'd0;
            y_flat_s5_r <= 8'd0;
            cb_low4_mix_s5_r <= 8'd0;
            cr_low4_mix_s5_r <= 8'd0;
            py_base_gate_s5_r <= 9'd0;
            flatten_gate_s5_r <= 1'b0;
            native_luma_gate_s5_r <= 1'b0;
            black_neutral_gate_s5_r <= 1'b0;
            r_center_s5_r <= 8'd0;
            g_center_s5_r <= 8'd0;
            b_center_s5_r <= 8'd0;
            stage19_rgb_s5_r <= 24'd0;
            apply_de_s6_r <= 1'b0;
            y_center_s6_r <= 8'd0;
            cb_center_s6_r <= 8'd0;
            cr_center_s6_r <= 8'd0;
            y_flat_s6_r <= 8'd0;
            cb_pre_quant_s6_r <= 8'd0;
            cr_pre_quant_s6_r <= 8'd0;
            py_base_gate_s6_r <= 9'd0;
            flatten_gate_s6_r <= 1'b0;
            native_luma_gate_s6_r <= 1'b0;
            black_neutral_gate_s6_r <= 1'b0;
            r_center_s6_r <= 8'd0;
            g_center_s6_r <= 8'd0;
            b_center_s6_r <= 8'd0;
            stage19_rgb_s6_r <= 24'd0;
            apply_de_s7_r <= 1'b0;
            y_center_s7_r <= 8'd0;
            cb_center_s7_r <= 8'd0;
            cr_center_s7_r <= 8'd0;
            y_out_s7_r <= 8'd0;
            cb_out_s7_r <= 8'd0;
            cr_out_s7_r <= 8'd0;
            r_center_s7_r <= 8'd0;
            g_center_s7_r <= 8'd0;
            b_center_s7_r <= 8'd0;
            stage19_rgb_s7_r <= 24'd0;
            apply_de_s8_r <= 1'b0;
            r_center_s8_r <= 8'd0;
            g_center_s8_r <= 8'd0;
            b_center_s8_r <= 8'd0;
            y_apply_delta_s8_r <= 9'sd0;
            r_term_s8_r <= 19'sd0;
            g_cb_term_s8_r <= 19'sd0;
            g_cr_term_s8_r <= 19'sd0;
            b_term_s8_r <= 19'sd0;
            stage19_rgb_s8_r <= 24'd0;
            apply_de_s9_r <= 1'b0;
            out_r_sum_s9_r <= 20'sd0;
            out_g_sum_s9_r <= 20'sd0;
            out_b_sum_s9_r <= 20'sd0;
            stage19_rgb_s9_r <= 24'd0;
            bypass_rgb_s9_r <= 24'd0;
            apply_de_s10_r <= 1'b0;
            filtered_rgb_s10_r <= 24'd0;
            bypass_rgb_s10_r <= 24'd0;
            out_de_r <= 1'b0;
            out_rgb_r <= 24'd0;
        end else begin
            de_s0_r <= in_de;
            rgb_s0_r <= in_de ? in_rgb : 24'd0;

            rgb2ycc_prod_de_r <= de_s0_r;
            rgb2ycc_prod_rgb_r <= de_s0_r ? rgb_s0_r : 24'd0;
            if (de_s0_r) begin
                rgb2ycc_r_y_r <= r_y_w;
                rgb2ycc_g_y_r <= g_y_w;
                rgb2ycc_b_y_r <= b_y_w;
                rgb2ycc_r_cb_r <= r_cb_w;
                rgb2ycc_g_cb_r <= g_cb_w;
                rgb2ycc_b_cb_r <= b_cb_w;
                rgb2ycc_r_cr_r <= r_cr_w;
                rgb2ycc_g_cr_r <= g_cr_w;
                rgb2ycc_b_cr_r <= b_cr_w;
            end else begin
                rgb2ycc_r_y_r <= 16'd0;
                rgb2ycc_g_y_r <= 16'd0;
                rgb2ycc_b_y_r <= 16'd0;
                rgb2ycc_r_cb_r <= 16'd0;
                rgb2ycc_g_cb_r <= 16'd0;
                rgb2ycc_b_cb_r <= 16'd0;
                rgb2ycc_r_cr_r <= 16'd0;
                rgb2ycc_g_cr_r <= 16'd0;
                rgb2ycc_b_cr_r <= 16'd0;
            end

            rgb2ycc_de_r <= rgb2ycc_prod_de_r;
            rgb2ycc_rgb_r <= rgb2ycc_prod_de_r ? rgb2ycc_prod_rgb_r : 24'd0;
            if (rgb2ycc_prod_de_r) begin
                rgb2ycc_y_r <= rgb2ycc_y_w;
                rgb2ycc_cb_r <= rgb2ycc_cb_w;
                rgb2ycc_cr_r <= rgb2ycc_cr_w;
            end else begin
                rgb2ycc_y_r <= 8'd0;
                rgb2ycc_cb_r <= 8'd0;
                rgb2ycc_cr_r <= 8'd0;
            end

            y_cross_align_de_d1_r <= y_de_w;
            y_cross_align_de_d2_r <= y_cross_align_de_d1_r;
            y_cross_align_center_d1_r <= y_de_w ? y_center_w : 8'd0;
            y_cross_align_center_d2_r <= y_cross_align_de_d1_r ? y_cross_align_center_d1_r : 8'd0;
            y_cross_align_filtered_d1_r <= y_de_w ? y_filtered_w : 8'd0;
            y_cross_align_filtered_d2_r <= y_cross_align_de_d1_r ? y_cross_align_filtered_d1_r : 8'd0;
            rgb_cross_align_de_d1_r <= rgb_de_w;
            rgb_cross_align_de_d2_r <= rgb_cross_align_de_d1_r;
            rgb_cross_align_d1_r <= rgb_de_w ? rgb_center_w : 24'd0;
            rgb_cross_align_d2_r <= rgb_cross_align_de_d1_r ? rgb_cross_align_d1_r : 24'd0;
            cb_de_align_r <= {cb_de_align_r[BILATERAL_EXTRA_LATENCY-2:0], cb_de_w};
            cr_de_align_r <= {cr_de_align_r[BILATERAL_EXTRA_LATENCY-2:0], cr_de_w};
            rgb_de_align_r <= {rgb_de_align_r[BILATERAL_EXTRA_LATENCY-2:0], rgb_de_w};
            cb_center_align_r <= {cb_center_align_r[(BILATERAL_EXTRA_LATENCY-1)*8-1:0],
                                  (cb_de_w ? cb_center_w : 8'd0)};
            cr_center_align_r <= {cr_center_align_r[(BILATERAL_EXTRA_LATENCY-1)*8-1:0],
                                  (cr_de_w ? cr_center_w : 8'd0)};
            cb_filtered_align_r <= {cb_filtered_align_r[(BILATERAL_EXTRA_LATENCY-1)*8-1:0],
                                    (cb_de_w ? cb_filtered_w : 8'd0)};
            cr_filtered_align_r <= {cr_filtered_align_r[(BILATERAL_EXTRA_LATENCY-1)*8-1:0],
                                    (cr_de_w ? cr_filtered_w : 8'd0)};
            rgb_center_align_r <= {rgb_center_align_r[(BILATERAL_EXTRA_LATENCY-1)*24-1:0],
                                   (rgb_de_w ? rgb_center_w : 24'd0)};

            bilat_de_s1_r <= bilat_de_w;
            if (bilat_de_w) begin
                y_center_s1_r <= y_center_dly_w;
                y_filtered_s1_r <= y_filtered_dly_w;
                cb_center_s1_r <= cb_center_dly_w;
                cr_center_s1_r <= cr_center_dly_w;
                cb_filtered_s1_r <= cb_filtered_dly_w;
                cr_filtered_s1_r <= cr_filtered_dly_w;
                cb_low2_s1_r <= cb_low2_w;
                cr_low2_s1_r <= cr_low2_w;
                cb_low4_s1_r <= cb_low4_w;
                cr_low4_s1_r <= cr_low4_w;
                flat_support_s1_r <= (STAGE17_ARCH_TARGET_EN || STAGE18_PY_TARGET_EN) ? flat_support_w : 8'd255;
                r_center_s1_r <= r_center_dly_w;
                g_center_s1_r <= g_center_dly_w;
                b_center_s1_r <= b_center_dly_w;
            end else begin
                y_center_s1_r <= 8'd0;
                y_filtered_s1_r <= 8'd0;
                cb_center_s1_r <= 8'd0;
                cr_center_s1_r <= 8'd0;
                cb_filtered_s1_r <= 8'd0;
                cr_filtered_s1_r <= 8'd0;
                cb_low2_s1_r <= 8'd0;
                cr_low2_s1_r <= 8'd0;
                cb_low4_s1_r <= 8'd0;
                cr_low4_s1_r <= 8'd0;
                flat_support_s1_r <= 8'd0;
                r_center_s1_r <= 8'd0;
                g_center_s1_r <= 8'd0;
                b_center_s1_r <= 8'd0;
            end

            apply_de_s2_r <= bilat_de_s1_r;
            if (bilat_de_s1_r) begin
                y_center_s2_r <= y_center_s1_r;
                cb_center_s2_r <= cb_center_s1_r;
                cr_center_s2_r <= cr_center_s1_r;
                y_flat_s2_r <= y_flat_s1_w;
                cb_mix_s2_r <= cb_mix_s1_w;
                cr_mix_s2_r <= cr_mix_s1_w;
                cb_low2_s2_r <= cb_low2_s1_r;
                cr_low2_s2_r <= cr_low2_s1_r;
                cb_low4_s2_r <= cb_low4_s1_r;
                cr_low4_s2_r <= cr_low4_s1_r;
                py_base_gate_s2_r <= py_base_gate_s1_w;
                flatten_gate_s2_r <= flatten_gate_s1_w;
                native_luma_gate_s2_r <= native_luma_gate_s1_w;
                r_center_s2_r <= r_center_s1_r;
                g_center_s2_r <= g_center_s1_r;
                b_center_s2_r <= b_center_s1_r;
                stage19_r_s2_r <= r_center_s1_r;
                stage19_g_s2_r <= g_center_s1_r;
                stage19_b_s2_r <= b_center_s1_r;
                stage19_y_s2_r <= y_center_s1_r;
                stage19_rg_diff_s2_r <= stage19_rg_diff_s1_w;
                stage19_b_delta_s2_r <= stage19_b_delta_s1_w;
            end else begin
                y_center_s2_r <= 8'd0;
                cb_center_s2_r <= 8'd0;
                cr_center_s2_r <= 8'd0;
                y_flat_s2_r <= 8'd0;
                cb_mix_s2_r <= 8'd0;
                cr_mix_s2_r <= 8'd0;
                cb_low2_s2_r <= 8'd0;
                cr_low2_s2_r <= 8'd0;
                cb_low4_s2_r <= 8'd0;
                cr_low4_s2_r <= 8'd0;
                py_base_gate_s2_r <= 9'd0;
                flatten_gate_s2_r <= 1'b0;
                native_luma_gate_s2_r <= 1'b0;
                r_center_s2_r <= 8'd0;
                g_center_s2_r <= 8'd0;
                b_center_s2_r <= 8'd0;
                stage19_r_s2_r <= 8'd0;
                stage19_g_s2_r <= 8'd0;
                stage19_b_s2_r <= 8'd0;
                stage19_y_s2_r <= 8'd0;
                stage19_rg_diff_s2_r <= 8'd0;
                stage19_b_delta_s2_r <= 8'd0;
            end

            apply_de_s3_r <= apply_de_s2_r;
            if (apply_de_s2_r) begin
                y_center_s3_r <= y_center_s2_r;
                cb_center_s3_r <= cb_center_s2_r;
                cr_center_s3_r <= cr_center_s2_r;
                y_flat_s3_r <= y_flat_s2_r;
                cb_smear_s3_r <= cb_smear_mix_s2_w;
                cr_smear_s3_r <= cr_smear_mix_s2_w;
                cb_low2_s3_r <= cb_low2_s2_r;
                cr_low2_s3_r <= cr_low2_s2_r;
                cb_low4_s3_r <= cb_low4_s2_r;
                cr_low4_s3_r <= cr_low4_s2_r;
                py_base_gate_s3_r <= py_base_gate_s2_r;
                flatten_gate_s3_r <= flatten_gate_s2_r;
                native_luma_gate_s3_r <= native_luma_gate_s2_r;
                r_center_s3_r <= r_center_s2_r;
                g_center_s3_r <= g_center_s2_r;
                b_center_s3_r <= b_center_s2_r;
                stage19_r_s3_r <= stage19_r_s2_r;
                stage19_g_s3_r <= stage19_g_s2_r;
                stage19_b_s3_r <= stage19_b_s2_r;
                stage19_b_delta_s3_r <= stage19_b_delta_s2_r;
                stage19_alpha_s3_r <= stage19_alpha_s2_w;
            end else begin
                y_center_s3_r <= 8'd0;
                cb_center_s3_r <= 8'd0;
                cr_center_s3_r <= 8'd0;
                y_flat_s3_r <= 8'd0;
                cb_smear_s3_r <= 8'd0;
                cr_smear_s3_r <= 8'd0;
                cb_low2_s3_r <= 8'd0;
                cr_low2_s3_r <= 8'd0;
                cb_low4_s3_r <= 8'd0;
                cr_low4_s3_r <= 8'd0;
                py_base_gate_s3_r <= 9'd0;
                flatten_gate_s3_r <= 1'b0;
                native_luma_gate_s3_r <= 1'b0;
                r_center_s3_r <= 8'd0;
                g_center_s3_r <= 8'd0;
                b_center_s3_r <= 8'd0;
                stage19_r_s3_r <= 8'd0;
                stage19_g_s3_r <= 8'd0;
                stage19_b_s3_r <= 8'd0;
                stage19_b_delta_s3_r <= 8'd0;
                stage19_alpha_s3_r <= 8'd0;
            end

            apply_de_s4_r <= apply_de_s3_r;
            if (apply_de_s3_r) begin
                y_center_s4_r <= y_center_s3_r;
                cb_center_s4_r <= cb_center_s3_r;
                cr_center_s4_r <= cr_center_s3_r;
                y_flat_s4_r <= y_flat_s3_r;
                cb_low2_mix_s4_r <= cb_low2_mix_s3_w;
                cr_low2_mix_s4_r <= cr_low2_mix_s3_w;
                cb_low4_s4_r <= cb_low4_s3_r;
                cr_low4_s4_r <= cr_low4_s3_r;
                py_base_gate_s4_r <= py_base_gate_s3_r;
                flatten_gate_s4_r <= flatten_gate_s3_r;
                native_luma_gate_s4_r <= native_luma_gate_s3_r;
                black_neutral_gate_s4_r <= black_neutral_gate_s3_w;
                r_center_s4_r <= r_center_s3_r;
                g_center_s4_r <= g_center_s3_r;
                b_center_s4_r <= b_center_s3_r;
                stage19_rgb_s4_r <= {stage19_r_s3_r, stage19_g_s3_r, stage19_b_out_s3_w};
            end else begin
                y_center_s4_r <= 8'd0;
                cb_center_s4_r <= 8'd0;
                cr_center_s4_r <= 8'd0;
                y_flat_s4_r <= 8'd0;
                cb_low2_mix_s4_r <= 8'd0;
                cr_low2_mix_s4_r <= 8'd0;
                cb_low4_s4_r <= 8'd0;
                cr_low4_s4_r <= 8'd0;
                py_base_gate_s4_r <= 9'd0;
                flatten_gate_s4_r <= 1'b0;
                native_luma_gate_s4_r <= 1'b0;
                black_neutral_gate_s4_r <= 1'b0;
                r_center_s4_r <= 8'd0;
                g_center_s4_r <= 8'd0;
                b_center_s4_r <= 8'd0;
                stage19_rgb_s4_r <= 24'd0;
            end

            apply_de_s5_r <= apply_de_s4_r;
            if (apply_de_s4_r) begin
                y_center_s5_r <= y_center_s4_r;
                cb_center_s5_r <= cb_center_s4_r;
                cr_center_s5_r <= cr_center_s4_r;
                y_flat_s5_r <= y_flat_s4_r;
                cb_low4_mix_s5_r <= cb_low4_mix_s4_w;
                cr_low4_mix_s5_r <= cr_low4_mix_s4_w;
                py_base_gate_s5_r <= py_base_gate_s4_r;
                flatten_gate_s5_r <= flatten_gate_s4_r;
                native_luma_gate_s5_r <= native_luma_gate_s4_r;
                black_neutral_gate_s5_r <= black_neutral_gate_s4_r;
                r_center_s5_r <= r_center_s4_r;
                g_center_s5_r <= g_center_s4_r;
                b_center_s5_r <= b_center_s4_r;
                stage19_rgb_s5_r <= stage19_rgb_s4_r;
            end else begin
                y_center_s5_r <= 8'd0;
                cb_center_s5_r <= 8'd0;
                cr_center_s5_r <= 8'd0;
                y_flat_s5_r <= 8'd0;
                cb_low4_mix_s5_r <= 8'd0;
                cr_low4_mix_s5_r <= 8'd0;
                py_base_gate_s5_r <= 9'd0;
                flatten_gate_s5_r <= 1'b0;
                native_luma_gate_s5_r <= 1'b0;
                black_neutral_gate_s5_r <= 1'b0;
                r_center_s5_r <= 8'd0;
                g_center_s5_r <= 8'd0;
                b_center_s5_r <= 8'd0;
                stage19_rgb_s5_r <= 24'd0;
            end

            apply_de_s6_r <= apply_de_s5_r;
            if (apply_de_s5_r) begin
                y_center_s6_r <= y_center_s5_r;
                cb_center_s6_r <= cb_center_s5_r;
                cr_center_s6_r <= cr_center_s5_r;
                y_flat_s6_r <= y_flat_s5_r;
                cb_pre_quant_s6_r <= cb_flat_pre_quant_s5_w;
                cr_pre_quant_s6_r <= cr_flat_pre_quant_s5_w;
                py_base_gate_s6_r <= py_base_gate_s5_r;
                flatten_gate_s6_r <= flatten_gate_s5_r;
                native_luma_gate_s6_r <= native_luma_gate_s5_r;
                black_neutral_gate_s6_r <= black_neutral_gate_s5_r;
                r_center_s6_r <= r_center_s5_r;
                g_center_s6_r <= g_center_s5_r;
                b_center_s6_r <= b_center_s5_r;
                stage19_rgb_s6_r <= stage19_rgb_s5_r;
            end else begin
                y_center_s6_r <= 8'd0;
                cb_center_s6_r <= 8'd0;
                cr_center_s6_r <= 8'd0;
                y_flat_s6_r <= 8'd0;
                cb_pre_quant_s6_r <= 8'd0;
                cr_pre_quant_s6_r <= 8'd0;
                py_base_gate_s6_r <= 9'd0;
                flatten_gate_s6_r <= 1'b0;
                native_luma_gate_s6_r <= 1'b0;
                black_neutral_gate_s6_r <= 1'b0;
                r_center_s6_r <= 8'd0;
                g_center_s6_r <= 8'd0;
                b_center_s6_r <= 8'd0;
                stage19_rgb_s6_r <= 24'd0;
            end

            apply_de_s7_r <= apply_de_s6_r;
            if (apply_de_s6_r) begin
                y_center_s7_r <= y_center_s6_r;
                cb_center_s7_r <= cb_center_s6_r;
                cr_center_s7_r <= cr_center_s6_r;
                y_out_s7_r <= y_out_ycbcr_s6_w;
                cb_out_s7_r <= cb_out_ycbcr_s6_w;
                cr_out_s7_r <= cr_out_ycbcr_s6_w;
                r_center_s7_r <= r_center_s6_r;
                g_center_s7_r <= g_center_s6_r;
                b_center_s7_r <= b_center_s6_r;
                stage19_rgb_s7_r <= stage19_rgb_s6_r;
            end else begin
                y_center_s7_r <= 8'd0;
                cb_center_s7_r <= 8'd0;
                cr_center_s7_r <= 8'd0;
                y_out_s7_r <= 8'd0;
                cb_out_s7_r <= 8'd0;
                cr_out_s7_r <= 8'd0;
                r_center_s7_r <= 8'd0;
                g_center_s7_r <= 8'd0;
                b_center_s7_r <= 8'd0;
                stage19_rgb_s7_r <= 24'd0;
            end

            apply_de_s8_r <= apply_de_s7_r;
            if (apply_de_s7_r) begin
                r_center_s8_r <= r_center_s7_r;
                g_center_s8_r <= g_center_s7_r;
                b_center_s8_r <= b_center_s7_r;
                y_apply_delta_s8_r <= y_apply_delta_s7_w;
                r_term_s8_r <= r_term_s7_w;
                g_cb_term_s8_r <= g_cb_term_s7_w;
                g_cr_term_s8_r <= g_cr_term_s7_w;
                b_term_s8_r <= b_term_s7_w;
                stage19_rgb_s8_r <= stage19_rgb_s7_r;
            end else begin
                r_center_s8_r <= 8'd0;
                g_center_s8_r <= 8'd0;
                b_center_s8_r <= 8'd0;
                y_apply_delta_s8_r <= 9'sd0;
                r_term_s8_r <= 19'sd0;
                g_cb_term_s8_r <= 19'sd0;
                g_cr_term_s8_r <= 19'sd0;
                b_term_s8_r <= 19'sd0;
                stage19_rgb_s8_r <= 24'd0;
            end

            apply_de_s9_r <= apply_de_s8_r;
            if (apply_de_s8_r) begin
                out_r_sum_s9_r <= out_r_sum_s8_w;
                out_g_sum_s9_r <= out_g_sum_s8_w;
                out_b_sum_s9_r <= out_b_sum_s8_w;
                stage19_rgb_s9_r <= stage19_rgb_s8_r;
                bypass_rgb_s9_r <= {r_center_s8_r, g_center_s8_r, b_center_s8_r};
            end else begin
                out_r_sum_s9_r <= 20'sd0;
                out_g_sum_s9_r <= 20'sd0;
                out_b_sum_s9_r <= 20'sd0;
                stage19_rgb_s9_r <= 24'd0;
                bypass_rgb_s9_r <= 24'd0;
            end

            apply_de_s10_r <= apply_de_s9_r;
            if (apply_de_s9_r) begin
                filtered_rgb_s10_r <= filtered_rgb_s9_w;
                bypass_rgb_s10_r <= bypass_rgb_s9_r;
            end else begin
                filtered_rgb_s10_r <= 24'd0;
                bypass_rgb_s10_r <= 24'd0;
            end

            out_de_r <= apply_de_s10_r;
            if (apply_de_s10_r) begin
                out_rgb_r <= runtime_bypass_en_w ? bypass_rgb_s10_r : filtered_rgb_s10_r;
            end else begin
                out_rgb_r <= 24'd0;
            end
        end
    end

    assign out_de  = out_de_r;
    assign out_rgb = out_rgb_r;

endmodule
