module rgb_flat_chroma_denoise_3x3
#(
    parameter H_DISP = 1280,
    parameter V_DISP = 720,
    parameter ENABLE = 1,
    parameter [7:0] Y_RANGE_TH = 8'd20,
    parameter [7:0] CHROMA_RANGE_TH = 8'd64,
    parameter [8:0] ALPHA_Q8 = 9'd224,
    parameter [7:0] DELTA_CLAMP = 8'd10,
    parameter EDGE_GUARD_ENABLE = 1,
    parameter [7:0] EDGE_GUARD_SAT_TH = 8'd36,
    parameter [7:0] EDGE_GUARD_Y_NEIGHBOR_SPREAD_MIN = 8'd8,
    parameter IMPULSE_ENABLE = 1,
    parameter [7:0] IMPULSE_NEIGHBOR_Y_RANGE_TH = 8'd8,
    parameter [7:0] IMPULSE_DELTA_MIN = 8'd6,
    parameter [7:0] IMPULSE_DELTA_MAX = 8'd32,
    parameter [8:0] IMPULSE_ALPHA_Q8 = 9'd192,
    parameter [7:0] GREEN_IMPULSE_DELTA_MIN = 8'd6,
    parameter [7:0] GREEN_IMPULSE_NEIGHBOR_RANGE_TH = 8'd48,
    parameter [7:0] GREEN_EXCESS_DELTA_MIN = 8'd18,
    parameter [10:0] STARTUP_BYPASS_LEFT_PX = 11'd13,
    parameter [10:0] STARTUP_BYPASS_TOP_PX = 11'd11
)
(
    input   wire            clk,
    input   wire            rst_n,
    input   wire            frame_clr,
    input   wire            in_de,
    input   wire    [23:0]  in_rgb,

    output  wire            out_de,
    output  wire    [23:0]  out_rgb
);

wire        pass1_de_w;
wire [23:0] pass1_rgb_w;
wire        pass2_de_w;
wire [23:0] pass2_rgb_w;

rgb_flat_chroma_denoise_3x3_pass
#(
    .H_DISP(H_DISP),
    .V_DISP(V_DISP),
    .ENABLE(ENABLE),
    .Y_RANGE_TH(Y_RANGE_TH),
    .CHROMA_RANGE_TH(CHROMA_RANGE_TH),
    .ALPHA_Q8(ALPHA_Q8),
    .DELTA_CLAMP(DELTA_CLAMP),
    .EDGE_GUARD_ENABLE(EDGE_GUARD_ENABLE),
    .EDGE_GUARD_SAT_TH(EDGE_GUARD_SAT_TH),
    .EDGE_GUARD_Y_NEIGHBOR_SPREAD_MIN(EDGE_GUARD_Y_NEIGHBOR_SPREAD_MIN),
    .IMPULSE_ENABLE(IMPULSE_ENABLE),
    .IMPULSE_NEIGHBOR_Y_RANGE_TH(IMPULSE_NEIGHBOR_Y_RANGE_TH),
    .IMPULSE_DELTA_MIN(IMPULSE_DELTA_MIN),
    .IMPULSE_DELTA_MAX(IMPULSE_DELTA_MAX),
    .IMPULSE_ALPHA_Q8(IMPULSE_ALPHA_Q8),
    .GREEN_IMPULSE_DELTA_MIN(GREEN_IMPULSE_DELTA_MIN),
    .GREEN_IMPULSE_NEIGHBOR_RANGE_TH(GREEN_IMPULSE_NEIGHBOR_RANGE_TH),
    .GREEN_EXCESS_DELTA_MIN(GREEN_EXCESS_DELTA_MIN),
    .STARTUP_BYPASS_LEFT_PX(STARTUP_BYPASS_LEFT_PX),
    .STARTUP_BYPASS_TOP_PX(STARTUP_BYPASS_TOP_PX)
)
u_pass1
(
    .clk      (clk),
    .rst_n    (rst_n),
    .frame_clr(frame_clr),
    .in_de    (in_de),
    .in_rgb   (in_rgb),
    .out_de   (pass1_de_w),
    .out_rgb  (pass1_rgb_w)
);

rgb_flat_chroma_denoise_3x3_pass
#(
    .H_DISP(H_DISP),
    .V_DISP(V_DISP),
    .ENABLE(ENABLE),
    .Y_RANGE_TH(Y_RANGE_TH),
    .CHROMA_RANGE_TH(CHROMA_RANGE_TH),
    .ALPHA_Q8(ALPHA_Q8),
    .DELTA_CLAMP(DELTA_CLAMP),
    .EDGE_GUARD_ENABLE(EDGE_GUARD_ENABLE),
    .EDGE_GUARD_SAT_TH(EDGE_GUARD_SAT_TH),
    .EDGE_GUARD_Y_NEIGHBOR_SPREAD_MIN(EDGE_GUARD_Y_NEIGHBOR_SPREAD_MIN),
    .IMPULSE_ENABLE(IMPULSE_ENABLE),
    .IMPULSE_NEIGHBOR_Y_RANGE_TH(IMPULSE_NEIGHBOR_Y_RANGE_TH),
    .IMPULSE_DELTA_MIN(IMPULSE_DELTA_MIN),
    .IMPULSE_DELTA_MAX(IMPULSE_DELTA_MAX),
    .IMPULSE_ALPHA_Q8(IMPULSE_ALPHA_Q8),
    .GREEN_IMPULSE_DELTA_MIN(GREEN_IMPULSE_DELTA_MIN),
    .GREEN_IMPULSE_NEIGHBOR_RANGE_TH(GREEN_IMPULSE_NEIGHBOR_RANGE_TH),
    .GREEN_EXCESS_DELTA_MIN(GREEN_EXCESS_DELTA_MIN),
    .STARTUP_BYPASS_LEFT_PX(STARTUP_BYPASS_LEFT_PX),
    .STARTUP_BYPASS_TOP_PX(STARTUP_BYPASS_TOP_PX)
)
u_pass2
(
    .clk      (clk),
    .rst_n    (rst_n),
    .frame_clr(frame_clr),
    .in_de    (pass1_de_w),
    .in_rgb   (pass1_rgb_w),
    .out_de   (pass2_de_w),
    .out_rgb  (pass2_rgb_w)
);

rgb_flat_chroma_denoise_3x3_pass
#(
    .H_DISP(H_DISP),
    .V_DISP(V_DISP),
    .ENABLE(ENABLE),
    .Y_RANGE_TH(Y_RANGE_TH),
    .CHROMA_RANGE_TH(CHROMA_RANGE_TH),
    .ALPHA_Q8(ALPHA_Q8),
    .DELTA_CLAMP(DELTA_CLAMP),
    .EDGE_GUARD_ENABLE(EDGE_GUARD_ENABLE),
    .EDGE_GUARD_SAT_TH(EDGE_GUARD_SAT_TH),
    .EDGE_GUARD_Y_NEIGHBOR_SPREAD_MIN(EDGE_GUARD_Y_NEIGHBOR_SPREAD_MIN),
    .IMPULSE_ENABLE(IMPULSE_ENABLE),
    .IMPULSE_NEIGHBOR_Y_RANGE_TH(IMPULSE_NEIGHBOR_Y_RANGE_TH),
    .IMPULSE_DELTA_MIN(IMPULSE_DELTA_MIN),
    .IMPULSE_DELTA_MAX(IMPULSE_DELTA_MAX),
    .IMPULSE_ALPHA_Q8(IMPULSE_ALPHA_Q8),
    .GREEN_IMPULSE_DELTA_MIN(GREEN_IMPULSE_DELTA_MIN),
    .GREEN_IMPULSE_NEIGHBOR_RANGE_TH(GREEN_IMPULSE_NEIGHBOR_RANGE_TH),
    .GREEN_EXCESS_DELTA_MIN(GREEN_EXCESS_DELTA_MIN),
    .STARTUP_BYPASS_LEFT_PX(STARTUP_BYPASS_LEFT_PX),
    .STARTUP_BYPASS_TOP_PX(STARTUP_BYPASS_TOP_PX)
)
u_pass3
(
    .clk      (clk),
    .rst_n    (rst_n),
    .frame_clr(frame_clr),
    .in_de    (pass2_de_w),
    .in_rgb   (pass2_rgb_w),
    .out_de   (out_de),
    .out_rgb  (out_rgb)
);

endmodule

module rgb_flat_chroma_denoise_3x3_pass
#(
    parameter H_DISP = 1280,
    parameter V_DISP = 720,
    parameter ENABLE = 1,
    parameter [7:0] Y_RANGE_TH = 8'd20,
    parameter [7:0] CHROMA_RANGE_TH = 8'd48,
    parameter [8:0] ALPHA_Q8 = 9'd192,
    parameter [7:0] DELTA_CLAMP = 8'd8,
    parameter EDGE_GUARD_ENABLE = 1,
    parameter [7:0] EDGE_GUARD_SAT_TH = 8'd36,
    parameter [7:0] EDGE_GUARD_Y_NEIGHBOR_SPREAD_MIN = 8'd8,
    parameter IMPULSE_ENABLE = 1,
    parameter [7:0] IMPULSE_NEIGHBOR_Y_RANGE_TH = 8'd8,
    parameter [7:0] IMPULSE_DELTA_MIN = 8'd6,
    parameter [7:0] IMPULSE_DELTA_MAX = 8'd32,
    parameter [8:0] IMPULSE_ALPHA_Q8 = 9'd192,
    parameter [7:0] GREEN_IMPULSE_DELTA_MIN = 8'd6,
    parameter [7:0] GREEN_IMPULSE_NEIGHBOR_RANGE_TH = 8'd48,
    parameter [7:0] GREEN_EXCESS_DELTA_MIN = 8'd18,
    parameter [10:0] STARTUP_BYPASS_LEFT_PX = 11'd13,
    parameter [10:0] STARTUP_BYPASS_TOP_PX = 11'd11
)
(
    input   wire            clk,
    input   wire            rst_n,
    input   wire            frame_clr,
    input   wire            in_de,
    input   wire    [23:0]  in_rgb,

    output  reg             out_de,
    output  reg     [23:0]  out_rgb
);

function [7:0] clip_u8;
    input signed [13:0] value;
    begin
        if (value < 14'sd0)
            clip_u8 = 8'd0;
        else if (value > 14'sd255)
            clip_u8 = 8'd255;
        else
            clip_u8 = value[7:0];
    end
endfunction

function [7:0] max3_u8;
    input [7:0] a;
    input [7:0] b;
    input [7:0] c;
    reg [7:0] ab;
    begin
        ab = (a >= b) ? a : b;
        max3_u8 = (ab >= c) ? ab : c;
    end
endfunction

function [7:0] min3_u8;
    input [7:0] a;
    input [7:0] b;
    input [7:0] c;
    reg [7:0] ab;
    begin
        ab = (a <= b) ? a : b;
        min3_u8 = (ab <= c) ? ab : c;
    end
endfunction

function signed [8:0] clamp_signed9;
    input signed [8:0] value;
    input [7:0] limit;
    begin
        if (value < -$signed({1'b0, limit}))
            clamp_signed9 = -$signed({1'b0, limit});
        else if (value > $signed({1'b0, limit}))
            clamp_signed9 = $signed({1'b0, limit});
        else
            clamp_signed9 = value;
    end
endfunction

function [8:0] abs_signed9;
    input signed [8:0] value;
    begin
        abs_signed9 = value < 9'sd0 ? -value : value;
    end
endfunction

wire [7:0] in_r_w = in_rgb[23:16];
wire [7:0] in_g_w = in_rgb[15:8];
wire [7:0] in_b_w = in_rgb[7:0];

wire [15:0] in_r_y_w = in_r_w * 8'd77;
wire [15:0] in_g_y_w = in_g_w * 8'd150;
wire [15:0] in_b_y_w = in_b_w * 8'd29;
wire [15:0] in_r_cb_w = in_r_w * 8'd43;
wire [15:0] in_g_cb_w = in_g_w * 8'd85;
wire [15:0] in_b_cb_w = in_b_w << 7;
wire [15:0] in_r_cr_w = in_r_w << 7;
wire [15:0] in_g_cr_w = in_g_w * 8'd107;
wire [15:0] in_b_cr_w = in_b_w * 8'd21;

reg        yc0_de_r;
reg [7:0]  yc0_r_r;
reg [7:0]  yc0_g_r;
reg [7:0]  yc0_b_r;
reg [15:0] yc0_r_y_r;
reg [15:0] yc0_g_y_r;
reg [15:0] yc0_b_y_r;
reg [15:0] yc0_r_cb_r;
reg [15:0] yc0_g_cb_r;
reg [15:0] yc0_b_cb_r;
reg [15:0] yc0_r_cr_r;
reg [15:0] yc0_g_cr_r;
reg [15:0] yc0_b_cr_r;

wire [16:0] y_acc_w =
    {1'b0, yc0_r_y_r} +
    {1'b0, yc0_g_y_r} +
    {1'b0, yc0_b_y_r} +
    17'd128;
wire signed [17:0] cb_acc_w =
    -$signed({2'b00, yc0_r_cb_r}) -
    $signed({2'b00, yc0_g_cb_r}) +
    $signed({2'b00, yc0_b_cb_r}) +
    18'sd128;
wire signed [17:0] cr_acc_w =
    $signed({2'b00, yc0_r_cr_r}) -
    $signed({2'b00, yc0_g_cr_r}) -
    $signed({2'b00, yc0_b_cr_r}) +
    18'sd128;

reg        s0_de_r;
reg [7:0]  s0_r_r;
reg [7:0]  s0_g_r;
reg [7:0]  s0_b_r;
reg [7:0]  s0_y_r;
reg [7:0]  s0_cb_r;
reg [7:0]  s0_cr_r;

wire        y_de_w;
wire [7:0]  y_center_w;
wire [7:0]  y_filtered_w;
wire [7:0]  y_spread_w;
wire [7:0]  y_neighbor_mean_w;
wire [7:0]  y_neighbor_spread_w;
wire [10:0] y_x_w;
wire [10:0] y_y_w;

wire        cb_de_w;
wire [7:0]  cb_center_w;
wire [7:0]  cb_filtered_w;
wire [7:0]  cb_spread_w;

wire        cr_de_w;
wire [7:0]  cr_center_w;
wire [7:0]  cr_filtered_w;
wire [7:0]  cr_spread_w;

wire        r_de_w;
wire [7:0]  r_center_w;
wire [7:0]  r_neighbor_mean_w;
wire [7:0]  r_neighbor_spread_w;

wire        g_de_w;
wire [7:0]  g_center_w;
wire [7:0]  g_neighbor_mean_w;
wire [7:0]  g_neighbor_spread_w;

wire        b_de_w;
wire [7:0]  b_center_w;
wire [7:0]  b_neighbor_mean_w;
wire [7:0]  b_neighbor_spread_w;

wire stats_de_w = y_de_w && cb_de_w && cr_de_w && r_de_w && g_de_w && b_de_w;

reg        g0_de_r;
reg [7:0]  g0_y_center_r;
reg [7:0]  g0_y_spread_r;
reg [7:0]  g0_y_neighbor_mean_r;
reg [7:0]  g0_y_neighbor_spread_r;
reg [7:0]  g0_cb_center_r;
reg [7:0]  g0_cb_filtered_r;
reg [7:0]  g0_cb_spread_r;
reg [7:0]  g0_cr_center_r;
reg [7:0]  g0_cr_filtered_r;
reg [7:0]  g0_cr_spread_r;
reg [7:0]  g0_r_center_r;
reg [7:0]  g0_g_center_r;
reg [7:0]  g0_b_center_r;
reg [7:0]  g0_r_neighbor_mean_r;
reg [7:0]  g0_g_neighbor_mean_r;
reg [7:0]  g0_b_neighbor_mean_r;
reg [7:0]  g0_r_neighbor_spread_r;
reg [7:0]  g0_g_neighbor_spread_r;
reg [7:0]  g0_b_neighbor_spread_r;
reg [10:0] g0_x_r;
reg [10:0] g0_y_r;

wire [7:0] g0_center_max_w = max3_u8(g0_r_center_r, g0_g_center_r, g0_b_center_r);
wire [7:0] g0_center_min_w = min3_u8(g0_r_center_r, g0_g_center_r, g0_b_center_r);
wire signed [8:0] g0_dcb_raw_w = $signed({1'b0, g0_cb_filtered_r}) - $signed({1'b0, g0_cb_center_r});
wire signed [8:0] g0_dcr_raw_w = $signed({1'b0, g0_cr_filtered_r}) - $signed({1'b0, g0_cr_center_r});
wire signed [8:0] g0_dcb_clamped_w = clamp_signed9(g0_dcb_raw_w, DELTA_CLAMP);
wire signed [8:0] g0_dcr_clamped_w = clamp_signed9(g0_dcr_raw_w, DELTA_CLAMP);
wire signed [8:0] g0_impulse_delta_y_w =
    $signed({1'b0, g0_y_center_r}) - $signed({1'b0, g0_y_neighbor_mean_r});
wire [8:0] g0_impulse_abs_delta_y_w = abs_signed9(g0_impulse_delta_y_w);
wire signed [9:0] g0_center_green_excess_w =
    $signed({1'b0, g0_g_center_r}) -
    $signed({1'b0, (({1'b0, g0_r_center_r} + {1'b0, g0_b_center_r}) >> 1)});
wire signed [9:0] g0_neighbor_green_excess_w =
    $signed({1'b0, g0_g_neighbor_mean_r}) -
    $signed({1'b0, (({1'b0, g0_r_neighbor_mean_r} + {1'b0, g0_b_neighbor_mean_r}) >> 1)});
wire signed [10:0] g0_green_excess_delta_w =
    $signed({g0_center_green_excess_w[9], g0_center_green_excess_w}) -
    $signed({g0_neighbor_green_excess_w[9], g0_neighbor_green_excess_w});
wire signed [8:0] g0_g_minus_gmean_w =
    $signed({1'b0, g0_g_center_r}) - $signed({1'b0, g0_g_neighbor_mean_r});
wire signed [8:0] g0_rmean_minus_r_w =
    $signed({1'b0, g0_r_neighbor_mean_r}) - $signed({1'b0, g0_r_center_r});
wire signed [8:0] g0_bmean_minus_b_w =
    $signed({1'b0, g0_b_neighbor_mean_r}) - $signed({1'b0, g0_b_center_r});
wire g0_startup_bypass_w =
    (g0_x_r < STARTUP_BYPASS_LEFT_PX) ||
    (g0_y_r < STARTUP_BYPASS_TOP_PX);

reg        g1_de_r;
reg [7:0]  g1_y_center_r;
reg [7:0]  g1_y_spread_r;
reg [7:0]  g1_y_neighbor_mean_r;
reg [7:0]  g1_y_neighbor_spread_r;
reg [7:0]  g1_cb_spread_r;
reg [7:0]  g1_cr_spread_r;
reg [7:0]  g1_r_r;
reg [7:0]  g1_g_r;
reg [7:0]  g1_b_r;
reg [7:0]  g1_r_mean_r;
reg [7:0]  g1_g_mean_r;
reg [7:0]  g1_b_mean_r;
reg [7:0]  g1_r_neighbor_spread_r;
reg [7:0]  g1_g_neighbor_spread_r;
reg [7:0]  g1_b_neighbor_spread_r;
reg [7:0]  g1_center_max_r;
reg [7:0]  g1_center_min_r;
reg signed [8:0]  g1_dcb_r;
reg signed [8:0]  g1_dcr_r;
reg [8:0]  g1_impulse_abs_delta_y_r;
reg signed [10:0] g1_green_excess_delta_r;
reg signed [8:0]  g1_g_minus_gmean_r;
reg signed [8:0]  g1_rmean_minus_r_r;
reg signed [8:0]  g1_bmean_minus_b_r;
reg        g1_startup_bypass_r;

wire g1_green_impulse_w =
    (g1_green_excess_delta_r >= $signed({3'b000, GREEN_EXCESS_DELTA_MIN})) ||
    ((g1_g_minus_gmean_r >= $signed({1'b0, GREEN_IMPULSE_DELTA_MIN})) &&
     (g1_rmean_minus_r_r >= $signed({1'b0, GREEN_IMPULSE_DELTA_MIN})) &&
     (g1_bmean_minus_b_r >= $signed({1'b0, GREEN_IMPULSE_DELTA_MIN})) &&
     (g1_r_neighbor_spread_r <= GREEN_IMPULSE_NEIGHBOR_RANGE_TH) &&
     (g1_g_neighbor_spread_r <= GREEN_IMPULSE_NEIGHBOR_RANGE_TH) &&
     (g1_b_neighbor_spread_r <= GREEN_IMPULSE_NEIGHBOR_RANGE_TH));
wire g1_impulse_core_w =
    (IMPULSE_ENABLE != 0) &&
    (g1_y_neighbor_mean_r > 8'd96) &&
    (g1_r_r > 8'd8) &&
    (g1_g_r > 8'd8) &&
    (g1_b_r > 8'd8) &&
    (((g1_y_neighbor_spread_r <= IMPULSE_NEIGHBOR_Y_RANGE_TH) &&
      (g1_impulse_abs_delta_y_r >= {1'b0, IMPULSE_DELTA_MIN}) &&
      (g1_impulse_abs_delta_y_r <= {1'b0, IMPULSE_DELTA_MAX})) ||
     g1_green_impulse_w);
wire g1_active_core_w =
    (ENABLE != 0) &&
    (g1_y_center_r > 8'd24) &&
    (g1_center_max_r < 8'd252) &&
    (g1_center_min_r > 8'd2) &&
    (g1_y_spread_r <= Y_RANGE_TH) &&
    (g1_cb_spread_r <= CHROMA_RANGE_TH) &&
    (g1_cr_spread_r <= CHROMA_RANGE_TH);
wire [7:0] g1_center_sat_w = g1_center_max_r - g1_center_min_r;
wire g1_edge_guard_w =
    (EDGE_GUARD_ENABLE != 0) &&
    (g1_center_sat_w >= EDGE_GUARD_SAT_TH) &&
    (g1_y_neighbor_spread_r >= EDGE_GUARD_Y_NEIGHBOR_SPREAD_MIN);

reg        g2_de_r;
reg [7:0]  g2_r_r;
reg [7:0]  g2_g_r;
reg [7:0]  g2_b_r;
reg [7:0]  g2_r_mean_r;
reg [7:0]  g2_g_mean_r;
reg [7:0]  g2_b_mean_r;
reg signed [8:0] g2_dcb_r;
reg signed [8:0] g2_dcr_r;
reg        g2_active_r;
reg        g2_impulse_r;

reg        m0_de_r;
reg [7:0]  m0_r_r;
reg [7:0]  m0_g_r;
reg [7:0]  m0_b_r;
reg signed [17:0] m0_dcb_prod_r;
reg signed [17:0] m0_dcr_prod_r;
reg signed [17:0] m0_impulse_dr_prod_r;
reg signed [17:0] m0_impulse_dg_prod_r;
reg signed [17:0] m0_impulse_db_prod_r;
reg        m0_active_r;
reg        m0_impulse_r;

reg        m1_de_r;
reg [7:0]  m1_r_r;
reg [7:0]  m1_g_r;
reg [7:0]  m1_b_r;
reg signed [8:0] m1_impulse_dr_r;
reg signed [8:0] m1_impulse_dg_r;
reg signed [8:0] m1_impulse_db_r;
reg signed [8:0] m1_dcb_scaled_r;
reg signed [8:0] m1_dcr_scaled_r;
reg        m1_active_r;
reg        m1_impulse_r;

reg        c0_de_r;
reg [7:0]  c0_r_r;
reg [7:0]  c0_g_r;
reg [7:0]  c0_b_r;
reg signed [18:0] c0_dr_prod_r;
reg signed [18:0] c0_db_prod_r;
reg signed [18:0] c0_dg_cb_prod_r;
reg signed [18:0] c0_dg_cr_prod_r;
reg        c0_active_r;

reg        c1_de_r;
reg [7:0]  c1_r_r;
reg [7:0]  c1_g_r;
reg [7:0]  c1_b_r;
reg signed [18:0] c1_dr_prod_r;
reg signed [18:0] c1_db_prod_r;
reg signed [18:0] c1_dg_sum_r;
reg        c1_active_r;

wire signed [8:0] m1_dcb_scaled_w = (m0_dcb_prod_r + 18'sd128) >>> 8;
wire signed [8:0] m1_dcr_scaled_w = (m0_dcr_prod_r + 18'sd128) >>> 8;
wire signed [8:0] m1_impulse_dr_w = (m0_impulse_dr_prod_r + 18'sd128) >>> 8;
wire signed [8:0] m1_impulse_dg_w = (m0_impulse_dg_prod_r + 18'sd128) >>> 8;
wire signed [8:0] m1_impulse_db_w = (m0_impulse_db_prod_r + 18'sd128) >>> 8;

wire [7:0] c0_impulse_r_w = m1_impulse_r ? clip_u8($signed({1'b0, m1_r_r}) + m1_impulse_dr_r) : m1_r_r;
wire [7:0] c0_impulse_g_w = m1_impulse_r ? clip_u8($signed({1'b0, m1_g_r}) + m1_impulse_dg_r) : m1_g_r;
wire [7:0] c0_impulse_b_w = m1_impulse_r ? clip_u8($signed({1'b0, m1_b_r}) + m1_impulse_db_r) : m1_b_r;

wire signed [10:0] c2_dr_w = c1_dr_prod_r >>> 8;
wire signed [10:0] c2_db_w = c1_db_prod_r >>> 8;
wire signed [10:0] c2_dg_w = -(c1_dg_sum_r >>> 8);
wire [7:0] c2_out_r_w = c1_active_r ? clip_u8($signed({1'b0, c1_r_r}) + c2_dr_w) : c1_r_r;
wire [7:0] c2_out_g_w = c1_active_r ? clip_u8($signed({1'b0, c1_g_r}) + c2_dg_w) : c1_g_r;
wire [7:0] c2_out_b_w = c1_active_r ? clip_u8($signed({1'b0, c1_b_r}) + c2_db_w) : c1_b_r;

stream_plane_causal3x3_current_stats
#(
    .H_DISP(H_DISP),
    .V_DISP(V_DISP)
)
u_y_stats
(
    .clk                (clk),
    .rst_n              (rst_n),
    .frame_clr          (frame_clr),
    .din_vld            (s0_de_r),
    .din                (s0_y_r),
    .out_vld            (y_de_w),
    .out_center         (y_center_w),
    .out_filtered       (y_filtered_w),
    .out_spread         (y_spread_w),
    .out_neighbor_mean  (y_neighbor_mean_w),
    .out_neighbor_spread(y_neighbor_spread_w),
    .out_x              (y_x_w),
    .out_y              (y_y_w)
);

stream_plane_causal3x3_current_stats
#(
    .H_DISP(H_DISP),
    .V_DISP(V_DISP)
)
u_cb_stats
(
    .clk                (clk),
    .rst_n              (rst_n),
    .frame_clr          (frame_clr),
    .din_vld            (s0_de_r),
    .din                (s0_cb_r),
    .out_vld            (cb_de_w),
    .out_center         (cb_center_w),
    .out_filtered       (cb_filtered_w),
    .out_spread         (cb_spread_w),
    .out_neighbor_mean  (),
    .out_neighbor_spread(),
    .out_x              (),
    .out_y              ()
);

stream_plane_causal3x3_current_stats
#(
    .H_DISP(H_DISP),
    .V_DISP(V_DISP)
)
u_cr_stats
(
    .clk                (clk),
    .rst_n              (rst_n),
    .frame_clr          (frame_clr),
    .din_vld            (s0_de_r),
    .din                (s0_cr_r),
    .out_vld            (cr_de_w),
    .out_center         (cr_center_w),
    .out_filtered       (cr_filtered_w),
    .out_spread         (cr_spread_w),
    .out_neighbor_mean  (),
    .out_neighbor_spread(),
    .out_x              (),
    .out_y              ()
);

stream_plane_causal3x3_current_stats
#(
    .H_DISP(H_DISP),
    .V_DISP(V_DISP)
)
u_r_stats
(
    .clk                (clk),
    .rst_n              (rst_n),
    .frame_clr          (frame_clr),
    .din_vld            (s0_de_r),
    .din                (s0_r_r),
    .out_vld            (r_de_w),
    .out_center         (r_center_w),
    .out_filtered       (),
    .out_spread         (),
    .out_neighbor_mean  (r_neighbor_mean_w),
    .out_neighbor_spread(r_neighbor_spread_w),
    .out_x              (),
    .out_y              ()
);

stream_plane_causal3x3_current_stats
#(
    .H_DISP(H_DISP),
    .V_DISP(V_DISP)
)
u_g_stats
(
    .clk                (clk),
    .rst_n              (rst_n),
    .frame_clr          (frame_clr),
    .din_vld            (s0_de_r),
    .din                (s0_g_r),
    .out_vld            (g_de_w),
    .out_center         (g_center_w),
    .out_filtered       (),
    .out_spread         (),
    .out_neighbor_mean  (g_neighbor_mean_w),
    .out_neighbor_spread(g_neighbor_spread_w),
    .out_x              (),
    .out_y              ()
);

stream_plane_causal3x3_current_stats
#(
    .H_DISP(H_DISP),
    .V_DISP(V_DISP)
)
u_b_stats
(
    .clk                (clk),
    .rst_n              (rst_n),
    .frame_clr          (frame_clr),
    .din_vld            (s0_de_r),
    .din                (s0_b_r),
    .out_vld            (b_de_w),
    .out_center         (b_center_w),
    .out_filtered       (),
    .out_spread         (),
    .out_neighbor_mean  (b_neighbor_mean_w),
    .out_neighbor_spread(b_neighbor_spread_w),
    .out_x              (),
    .out_y              ()
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        yc0_de_r <= 1'b0;
        yc0_r_r <= 8'd0;
        yc0_g_r <= 8'd0;
        yc0_b_r <= 8'd0;
        yc0_r_y_r <= 16'd0;
        yc0_g_y_r <= 16'd0;
        yc0_b_y_r <= 16'd0;
        yc0_r_cb_r <= 16'd0;
        yc0_g_cb_r <= 16'd0;
        yc0_b_cb_r <= 16'd0;
        yc0_r_cr_r <= 16'd0;
        yc0_g_cr_r <= 16'd0;
        yc0_b_cr_r <= 16'd0;
        s0_de_r <= 1'b0;
        s0_r_r <= 8'd0;
        s0_g_r <= 8'd0;
        s0_b_r <= 8'd0;
        s0_y_r <= 8'd0;
        s0_cb_r <= 8'd0;
        s0_cr_r <= 8'd0;
    end else if (frame_clr) begin
        yc0_de_r <= 1'b0;
        yc0_r_r <= 8'd0;
        yc0_g_r <= 8'd0;
        yc0_b_r <= 8'd0;
        yc0_r_y_r <= 16'd0;
        yc0_g_y_r <= 16'd0;
        yc0_b_y_r <= 16'd0;
        yc0_r_cb_r <= 16'd0;
        yc0_g_cb_r <= 16'd0;
        yc0_b_cb_r <= 16'd0;
        yc0_r_cr_r <= 16'd0;
        yc0_g_cr_r <= 16'd0;
        yc0_b_cr_r <= 16'd0;
        s0_de_r <= 1'b0;
        s0_r_r <= 8'd0;
        s0_g_r <= 8'd0;
        s0_b_r <= 8'd0;
        s0_y_r <= 8'd0;
        s0_cb_r <= 8'd0;
        s0_cr_r <= 8'd0;
    end else begin
        yc0_de_r <= in_de;
        if (in_de) begin
            yc0_r_r <= in_r_w;
            yc0_g_r <= in_g_w;
            yc0_b_r <= in_b_w;
            yc0_r_y_r <= in_r_y_w;
            yc0_g_y_r <= in_g_y_w;
            yc0_b_y_r <= in_b_y_w;
            yc0_r_cb_r <= in_r_cb_w;
            yc0_g_cb_r <= in_g_cb_w;
            yc0_b_cb_r <= in_b_cb_w;
            yc0_r_cr_r <= in_r_cr_w;
            yc0_g_cr_r <= in_g_cr_w;
            yc0_b_cr_r <= in_b_cr_w;
        end else begin
            yc0_r_r <= 8'd0;
            yc0_g_r <= 8'd0;
            yc0_b_r <= 8'd0;
            yc0_r_y_r <= 16'd0;
            yc0_g_y_r <= 16'd0;
            yc0_b_y_r <= 16'd0;
            yc0_r_cb_r <= 16'd0;
            yc0_g_cb_r <= 16'd0;
            yc0_b_cb_r <= 16'd0;
            yc0_r_cr_r <= 16'd0;
            yc0_g_cr_r <= 16'd0;
            yc0_b_cr_r <= 16'd0;
        end

        s0_de_r <= yc0_de_r;
        if (yc0_de_r) begin
            s0_r_r <= yc0_r_r;
            s0_g_r <= yc0_g_r;
            s0_b_r <= yc0_b_r;
            s0_y_r <= y_acc_w[15:8];
            s0_cb_r <= (cb_acc_w >>> 8) + 9'sd128;
            s0_cr_r <= (cr_acc_w >>> 8) + 9'sd128;
        end else begin
            s0_r_r <= 8'd0;
            s0_g_r <= 8'd0;
            s0_b_r <= 8'd0;
            s0_y_r <= 8'd0;
            s0_cb_r <= 8'd0;
            s0_cr_r <= 8'd0;
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        g0_de_r <= 1'b0;
        g0_y_center_r <= 8'd0;
        g0_y_spread_r <= 8'd0;
        g0_y_neighbor_mean_r <= 8'd0;
        g0_y_neighbor_spread_r <= 8'd0;
        g0_cb_center_r <= 8'd0;
        g0_cb_filtered_r <= 8'd0;
        g0_cb_spread_r <= 8'd0;
        g0_cr_center_r <= 8'd0;
        g0_cr_filtered_r <= 8'd0;
        g0_cr_spread_r <= 8'd0;
        g0_r_center_r <= 8'd0;
        g0_g_center_r <= 8'd0;
        g0_b_center_r <= 8'd0;
        g0_r_neighbor_mean_r <= 8'd0;
        g0_g_neighbor_mean_r <= 8'd0;
        g0_b_neighbor_mean_r <= 8'd0;
        g0_r_neighbor_spread_r <= 8'd0;
        g0_g_neighbor_spread_r <= 8'd0;
        g0_b_neighbor_spread_r <= 8'd0;
        g0_x_r <= 11'd0;
        g0_y_r <= 11'd0;
    end else if (frame_clr) begin
        g0_de_r <= 1'b0;
        g0_y_center_r <= 8'd0;
        g0_y_spread_r <= 8'd0;
        g0_y_neighbor_mean_r <= 8'd0;
        g0_y_neighbor_spread_r <= 8'd0;
        g0_cb_center_r <= 8'd0;
        g0_cb_filtered_r <= 8'd0;
        g0_cb_spread_r <= 8'd0;
        g0_cr_center_r <= 8'd0;
        g0_cr_filtered_r <= 8'd0;
        g0_cr_spread_r <= 8'd0;
        g0_r_center_r <= 8'd0;
        g0_g_center_r <= 8'd0;
        g0_b_center_r <= 8'd0;
        g0_r_neighbor_mean_r <= 8'd0;
        g0_g_neighbor_mean_r <= 8'd0;
        g0_b_neighbor_mean_r <= 8'd0;
        g0_r_neighbor_spread_r <= 8'd0;
        g0_g_neighbor_spread_r <= 8'd0;
        g0_b_neighbor_spread_r <= 8'd0;
        g0_x_r <= 11'd0;
        g0_y_r <= 11'd0;
    end else begin
        g0_de_r <= stats_de_w;
        if (stats_de_w) begin
            g0_y_center_r <= y_center_w;
            g0_y_spread_r <= y_spread_w;
            g0_y_neighbor_mean_r <= y_neighbor_mean_w;
            g0_y_neighbor_spread_r <= y_neighbor_spread_w;
            g0_cb_center_r <= cb_center_w;
            g0_cb_filtered_r <= cb_filtered_w;
            g0_cb_spread_r <= cb_spread_w;
            g0_cr_center_r <= cr_center_w;
            g0_cr_filtered_r <= cr_filtered_w;
            g0_cr_spread_r <= cr_spread_w;
            g0_r_center_r <= r_center_w;
            g0_g_center_r <= g_center_w;
            g0_b_center_r <= b_center_w;
            g0_r_neighbor_mean_r <= r_neighbor_mean_w;
            g0_g_neighbor_mean_r <= g_neighbor_mean_w;
            g0_b_neighbor_mean_r <= b_neighbor_mean_w;
            g0_r_neighbor_spread_r <= r_neighbor_spread_w;
            g0_g_neighbor_spread_r <= g_neighbor_spread_w;
            g0_b_neighbor_spread_r <= b_neighbor_spread_w;
            g0_x_r <= y_x_w;
            g0_y_r <= y_y_w;
        end else begin
            g0_y_center_r <= 8'd0;
            g0_y_spread_r <= 8'd0;
            g0_y_neighbor_mean_r <= 8'd0;
            g0_y_neighbor_spread_r <= 8'd0;
            g0_cb_center_r <= 8'd0;
            g0_cb_filtered_r <= 8'd0;
            g0_cb_spread_r <= 8'd0;
            g0_cr_center_r <= 8'd0;
            g0_cr_filtered_r <= 8'd0;
            g0_cr_spread_r <= 8'd0;
            g0_r_center_r <= 8'd0;
            g0_g_center_r <= 8'd0;
            g0_b_center_r <= 8'd0;
            g0_r_neighbor_mean_r <= 8'd0;
            g0_g_neighbor_mean_r <= 8'd0;
            g0_b_neighbor_mean_r <= 8'd0;
            g0_r_neighbor_spread_r <= 8'd0;
            g0_g_neighbor_spread_r <= 8'd0;
            g0_b_neighbor_spread_r <= 8'd0;
            g0_x_r <= 11'd0;
            g0_y_r <= 11'd0;
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        g1_de_r <= 1'b0;
        g1_y_center_r <= 8'd0;
        g1_y_spread_r <= 8'd0;
        g1_y_neighbor_mean_r <= 8'd0;
        g1_y_neighbor_spread_r <= 8'd0;
        g1_cb_spread_r <= 8'd0;
        g1_cr_spread_r <= 8'd0;
        g1_r_r <= 8'd0;
        g1_g_r <= 8'd0;
        g1_b_r <= 8'd0;
        g1_r_mean_r <= 8'd0;
        g1_g_mean_r <= 8'd0;
        g1_b_mean_r <= 8'd0;
        g1_r_neighbor_spread_r <= 8'd0;
        g1_g_neighbor_spread_r <= 8'd0;
        g1_b_neighbor_spread_r <= 8'd0;
        g1_center_max_r <= 8'd0;
        g1_center_min_r <= 8'd0;
        g1_dcb_r <= 9'sd0;
        g1_dcr_r <= 9'sd0;
        g1_impulse_abs_delta_y_r <= 9'd0;
        g1_green_excess_delta_r <= 11'sd0;
        g1_g_minus_gmean_r <= 9'sd0;
        g1_rmean_minus_r_r <= 9'sd0;
        g1_bmean_minus_b_r <= 9'sd0;
        g1_startup_bypass_r <= 1'b0;
    end else if (frame_clr) begin
        g1_de_r <= 1'b0;
        g1_y_center_r <= 8'd0;
        g1_y_spread_r <= 8'd0;
        g1_y_neighbor_mean_r <= 8'd0;
        g1_y_neighbor_spread_r <= 8'd0;
        g1_cb_spread_r <= 8'd0;
        g1_cr_spread_r <= 8'd0;
        g1_r_r <= 8'd0;
        g1_g_r <= 8'd0;
        g1_b_r <= 8'd0;
        g1_r_mean_r <= 8'd0;
        g1_g_mean_r <= 8'd0;
        g1_b_mean_r <= 8'd0;
        g1_r_neighbor_spread_r <= 8'd0;
        g1_g_neighbor_spread_r <= 8'd0;
        g1_b_neighbor_spread_r <= 8'd0;
        g1_center_max_r <= 8'd0;
        g1_center_min_r <= 8'd0;
        g1_dcb_r <= 9'sd0;
        g1_dcr_r <= 9'sd0;
        g1_impulse_abs_delta_y_r <= 9'd0;
        g1_green_excess_delta_r <= 11'sd0;
        g1_g_minus_gmean_r <= 9'sd0;
        g1_rmean_minus_r_r <= 9'sd0;
        g1_bmean_minus_b_r <= 9'sd0;
        g1_startup_bypass_r <= 1'b0;
    end else begin
        g1_de_r <= g0_de_r;
        if (g0_de_r) begin
            g1_y_center_r <= g0_y_center_r;
            g1_y_spread_r <= g0_y_spread_r;
            g1_y_neighbor_mean_r <= g0_y_neighbor_mean_r;
            g1_y_neighbor_spread_r <= g0_y_neighbor_spread_r;
            g1_cb_spread_r <= g0_cb_spread_r;
            g1_cr_spread_r <= g0_cr_spread_r;
            g1_r_r <= g0_r_center_r;
            g1_g_r <= g0_g_center_r;
            g1_b_r <= g0_b_center_r;
            g1_r_mean_r <= g0_r_neighbor_mean_r;
            g1_g_mean_r <= g0_g_neighbor_mean_r;
            g1_b_mean_r <= g0_b_neighbor_mean_r;
            g1_r_neighbor_spread_r <= g0_r_neighbor_spread_r;
            g1_g_neighbor_spread_r <= g0_g_neighbor_spread_r;
            g1_b_neighbor_spread_r <= g0_b_neighbor_spread_r;
            g1_center_max_r <= g0_center_max_w;
            g1_center_min_r <= g0_center_min_w;
            g1_dcb_r <= g0_dcb_clamped_w;
            g1_dcr_r <= g0_dcr_clamped_w;
            g1_impulse_abs_delta_y_r <= g0_impulse_abs_delta_y_w;
            g1_green_excess_delta_r <= g0_green_excess_delta_w;
            g1_g_minus_gmean_r <= g0_g_minus_gmean_w;
            g1_rmean_minus_r_r <= g0_rmean_minus_r_w;
            g1_bmean_minus_b_r <= g0_bmean_minus_b_w;
            g1_startup_bypass_r <= g0_startup_bypass_w;
        end else begin
            g1_y_center_r <= 8'd0;
            g1_y_spread_r <= 8'd0;
            g1_y_neighbor_mean_r <= 8'd0;
            g1_y_neighbor_spread_r <= 8'd0;
            g1_cb_spread_r <= 8'd0;
            g1_cr_spread_r <= 8'd0;
            g1_r_r <= 8'd0;
            g1_g_r <= 8'd0;
            g1_b_r <= 8'd0;
            g1_r_mean_r <= 8'd0;
            g1_g_mean_r <= 8'd0;
            g1_b_mean_r <= 8'd0;
            g1_r_neighbor_spread_r <= 8'd0;
            g1_g_neighbor_spread_r <= 8'd0;
            g1_b_neighbor_spread_r <= 8'd0;
            g1_center_max_r <= 8'd0;
            g1_center_min_r <= 8'd0;
            g1_dcb_r <= 9'sd0;
            g1_dcr_r <= 9'sd0;
            g1_impulse_abs_delta_y_r <= 9'd0;
            g1_green_excess_delta_r <= 11'sd0;
            g1_g_minus_gmean_r <= 9'sd0;
            g1_rmean_minus_r_r <= 9'sd0;
            g1_bmean_minus_b_r <= 9'sd0;
            g1_startup_bypass_r <= 1'b0;
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        g2_de_r <= 1'b0;
        g2_r_r <= 8'd0;
        g2_g_r <= 8'd0;
        g2_b_r <= 8'd0;
        g2_r_mean_r <= 8'd0;
        g2_g_mean_r <= 8'd0;
        g2_b_mean_r <= 8'd0;
        g2_dcb_r <= 9'sd0;
        g2_dcr_r <= 9'sd0;
        g2_active_r <= 1'b0;
        g2_impulse_r <= 1'b0;
    end else if (frame_clr) begin
        g2_de_r <= 1'b0;
        g2_r_r <= 8'd0;
        g2_g_r <= 8'd0;
        g2_b_r <= 8'd0;
        g2_r_mean_r <= 8'd0;
        g2_g_mean_r <= 8'd0;
        g2_b_mean_r <= 8'd0;
        g2_dcb_r <= 9'sd0;
        g2_dcr_r <= 9'sd0;
        g2_active_r <= 1'b0;
        g2_impulse_r <= 1'b0;
    end else begin
        g2_de_r <= g1_de_r;
        if (g1_de_r) begin
            g2_r_r <= g1_r_r;
            g2_g_r <= g1_g_r;
            g2_b_r <= g1_b_r;
            g2_r_mean_r <= g1_r_mean_r;
            g2_g_mean_r <= g1_g_mean_r;
            g2_b_mean_r <= g1_b_mean_r;
            g2_dcb_r <= g1_dcb_r;
            g2_dcr_r <= g1_dcr_r;
            g2_active_r <= g1_active_core_w && !g1_edge_guard_w && !g1_startup_bypass_r;
            g2_impulse_r <= g1_impulse_core_w && !g1_edge_guard_w && !g1_startup_bypass_r;
        end else begin
            g2_r_r <= 8'd0;
            g2_g_r <= 8'd0;
            g2_b_r <= 8'd0;
            g2_r_mean_r <= 8'd0;
            g2_g_mean_r <= 8'd0;
            g2_b_mean_r <= 8'd0;
            g2_dcb_r <= 9'sd0;
            g2_dcr_r <= 9'sd0;
            g2_active_r <= 1'b0;
            g2_impulse_r <= 1'b0;
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        m0_de_r <= 1'b0;
        m0_r_r <= 8'd0;
        m0_g_r <= 8'd0;
        m0_b_r <= 8'd0;
        m0_dcb_prod_r <= 18'sd0;
        m0_dcr_prod_r <= 18'sd0;
        m0_impulse_dr_prod_r <= 18'sd0;
        m0_impulse_dg_prod_r <= 18'sd0;
        m0_impulse_db_prod_r <= 18'sd0;
        m0_active_r <= 1'b0;
        m0_impulse_r <= 1'b0;
    end else if (frame_clr) begin
        m0_de_r <= 1'b0;
        m0_r_r <= 8'd0;
        m0_g_r <= 8'd0;
        m0_b_r <= 8'd0;
        m0_dcb_prod_r <= 18'sd0;
        m0_dcr_prod_r <= 18'sd0;
        m0_impulse_dr_prod_r <= 18'sd0;
        m0_impulse_dg_prod_r <= 18'sd0;
        m0_impulse_db_prod_r <= 18'sd0;
        m0_active_r <= 1'b0;
        m0_impulse_r <= 1'b0;
    end else begin
        m0_de_r <= g2_de_r;
        m0_r_r <= g2_de_r ? g2_r_r : 8'd0;
        m0_g_r <= g2_de_r ? g2_g_r : 8'd0;
        m0_b_r <= g2_de_r ? g2_b_r : 8'd0;
        m0_dcb_prod_r <= g2_dcb_r * $signed({1'b0, ALPHA_Q8});
        m0_dcr_prod_r <= g2_dcr_r * $signed({1'b0, ALPHA_Q8});
        m0_impulse_dr_prod_r <=
            ($signed({1'b0, g2_r_mean_r}) - $signed({1'b0, g2_r_r})) * $signed({1'b0, IMPULSE_ALPHA_Q8});
        m0_impulse_dg_prod_r <=
            ($signed({1'b0, g2_g_mean_r}) - $signed({1'b0, g2_g_r})) * $signed({1'b0, IMPULSE_ALPHA_Q8});
        m0_impulse_db_prod_r <=
            ($signed({1'b0, g2_b_mean_r}) - $signed({1'b0, g2_b_r})) * $signed({1'b0, IMPULSE_ALPHA_Q8});
        m0_active_r <= g2_active_r;
        m0_impulse_r <= g2_impulse_r;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        m1_de_r <= 1'b0;
        m1_r_r <= 8'd0;
        m1_g_r <= 8'd0;
        m1_b_r <= 8'd0;
        m1_impulse_dr_r <= 9'sd0;
        m1_impulse_dg_r <= 9'sd0;
        m1_impulse_db_r <= 9'sd0;
        m1_dcb_scaled_r <= 9'sd0;
        m1_dcr_scaled_r <= 9'sd0;
        m1_active_r <= 1'b0;
        m1_impulse_r <= 1'b0;
    end else if (frame_clr) begin
        m1_de_r <= 1'b0;
        m1_r_r <= 8'd0;
        m1_g_r <= 8'd0;
        m1_b_r <= 8'd0;
        m1_impulse_dr_r <= 9'sd0;
        m1_impulse_dg_r <= 9'sd0;
        m1_impulse_db_r <= 9'sd0;
        m1_dcb_scaled_r <= 9'sd0;
        m1_dcr_scaled_r <= 9'sd0;
        m1_active_r <= 1'b0;
        m1_impulse_r <= 1'b0;
    end else begin
        m1_de_r <= m0_de_r;
        m1_r_r <= m0_de_r ? m0_r_r : 8'd0;
        m1_g_r <= m0_de_r ? m0_g_r : 8'd0;
        m1_b_r <= m0_de_r ? m0_b_r : 8'd0;
        m1_impulse_dr_r <= m1_impulse_dr_w;
        m1_impulse_dg_r <= m1_impulse_dg_w;
        m1_impulse_db_r <= m1_impulse_db_w;
        m1_dcb_scaled_r <= m1_dcb_scaled_w;
        m1_dcr_scaled_r <= m1_dcr_scaled_w;
        m1_active_r <= m0_active_r;
        m1_impulse_r <= m0_impulse_r;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        c0_de_r <= 1'b0;
        c0_r_r <= 8'd0;
        c0_g_r <= 8'd0;
        c0_b_r <= 8'd0;
        c0_dr_prod_r <= 19'sd0;
        c0_db_prod_r <= 19'sd0;
        c0_dg_cb_prod_r <= 19'sd0;
        c0_dg_cr_prod_r <= 19'sd0;
        c0_active_r <= 1'b0;
    end else if (frame_clr) begin
        c0_de_r <= 1'b0;
        c0_r_r <= 8'd0;
        c0_g_r <= 8'd0;
        c0_b_r <= 8'd0;
        c0_dr_prod_r <= 19'sd0;
        c0_db_prod_r <= 19'sd0;
        c0_dg_cb_prod_r <= 19'sd0;
        c0_dg_cr_prod_r <= 19'sd0;
        c0_active_r <= 1'b0;
    end else begin
        c0_de_r <= m1_de_r;
        c0_r_r <= m1_de_r ? c0_impulse_r_w : 8'd0;
        c0_g_r <= m1_de_r ? c0_impulse_g_w : 8'd0;
        c0_b_r <= m1_de_r ? c0_impulse_b_w : 8'd0;
        c0_dr_prod_r <= m1_dcr_scaled_r * 10'sd359;
        c0_db_prod_r <= m1_dcb_scaled_r * 10'sd454;
        c0_dg_cb_prod_r <= m1_dcb_scaled_r * 9'sd88;
        c0_dg_cr_prod_r <= m1_dcr_scaled_r * 9'sd183;
        c0_active_r <= m1_active_r;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        c1_de_r <= 1'b0;
        c1_r_r <= 8'd0;
        c1_g_r <= 8'd0;
        c1_b_r <= 8'd0;
        c1_dr_prod_r <= 19'sd0;
        c1_db_prod_r <= 19'sd0;
        c1_dg_sum_r <= 19'sd0;
        c1_active_r <= 1'b0;
    end else if (frame_clr) begin
        c1_de_r <= 1'b0;
        c1_r_r <= 8'd0;
        c1_g_r <= 8'd0;
        c1_b_r <= 8'd0;
        c1_dr_prod_r <= 19'sd0;
        c1_db_prod_r <= 19'sd0;
        c1_dg_sum_r <= 19'sd0;
        c1_active_r <= 1'b0;
    end else begin
        c1_de_r <= c0_de_r;
        c1_r_r <= c0_de_r ? c0_r_r : 8'd0;
        c1_g_r <= c0_de_r ? c0_g_r : 8'd0;
        c1_b_r <= c0_de_r ? c0_b_r : 8'd0;
        c1_dr_prod_r <= c0_dr_prod_r + 19'sd128;
        c1_db_prod_r <= c0_db_prod_r + 19'sd128;
        c1_dg_sum_r <= c0_dg_cb_prod_r + c0_dg_cr_prod_r + 19'sd128;
        c1_active_r <= c0_active_r;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        out_de <= 1'b0;
        out_rgb <= 24'd0;
    end else if (frame_clr) begin
        out_de <= 1'b0;
        out_rgb <= 24'd0;
    end else begin
        out_de <= c1_de_r;
        out_rgb <= c1_de_r ? {c2_out_r_w, c2_out_g_w, c2_out_b_w} : 24'd0;
    end
end

endmodule

module stream_plane_causal3x3_current_stats
#(
    parameter H_DISP = 1280,
    parameter V_DISP = 720
)
(
    input   wire            clk,
    input   wire            rst_n,
    input   wire            frame_clr,
    input   wire            din_vld,
    input   wire    [7:0]   din,

    output  reg             out_vld,
    output  reg     [7:0]   out_center,
    output  reg     [7:0]   out_filtered,
    output  reg     [7:0]   out_spread,
    output  reg     [7:0]   out_neighbor_mean,
    output  reg     [7:0]   out_neighbor_spread,
    output  reg     [10:0]  out_x,
    output  reg     [10:0]  out_y
);

function [7:0] min2_u8;
    input [7:0] a;
    input [7:0] b;
    begin
        min2_u8 = (a <= b) ? a : b;
    end
endfunction

function [7:0] max2_u8;
    input [7:0] a;
    input [7:0] b;
    begin
        max2_u8 = (a >= b) ? a : b;
    end
endfunction

wire [7:0] line1_q;
wire [7:0] line2_q;
wire [7:0] top_src_w;
wire [7:0] mid_src_w;
wire [7:0] next_m11_w;
wire [7:0] next_m12_w;
wire [7:0] next_m13_w;
wire [7:0] next_m21_w;
wire [7:0] next_m22_w;
wire [7:0] next_m23_w;
wire [7:0] next_m31_w;
wire [7:0] next_m32_w;
wire [7:0] next_m33_w;

(* synthesis, probe_port, keep, preserve, noprune, syn_preserve = 1, syn_keep = 1, altera_attribute = "-name AUTO_SHIFT_REGISTER_RECOGNITION OFF" *) reg         din_vld_d1;
(* synthesis, probe_port, keep, preserve, noprune, syn_preserve = 1, syn_keep = 1, altera_attribute = "-name AUTO_SHIFT_REGISTER_RECOGNITION OFF" *) reg         din_vld_d1_linebuf_r;
(* synthesis, probe_port, keep, preserve, noprune, syn_preserve = 1, syn_keep = 1, altera_attribute = "-name AUTO_SHIFT_REGISTER_RECOGNITION OFF" *) reg         din_vld_d2;
reg  [7:0]  din_d1;
reg  [7:0]  din_d2;
(* preserve, syn_preserve = 1 *) reg  [11:0] col_cnt;
(* preserve, syn_preserve = 1 *) reg  [11:0] row_cnt;
(* preserve, syn_preserve = 1 *) reg  [10:0] col_d1;
(* preserve, syn_preserve = 1 *) reg  [10:0] col_d2;
(* preserve, syn_preserve = 1 *) reg  [11:0] row_d1;
(* preserve, syn_preserve = 1 *) reg  [11:0] row_d2;
(* synthesis, probe_port, keep, preserve, noprune, syn_preserve = 1, syn_keep = 1, altera_attribute = "-name AUTO_SHIFT_REGISTER_RECOGNITION OFF" *) reg         row_nonzero_d1_r;
reg  [7:0]  line1_q_d1;

reg [7:0] matrix_11;
reg [7:0] matrix_12;
reg [7:0] matrix_13;
reg [7:0] matrix_21;
reg [7:0] matrix_22;
reg [7:0] matrix_23;
reg [7:0] matrix_31;
reg [7:0] matrix_32;
reg [7:0] matrix_33;

reg        s1_vld_r;
reg [7:0]  s1_p11_r;
reg [7:0]  s1_p12_r;
reg [7:0]  s1_p13_r;
reg [7:0]  s1_p21_r;
reg [7:0]  s1_p22_r;
reg [7:0]  s1_p23_r;
reg [7:0]  s1_p31_r;
reg [7:0]  s1_p32_r;
reg [7:0]  s1_p33_r;
reg [10:0] s1_x_r;
reg [10:0] s1_y_r;

reg         s2_vld_r;
reg  [7:0] s2_center_r;
reg [10:0] s2_filtered_row0_r;
reg [10:0] s2_filtered_row1_r;
reg [10:0] s2_filtered_row2_r;
reg  [7:0] s2_min_row0_r;
reg  [7:0] s2_min_row1_r;
reg  [7:0] s2_min_row2_r;
reg  [7:0] s2_max_row0_r;
reg  [7:0] s2_max_row1_r;
reg  [7:0] s2_max_row2_r;
reg  [7:0] s2_neighbor_min_row0_r;
reg  [7:0] s2_neighbor_min_row1_r;
reg  [7:0] s2_neighbor_min_row2_r;
reg  [7:0] s2_neighbor_max_row0_r;
reg  [7:0] s2_neighbor_max_row1_r;
reg  [7:0] s2_neighbor_max_row2_r;
reg [11:0] s2_neighbor_sum_r;
reg [10:0] s2_x_r;
reg [10:0] s2_y_r;

wire [10:0] s1_filtered_row0_w =
    {3'd0, s1_p11_r} + {2'd0, s1_p12_r, 1'b0} + {3'd0, s1_p13_r};
wire [10:0] s1_filtered_row1_w =
    {2'd0, s1_p21_r, 1'b0} + {1'd0, s1_p22_r, 2'b00} + {2'd0, s1_p23_r, 1'b0};
wire [10:0] s1_filtered_row2_w =
    {3'd0, s1_p31_r} + {2'd0, s1_p32_r, 1'b0} + {3'd0, s1_p33_r};
wire [11:0] filtered_sum_w =
    {1'b0, s2_filtered_row0_r} + {1'b0, s2_filtered_row1_r} + {1'b0, s2_filtered_row2_r};
wire [7:0] filtered_px_w = (filtered_sum_w + 12'd8) >> 4;

wire [7:0] min_row0_w = min2_u8(min2_u8(s1_p11_r, s1_p12_r), s1_p13_r);
wire [7:0] min_row1_w = min2_u8(min2_u8(s1_p21_r, s1_p22_r), s1_p23_r);
wire [7:0] min_row2_w = min2_u8(min2_u8(s1_p31_r, s1_p32_r), s1_p33_r);
wire [7:0] min_all_w = min2_u8(min2_u8(s2_min_row0_r, s2_min_row1_r), s2_min_row2_r);
wire [7:0] max_row0_w = max2_u8(max2_u8(s1_p11_r, s1_p12_r), s1_p13_r);
wire [7:0] max_row1_w = max2_u8(max2_u8(s1_p21_r, s1_p22_r), s1_p23_r);
wire [7:0] max_row2_w = max2_u8(max2_u8(s1_p31_r, s1_p32_r), s1_p33_r);
wire [7:0] max_all_w = max2_u8(max2_u8(s2_max_row0_r, s2_max_row1_r), s2_max_row2_r);
wire [7:0] spread_w = max_all_w - min_all_w;

wire [7:0] neighbor_min_row0_w = min_row0_w;
wire [7:0] neighbor_min_row1_w = min_row1_w;
wire [7:0] neighbor_min_row2_w = min2_u8(s1_p31_r, s1_p32_r);
wire [7:0] neighbor_min_w =
    min2_u8(min2_u8(s2_neighbor_min_row0_r, s2_neighbor_min_row1_r), s2_neighbor_min_row2_r);
wire [7:0] neighbor_max_row0_w = max_row0_w;
wire [7:0] neighbor_max_row1_w = max_row1_w;
wire [7:0] neighbor_max_row2_w = max2_u8(s1_p31_r, s1_p32_r);
wire [7:0] neighbor_max_w =
    max2_u8(max2_u8(s2_neighbor_max_row0_r, s2_neighbor_max_row1_r), s2_neighbor_max_row2_r);
wire [7:0] neighbor_spread_w = neighbor_max_w - neighbor_min_w;
wire [11:0] neighbor_sum_w =
    {4'd0, s1_p11_r} + {4'd0, s1_p12_r} + {4'd0, s1_p13_r} +
    {4'd0, s1_p21_r} + {4'd0, s1_p22_r} + {4'd0, s1_p23_r} +
    {4'd0, s1_p31_r} + {4'd0, s1_p32_r};
wire [7:0] neighbor_mean_w = (s2_neighbor_sum_r + 12'd4) >> 3;

assign top_src_w = (row_d2 < 12'd2) ? 8'd0 : line2_q;
assign mid_src_w = (row_d2 == 12'd0) ? 8'd0 : line1_q_d1;

assign next_m11_w = (col_d2 == 11'd0) ? 8'd0 : matrix_12;
assign next_m12_w = (col_d2 == 11'd0) ? 8'd0 : matrix_13;
assign next_m13_w = top_src_w;
assign next_m21_w = (col_d2 == 11'd0) ? 8'd0 : matrix_22;
assign next_m22_w = (col_d2 == 11'd0) ? 8'd0 : matrix_23;
assign next_m23_w = mid_src_w;
assign next_m31_w = (col_d2 == 11'd0) ? 8'd0 : matrix_32;
assign next_m32_w = (col_d2 == 11'd0) ? 8'd0 : matrix_33;
assign next_m33_w = din_d2;

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
    .wren       (din_vld_d1_linebuf_r && row_nonzero_d1_r),
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
        din_vld_d1_linebuf_r <= 1'b0;
        din_vld_d2 <= 1'b0;
        din_d1 <= 8'd0;
        din_d2 <= 8'd0;
        col_d1 <= 11'd0;
        col_d2 <= 11'd0;
        row_d1 <= 12'd0;
        row_d2 <= 12'd0;
        row_nonzero_d1_r <= 1'b0;
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
        s1_vld_r <= 1'b0;
        s1_p11_r <= 8'd0;
        s1_p12_r <= 8'd0;
        s1_p13_r <= 8'd0;
        s1_p21_r <= 8'd0;
        s1_p22_r <= 8'd0;
        s1_p23_r <= 8'd0;
        s1_p31_r <= 8'd0;
        s1_p32_r <= 8'd0;
        s1_p33_r <= 8'd0;
        s1_x_r <= 11'd0;
        s1_y_r <= 11'd0;
        s2_vld_r <= 1'b0;
        s2_center_r <= 8'd0;
        s2_filtered_row0_r <= 11'd0;
        s2_filtered_row1_r <= 11'd0;
        s2_filtered_row2_r <= 11'd0;
        s2_min_row0_r <= 8'd0;
        s2_min_row1_r <= 8'd0;
        s2_min_row2_r <= 8'd0;
        s2_max_row0_r <= 8'd0;
        s2_max_row1_r <= 8'd0;
        s2_max_row2_r <= 8'd0;
        s2_neighbor_min_row0_r <= 8'd0;
        s2_neighbor_min_row1_r <= 8'd0;
        s2_neighbor_min_row2_r <= 8'd0;
        s2_neighbor_max_row0_r <= 8'd0;
        s2_neighbor_max_row1_r <= 8'd0;
        s2_neighbor_max_row2_r <= 8'd0;
        s2_neighbor_sum_r <= 12'd0;
        s2_x_r <= 11'd0;
        s2_y_r <= 11'd0;
    end else if (frame_clr) begin
        col_cnt <= 12'd0;
        row_cnt <= 12'd0;
        din_vld_d1 <= 1'b0;
        din_vld_d1_linebuf_r <= 1'b0;
        din_vld_d2 <= 1'b0;
        din_d1 <= 8'd0;
        din_d2 <= 8'd0;
        col_d1 <= 11'd0;
        col_d2 <= 11'd0;
        row_d1 <= 12'd0;
        row_d2 <= 12'd0;
        row_nonzero_d1_r <= 1'b0;
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
        s1_vld_r <= 1'b0;
        s1_p11_r <= 8'd0;
        s1_p12_r <= 8'd0;
        s1_p13_r <= 8'd0;
        s1_p21_r <= 8'd0;
        s1_p22_r <= 8'd0;
        s1_p23_r <= 8'd0;
        s1_p31_r <= 8'd0;
        s1_p32_r <= 8'd0;
        s1_p33_r <= 8'd0;
        s1_x_r <= 11'd0;
        s1_y_r <= 11'd0;
        s2_vld_r <= 1'b0;
        s2_center_r <= 8'd0;
        s2_filtered_row0_r <= 11'd0;
        s2_filtered_row1_r <= 11'd0;
        s2_filtered_row2_r <= 11'd0;
        s2_min_row0_r <= 8'd0;
        s2_min_row1_r <= 8'd0;
        s2_min_row2_r <= 8'd0;
        s2_max_row0_r <= 8'd0;
        s2_max_row1_r <= 8'd0;
        s2_max_row2_r <= 8'd0;
        s2_neighbor_min_row0_r <= 8'd0;
        s2_neighbor_min_row1_r <= 8'd0;
        s2_neighbor_min_row2_r <= 8'd0;
        s2_neighbor_max_row0_r <= 8'd0;
        s2_neighbor_max_row1_r <= 8'd0;
        s2_neighbor_max_row2_r <= 8'd0;
        s2_neighbor_sum_r <= 12'd0;
        s2_x_r <= 11'd0;
        s2_y_r <= 11'd0;
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
        din_vld_d1_linebuf_r <= din_vld;
        din_d1 <= din;
        col_d1 <= col_cnt[10:0];
        row_d1 <= row_cnt;
        row_nonzero_d1_r <= (row_cnt != 12'd0);

        din_vld_d2 <= din_vld_d1;
        din_d2 <= din_d1;
        col_d2 <= col_d1;
        row_d2 <= row_d1;
        line1_q_d1 <= line1_q;

        s1_vld_r <= din_vld_d2;
        if (din_vld_d2) begin
            matrix_11 <= next_m11_w;
            matrix_12 <= next_m12_w;
            matrix_13 <= next_m13_w;
            matrix_21 <= next_m21_w;
            matrix_22 <= next_m22_w;
            matrix_23 <= next_m23_w;
            matrix_31 <= next_m31_w;
            matrix_32 <= next_m32_w;
            matrix_33 <= next_m33_w;

            s1_p11_r <= next_m11_w;
            s1_p12_r <= next_m12_w;
            s1_p13_r <= next_m13_w;
            s1_p21_r <= next_m21_w;
            s1_p22_r <= next_m22_w;
            s1_p23_r <= next_m23_w;
            s1_p31_r <= next_m31_w;
            s1_p32_r <= next_m32_w;
            s1_p33_r <= next_m33_w;
            s1_x_r <= col_d2;
            s1_y_r <= row_d2[10:0];
        end else begin
            s1_p11_r <= 8'd0;
            s1_p12_r <= 8'd0;
            s1_p13_r <= 8'd0;
            s1_p21_r <= 8'd0;
            s1_p22_r <= 8'd0;
            s1_p23_r <= 8'd0;
            s1_p31_r <= 8'd0;
            s1_p32_r <= 8'd0;
            s1_p33_r <= 8'd0;
            s1_x_r <= 11'd0;
            s1_y_r <= 11'd0;
        end

        s2_vld_r <= s1_vld_r;
        if (s1_vld_r) begin
            s2_center_r <= s1_p33_r;
            s2_filtered_row0_r <= s1_filtered_row0_w;
            s2_filtered_row1_r <= s1_filtered_row1_w;
            s2_filtered_row2_r <= s1_filtered_row2_w;
            s2_min_row0_r <= min_row0_w;
            s2_min_row1_r <= min_row1_w;
            s2_min_row2_r <= min_row2_w;
            s2_max_row0_r <= max_row0_w;
            s2_max_row1_r <= max_row1_w;
            s2_max_row2_r <= max_row2_w;
            s2_neighbor_min_row0_r <= neighbor_min_row0_w;
            s2_neighbor_min_row1_r <= neighbor_min_row1_w;
            s2_neighbor_min_row2_r <= neighbor_min_row2_w;
            s2_neighbor_max_row0_r <= neighbor_max_row0_w;
            s2_neighbor_max_row1_r <= neighbor_max_row1_w;
            s2_neighbor_max_row2_r <= neighbor_max_row2_w;
            s2_neighbor_sum_r <= neighbor_sum_w;
            s2_x_r <= s1_x_r;
            s2_y_r <= s1_y_r;
        end else begin
            s2_center_r <= 8'd0;
            s2_filtered_row0_r <= 11'd0;
            s2_filtered_row1_r <= 11'd0;
            s2_filtered_row2_r <= 11'd0;
            s2_min_row0_r <= 8'd0;
            s2_min_row1_r <= 8'd0;
            s2_min_row2_r <= 8'd0;
            s2_max_row0_r <= 8'd0;
            s2_max_row1_r <= 8'd0;
            s2_max_row2_r <= 8'd0;
            s2_neighbor_min_row0_r <= 8'd0;
            s2_neighbor_min_row1_r <= 8'd0;
            s2_neighbor_min_row2_r <= 8'd0;
            s2_neighbor_max_row0_r <= 8'd0;
            s2_neighbor_max_row1_r <= 8'd0;
            s2_neighbor_max_row2_r <= 8'd0;
            s2_neighbor_sum_r <= 12'd0;
            s2_x_r <= 11'd0;
            s2_y_r <= 11'd0;
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        out_vld <= 1'b0;
        out_center <= 8'd0;
        out_filtered <= 8'd0;
        out_spread <= 8'd0;
        out_neighbor_mean <= 8'd0;
        out_neighbor_spread <= 8'd0;
        out_x <= 11'd0;
        out_y <= 11'd0;
    end else if (frame_clr) begin
        out_vld <= 1'b0;
        out_center <= 8'd0;
        out_filtered <= 8'd0;
        out_spread <= 8'd0;
        out_neighbor_mean <= 8'd0;
        out_neighbor_spread <= 8'd0;
        out_x <= 11'd0;
        out_y <= 11'd0;
    end else begin
        out_vld <= s2_vld_r;
        if (s2_vld_r) begin
            out_center <= s2_center_r;
            out_filtered <= filtered_px_w;
            out_spread <= spread_w;
            out_neighbor_mean <= neighbor_mean_w;
            out_neighbor_spread <= neighbor_spread_w;
            out_x <= s2_x_r;
            out_y <= s2_y_r;
        end else begin
            out_center <= 8'd0;
            out_filtered <= 8'd0;
            out_spread <= 8'd0;
            out_neighbor_mean <= 8'd0;
            out_neighbor_spread <= 8'd0;
            out_x <= 11'd0;
            out_y <= 11'd0;
        end
    end
end

endmodule
