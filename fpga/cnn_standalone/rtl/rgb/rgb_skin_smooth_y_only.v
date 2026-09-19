module rgb_skin_smooth_y_only
#(
    parameter H_DISP = 1280,
    parameter V_DISP = 720,
    parameter integer BORDER_BYPASS_PX = 2
)
(
    input   wire            clk,
    input   wire            rst_n,
    input   wire            frame_clr,
    input   wire            in_de,
    input   wire    [23:0]  in_rgb,
    input   wire    [1:0]   cfg_runtime_skin_level_sel,

    output  wire            out_de,
    output  wire    [23:0]  out_rgb
);

localparam [1:0] SKIN_LEVEL_OFF      = 2'd0;
localparam [1:0] SKIN_LEVEL_STRONG   = 2'd1;
localparam [1:0] SKIN_LEVEL_VERYHIGH = 2'd2;
localparam integer SKIN_OFF_FIFO_DEPTH = 64;
localparam integer SKIN_OFF_FIFO_AW = 6;
localparam [SKIN_OFF_FIFO_AW-1:0] METRIC_RGB_LOOKAHEAD = 6'd5;
localparam [SKIN_OFF_FIFO_AW-1:0] METRIC_RGB_PIPE_AHEAD = 6'd2;
localparam [SKIN_OFF_FIFO_AW-1:0] METRIC_RGB_READ_AHEAD =
    METRIC_RGB_LOOKAHEAD + METRIC_RGB_PIPE_AHEAD;
localparam [10:0] STARTUP_BYPASS_LEFT_PX = 11'd13;
localparam [10:0] STARTUP_BYPASS_TOP_PX = 11'd11;

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

function [7:0] abs_diff_u8;
    input [7:0] a;
    input [7:0] b;
    begin
        abs_diff_u8 = (a >= b) ? (a - b) : (b - a);
    end
endfunction

function [7:0] gate_level1_q8;
    input [7:0] spread;
    begin
        if (spread <= 8'd6)
            gate_level1_q8 = 8'd255;
        else if (spread <= 8'd10)
            gate_level1_q8 = 8'd192;
        else if (spread <= 8'd14)
            gate_level1_q8 = 8'd128;
        else if (spread <= 8'd18)
            gate_level1_q8 = 8'd64;
        else
            gate_level1_q8 = 8'd0;
    end
endfunction

function [7:0] gate_level2_q8;
    input [7:0] spread;
    begin
        if (spread <= 8'd6)
            gate_level2_q8 = 8'd255;
        else if (spread <= 8'd10)
            gate_level2_q8 = 8'd192;
        else if (spread <= 8'd14)
            gate_level2_q8 = 8'd128;
        else if (spread <= 8'd18)
            gate_level2_q8 = 8'd64;
        else
            gate_level2_q8 = 8'd0;
    end
endfunction

function signed [8:0] clamp_delta_level1;
    input signed [8:0] value;
    begin
        if (value < -9'sd10)
            clamp_delta_level1 = -9'sd10;
        else if (value > 9'sd10)
            clamp_delta_level1 = 9'sd10;
        else
            clamp_delta_level1 = value;
    end
endfunction

function signed [8:0] clamp_delta_level1_edge;
    input signed [8:0] value;
    begin
        if (value < -9'sd4)
            clamp_delta_level1_edge = -9'sd4;
        else if (value > 9'sd4)
            clamp_delta_level1_edge = 9'sd4;
        else
            clamp_delta_level1_edge = value;
    end
endfunction

function signed [8:0] clamp_delta_level2;
    input signed [8:0] value;
    begin
        if (value < -9'sd16)
            clamp_delta_level2 = -9'sd16;
        else if (value > 9'sd16)
            clamp_delta_level2 = 9'sd16;
        else
            clamp_delta_level2 = value;
    end
endfunction

function signed [8:0] clamp_delta_level2_edge;
    input signed [8:0] value;
    begin
        if (value < -9'sd6)
            clamp_delta_level2_edge = -9'sd6;
        else if (value > 9'sd6)
            clamp_delta_level2_edge = 9'sd6;
        else
            clamp_delta_level2_edge = value;
    end
endfunction

function [8:0] abs_s9;
    input signed [8:0] value;
    begin
        abs_s9 = value[8] ? -value : value;
    end
endfunction

wire [7:0] in_r_w = in_rgb[23:16];
wire [7:0] in_g_w = in_rgb[15:8];
wire [7:0] in_b_w = in_rgb[7:0];

wire [15:0] in_r_y_w = in_r_w * 8'd77;
wire [15:0] in_g_y_w = in_g_w * 8'd150;
wire [15:0] in_b_y_w = in_b_w * 8'd29;
wire [15:0] in_y_acc_w = in_r_y_w + in_g_y_w + in_b_y_w;
wire [7:0]  in_y_w = in_y_acc_w[15:8];

wire        y_b1_de_w;
wire [7:0]  y_b1_center_w;
wire [7:0]  y_b1_filtered_w;
wire [7:0]  y_b1_spread_w;
wire        y_b7_de_w;
wire [7:0]  y_b7_filtered_w;
wire        level1_spread_de_w;
wire [7:0]  level1_spread_w;
wire        level1_spread_align_de_w;
wire [7:0]  level1_spread_align_w;
wire        rgb_core_de_s1_w;
wire [23:0] rgb_core_s1_w;
wire        rgb_core_de_w;
wire [23:0] rgb_core_w;
wire        rgb_core_align_de_w;

reg  [3:0]  level1_spread_de_pipe_r;
reg  [7:0]  level1_spread_pipe0_r;
reg  [7:0]  level1_spread_pipe1_r;
reg  [7:0]  level1_spread_pipe2_r;
reg  [7:0]  level1_spread_pipe3_r;
reg  [5:0]  rgb_core_de_pipe_r;
reg  [5:0]  y_b7_de_pipe_r;
reg  [7:0]  y_b7_pipe0_r;
reg  [7:0]  y_b7_pipe1_r;
reg  [7:0]  y_b7_pipe2_r;
reg  [7:0]  y_b7_pipe3_r;
reg  [7:0]  y_b7_pipe4_r;
reg  [7:0]  y_b7_pipe5_r;
reg         metric_de_r;
reg  [23:0] metric_rgb_r;
reg  [7:0]  metric_level1_filtered_r;
reg  [7:0]  metric_level2_filtered_r;
reg  [7:0]  metric_level1_spread_r;
(* preserve, syn_preserve = 1 *) reg         metric_req_de_r;
(* preserve, syn_preserve = 1 *) reg         metric_req_ready_r;
reg  [7:0]  metric_level1_filtered_req_r;
reg  [7:0]  metric_level2_filtered_req_r;
reg  [7:0]  metric_level1_spread_req_r;
(* preserve, syn_preserve = 1 *) reg         metric_rgb_fetch_de_r;
(* preserve, syn_preserve = 1 *) reg         metric_rgb_fetch_ready_r;
(* preserve, syn_preserve = 1 *) reg  [23:0] metric_rgb_fetch_r;
reg  [7:0]  metric_level1_filtered_fetch_r;
reg  [7:0]  metric_level2_filtered_fetch_r;
reg  [7:0]  metric_level1_spread_fetch_r;

reg         metric_mul_de_r;
reg  [23:0] metric_mul_rgb_r;
reg  [7:0]  metric_mul_level1_filtered_r;
reg  [7:0]  metric_mul_level2_filtered_r;
reg  [7:0]  metric_mul_level1_spread_r;
reg  [15:0] metric_r_y_mul_r;
reg  [15:0] metric_g_y_mul_r;
reg  [15:0] metric_b_y_mul_r;
reg  [15:0] metric_r_cb_mul_r;
reg  [15:0] metric_g_cb_mul_r;
reg  [15:0] metric_b_cb_mul_r;
reg  [15:0] metric_r_cr_mul_r;
reg  [15:0] metric_g_cr_mul_r;
reg  [15:0] metric_b_cr_mul_r;

reg         align_de_r;
reg  [23:0] align_rgb_r;
reg  [7:0]  align_y_r;
reg  [7:0]  align_cb_r;
reg  [7:0]  align_cr_r;
reg  [7:0]  level1_filtered_r;
reg  [7:0]  level2_filtered_r;
reg  [7:0]  level1_spread_r;

reg         skin_abs_de_r;
reg  [23:0] skin_abs_rgb_r;
reg  [7:0]  skin_abs_y_r;
reg  [7:0]  skin_abs_cb_r;
reg  [7:0]  skin_abs_cr_r;
reg  [7:0]  skin_abs_level1_filtered_r;
reg  [7:0]  skin_abs_level2_filtered_r;
reg  [7:0]  skin_abs_level1_spread_r;
reg  signed [8:0] skin_abs_warm_diff_r;
reg  [7:0]  skin_abs_cb_abs_r;
reg  [7:0]  skin_abs_cr_abs_r;

reg         skin_cmp_de_r;
reg  [23:0] skin_cmp_rgb_r;
reg  [7:0]  skin_cmp_y_r;
reg  [7:0]  skin_cmp_cb_r;
reg  [7:0]  skin_cmp_cr_r;
reg  [7:0]  skin_cmp_level1_filtered_r;
reg  [7:0]  skin_cmp_level2_filtered_r;
reg  [7:0]  skin_cmp_level1_spread_r;
reg  signed [8:0] skin_cmp_warm_diff_r;
reg  [8:0]  skin_cmp_sat_sum_r;

reg         skin_match_de_r;
reg  [23:0] skin_match_rgb_r;
reg  signed [8:0] skin_match_delta_raw_r;
reg  [7:0]  skin_match_detail_gate_r;
reg         skin_match_hit_r;
reg  [23:0] skin_match_bypass_rgb_r;
reg         skin_match_startup_bypass_r;
reg         skin_match_level_off_r;

reg         alpha_base_de_r;
reg  [23:0] alpha_base_rgb_r;
reg  signed [8:0] alpha_base_delta_r;
reg  [7:0]  alpha_base_alpha_r;
reg  [7:0]  alpha_base_detail_gate_r;
reg  [23:0] alpha_base_bypass_rgb_r;
reg         alpha_base_startup_bypass_r;
reg         alpha_base_level_off_r;

reg         alpha_mul_de_r;
reg  [23:0] alpha_mul_rgb_r;
reg  signed [8:0] alpha_mul_delta_r;
reg  [16:0] alpha_gate_mul_r;
reg  [23:0] alpha_mul_bypass_rgb_r;
reg         alpha_mul_startup_bypass_r;
reg         alpha_mul_level_off_r;

reg         match_de_r;
reg  [23:0] match_rgb_r;
reg  signed [8:0] match_delta_y_r;
reg  [7:0]  match_alpha_r;
reg  [23:0] match_bypass_rgb_r;
reg         match_startup_bypass_r;
reg         match_level_off_r;

reg         blend_de_s0_r;
reg  [23:0] blend_rgb_s0_r;
reg  signed [8:0] blend_delta_y_s0_r;
reg  [7:0]  blend_alpha_s0_r;
reg  [23:0] blend_bypass_rgb_s0_r;
reg         startup_bypass_s0_r;
reg         skin_level_off_s0_r;

reg         blend_de_s1_r;
reg  [23:0] blend_rgb_s1_r;
reg  signed [17:0] blend_mul_s1_r;
reg  [23:0] blend_bypass_rgb_s1_r;
reg         startup_bypass_s1_r;
reg         skin_level_off_s1_r;

reg         blend_de_s2_r;
reg  [23:0] blend_rgb_s2_r;
reg  [23:0] blend_bypass_rgb_s2_r;
reg  signed [17:0] blend_round_s2_r;
reg         startup_bypass_s2_r;
reg         skin_level_off_s2_r;

reg         blend_de_s3_r;
reg  [23:0] blend_rgb_s3_r;
reg  [23:0] blend_bypass_rgb_s3_r;
reg  signed [9:0] blend_delta_apply_s3_r;
reg         startup_bypass_s3_r;
reg         skin_level_off_s3_r;

reg         blend_de_s4_r;
reg  signed [19:0] blend_r_sum_s4_r;
reg  signed [19:0] blend_g_sum_s4_r;
reg  signed [19:0] blend_b_sum_s4_r;
reg  [23:0] blend_bypass_rgb_s4_r;
reg         startup_bypass_s4_r;
reg         skin_level_off_s4_r;

reg         blend_de_s5_r;
reg  [23:0] blend_rgb_s5_r;
reg  [23:0] blend_bypass_rgb_s5_r;
reg         startup_bypass_s5_r;
reg         skin_level_off_s5_r;

reg         out_de_r;
reg  [23:0] out_rgb_r;
reg  [10:0] out_x_r;
reg  [10:0] out_y_r;
reg  [SKIN_OFF_FIFO_AW-1:0] skin_off_wr_ptr_r;
reg  [SKIN_OFF_FIFO_AW-1:0] skin_off_rd_ptr_r;
reg  [SKIN_OFF_FIFO_AW:0] skin_off_level_r;

wire skin_off_fifo_empty_w = (skin_off_level_r == {(SKIN_OFF_FIFO_AW + 1){1'b0}});
wire skin_off_pop_w = skin_cmp_de_r && !skin_off_fifo_empty_w;
wire [SKIN_OFF_FIFO_AW-1:0] skin_off_head_addr_w =
    skin_off_rd_ptr_r + (skin_off_pop_w ? {{(SKIN_OFF_FIFO_AW-1){1'b0}}, 1'b1}
                                         : {SKIN_OFF_FIFO_AW{1'b0}});
wire [23:0] skin_off_rgb_head_w;
wire [23:0] current_rgb_w = skin_off_fifo_empty_w ? 24'd0 : skin_off_rgb_head_w;
wire metric_rgb_ready_w = (skin_off_level_r > {1'b0, METRIC_RGB_READ_AHEAD});
wire y_b7_align_de_w = y_b7_de_pipe_r[5];
wire [7:0] y_b7_align_w = y_b7_align_de_w ? y_b7_pipe5_r : 8'd0;
wire metric_sample_de_w =
    rgb_core_align_de_w && y_b7_align_de_w && level1_spread_align_de_w;
wire [SKIN_OFF_FIFO_AW-1:0] metric_rgb_rd_ptr_next_w = skin_off_rd_ptr_r + METRIC_RGB_READ_AHEAD;
wire [23:0] metric_rgb_read_w;
wire [7:0] metric_r_w = metric_rgb_r[23:16];
wire [7:0] metric_g_w = metric_rgb_r[15:8];
wire [7:0] metric_b_w = metric_rgb_r[7:0];
wire [15:0] metric_r_y_w  = metric_r_w * 8'd77;
wire [15:0] metric_g_y_w  = metric_g_w * 8'd150;
wire [15:0] metric_b_y_w  = metric_b_w * 8'd29;
wire [15:0] metric_r_cb_w = metric_r_w * 8'd43;
wire [15:0] metric_g_cb_w = metric_g_w * 8'd85;
wire [15:0] metric_b_cb_w = metric_b_w << 7;
wire [15:0] metric_r_cr_w = metric_r_w << 7;
wire [15:0] metric_g_cr_w = metric_g_w * 8'd107;
wire [15:0] metric_b_cr_w = metric_b_w * 8'd21;
wire [15:0] metric_y_acc_w =
    metric_r_y_mul_r + metric_g_y_mul_r + metric_b_y_mul_r;
wire signed [17:0] metric_cb_acc_w =
    $signed({2'b00, metric_b_cb_mul_r}) -
    $signed({2'b00, metric_r_cb_mul_r}) -
    $signed({2'b00, metric_g_cb_mul_r}) +
    18'sd32768;
wire signed [17:0] metric_cr_acc_w =
    $signed({2'b00, metric_r_cr_mul_r}) -
    $signed({2'b00, metric_g_cr_mul_r}) -
    $signed({2'b00, metric_b_cr_mul_r}) +
    18'sd32768;

wire level1_sel_w = (cfg_runtime_skin_level_sel == SKIN_LEVEL_STRONG);
wire level2_sel_w = (cfg_runtime_skin_level_sel == SKIN_LEVEL_VERYHIGH);
wire skin_match_hit_w =
    (skin_cmp_y_r >= 8'd12) && (skin_cmp_y_r <= 8'd236) &&
    (skin_cmp_cb_r >= 8'd92) && (skin_cmp_cb_r <= 8'd140) &&
    (skin_cmp_cr_r >= 8'd118) && (skin_cmp_cr_r <= 8'd170) &&
    (skin_cmp_warm_diff_r >= -9'sd4) && (skin_cmp_warm_diff_r <= 9'sd48) &&
    (skin_cmp_sat_sum_r <= 9'd60) &&
    (skin_cmp_y_r >= 8'd26);
wire [7:0] skin_detail_gate_w =
    level1_sel_w ? gate_level1_q8(skin_cmp_level1_spread_r) :
    (level2_sel_w ? gate_level2_q8(skin_cmp_level1_spread_r) : 8'd0);
wire [7:0] skin_target_y_w =
    level1_sel_w ? skin_cmp_level1_filtered_r :
    (level2_sel_w ? skin_cmp_level2_filtered_r : skin_cmp_y_r);
wire signed [8:0] skin_delta_raw_w =
    $signed({1'b0, skin_target_y_w}) - $signed({1'b0, skin_cmp_y_r});
wire [8:0] delta_abs_w = abs_s9(skin_match_delta_raw_r);
wire level1_edge_delta_w = level1_sel_w && (delta_abs_w > 9'd8);
wire level2_edge_delta_w = level2_sel_w && (delta_abs_w > 9'd10);
wire edge_delta_w = level1_edge_delta_w || level2_edge_delta_w;
wire [7:0] alpha_nominal_w =
    level1_sel_w ? (skin_match_hit_r ? 8'd72 : 8'd21) :
    (level2_sel_w ? (skin_match_hit_r ? 8'd141 : 8'd38) : 8'd0);
wire [7:0] alpha_edge_limit_w =
    level1_sel_w ? 8'd8 :
    (level2_sel_w ? 8'd16 : 8'd0);
wire [7:0] alpha_base_w =
    (edge_delta_w && (alpha_nominal_w > alpha_edge_limit_w)) ? alpha_edge_limit_w : alpha_nominal_w;
wire signed [8:0] delta_raw_w =
    skin_match_delta_raw_r;
wire signed [8:0] delta_clamped_w =
    level1_sel_w ? (level1_edge_delta_w ? clamp_delta_level1_edge(delta_raw_w) : clamp_delta_level1(delta_raw_w)) :
    (level2_sel_w ? (level2_edge_delta_w ? clamp_delta_level2_edge(delta_raw_w) : clamp_delta_level2(delta_raw_w)) : 9'sd0);
wire [7:0] alpha_gated_w = (alpha_gate_mul_r + 17'd128) >> 8;
wire signed [17:0] blend_mul_s1_w =
    blend_delta_y_s0_r * $signed({1'b0, blend_alpha_s0_r});
wire signed [9:0] blend_delta_apply_s3_w = blend_round_s2_r >>> 8;
wire [7:0] out_r_w = clip_u8(blend_r_sum_s4_r);
wire [7:0] out_g_w = clip_u8(blend_g_sum_s4_r);
wire [7:0] out_b_w = clip_u8(blend_b_sum_s4_r);
wire startup_bypass_w =
    (cfg_runtime_skin_level_sel != SKIN_LEVEL_OFF) &&
    ((out_x_r < STARTUP_BYPASS_LEFT_PX) || (out_y_r < STARTUP_BYPASS_TOP_PX));

// Two mirrored M4Ks provide the FIFO's two independent read addresses. The
// registered port-B address is anticipated by one cycle, preserving the
// existing metric-fetch and bypass timing without a 64:1 asynchronous mux.
altsyncram u_skin_off_head_ram (
    .wren_a        (in_de),
    .wren_b        (1'b0),
    .clock0        (clk),
    .clock1        (1'b1),
    .address_a     (skin_off_wr_ptr_r),
    .address_b     (skin_off_head_addr_w),
    .data_a        (in_rgb),
    .data_b        ({24{1'b1}}),
    .q_b           (skin_off_rgb_head_w),
    .q_a           (),
    .aclr0         (1'b0),
    .aclr1         (1'b0),
    .addressstall_a(1'b0),
    .addressstall_b(1'b0),
    .byteena_a     (1'b1),
    .byteena_b     (1'b1),
    .clocken0      (1'b1),
    .clocken1      (1'b1),
    .clocken2      (1'b1),
    .clocken3      (1'b1),
    .eccstatus     (),
    .rden_a        (1'b1),
    .rden_b        (1'b1)
);

altsyncram u_skin_off_metric_ram (
    .wren_a        (in_de),
    .wren_b        (1'b0),
    .clock0        (clk),
    .clock1        (1'b1),
    .address_a     (skin_off_wr_ptr_r),
    .address_b     (metric_rgb_rd_ptr_next_w),
    .data_a        (in_rgb),
    .data_b        ({24{1'b1}}),
    .q_b           (metric_rgb_read_w),
    .q_a           (),
    .aclr0         (1'b0),
    .aclr1         (1'b0),
    .addressstall_a(1'b0),
    .addressstall_b(1'b0),
    .byteena_a     (1'b1),
    .byteena_b     (1'b1),
    .clocken0      (1'b1),
    .clocken1      (1'b1),
    .clocken2      (1'b1),
    .clocken3      (1'b1),
    .eccstatus     (),
    .rden_a        (1'b1),
    .rden_b        (1'b1)
);

defparam
    u_skin_off_head_ram.address_aclr_a = "NONE",
    u_skin_off_head_ram.address_aclr_b = "NONE",
    u_skin_off_head_ram.address_reg_b = "CLOCK0",
    u_skin_off_head_ram.indata_aclr_a = "NONE",
    u_skin_off_head_ram.intended_device_family = "Stratix",
    u_skin_off_head_ram.lpm_type = "altsyncram",
    u_skin_off_head_ram.numwords_a = SKIN_OFF_FIFO_DEPTH,
    u_skin_off_head_ram.numwords_b = SKIN_OFF_FIFO_DEPTH,
    u_skin_off_head_ram.operation_mode = "DUAL_PORT",
    u_skin_off_head_ram.outdata_aclr_b = "NONE",
    u_skin_off_head_ram.outdata_reg_b = "UNREGISTERED",
    u_skin_off_head_ram.power_up_uninitialized = "TRUE",
    u_skin_off_head_ram.ram_block_type = "M4K",
    u_skin_off_head_ram.read_during_write_mode_mixed_ports = "OLD_DATA",
    u_skin_off_head_ram.widthad_a = SKIN_OFF_FIFO_AW,
    u_skin_off_head_ram.widthad_b = SKIN_OFF_FIFO_AW,
    u_skin_off_head_ram.width_a = 24,
    u_skin_off_head_ram.width_b = 24,
    u_skin_off_head_ram.width_byteena_a = 1,
    u_skin_off_head_ram.init_file = "UNUSED",
    u_skin_off_head_ram.wrcontrol_aclr_a = "NONE";

defparam
    u_skin_off_metric_ram.address_aclr_a = "NONE",
    u_skin_off_metric_ram.address_aclr_b = "NONE",
    u_skin_off_metric_ram.address_reg_b = "CLOCK0",
    u_skin_off_metric_ram.indata_aclr_a = "NONE",
    u_skin_off_metric_ram.intended_device_family = "Stratix",
    u_skin_off_metric_ram.lpm_type = "altsyncram",
    u_skin_off_metric_ram.numwords_a = SKIN_OFF_FIFO_DEPTH,
    u_skin_off_metric_ram.numwords_b = SKIN_OFF_FIFO_DEPTH,
    u_skin_off_metric_ram.operation_mode = "DUAL_PORT",
    u_skin_off_metric_ram.outdata_aclr_b = "NONE",
    u_skin_off_metric_ram.outdata_reg_b = "UNREGISTERED",
    u_skin_off_metric_ram.power_up_uninitialized = "TRUE",
    u_skin_off_metric_ram.ram_block_type = "M4K",
    u_skin_off_metric_ram.read_during_write_mode_mixed_ports = "OLD_DATA",
    u_skin_off_metric_ram.widthad_a = SKIN_OFF_FIFO_AW,
    u_skin_off_metric_ram.widthad_b = SKIN_OFF_FIFO_AW,
    u_skin_off_metric_ram.width_a = 24,
    u_skin_off_metric_ram.width_b = 24,
    u_skin_off_metric_ram.width_byteena_a = 1,
    u_skin_off_metric_ram.init_file = "UNUSED",
    u_skin_off_metric_ram.wrcontrol_aclr_a = "NONE";

stream_plane_box3x3_stats
#(
    .H_DISP(H_DISP),
    .V_DISP(V_DISP)
)
u_skin_y_box_1
(
    .clk         (clk),
    .rst_n       (rst_n),
    .frame_clr   (frame_clr),
    .din_vld     (in_de),
    .din         (in_y_w),
    .out_vld     (y_b1_de_w),
    .out_center  (y_b1_center_w),
    .out_filtered(y_b1_filtered_w),
    .out_spread  (y_b1_spread_w)
);

stream_plane_box7x7_mean
#(
    .H_DISP(H_DISP),
    .V_DISP(V_DISP)
)
u_skin_y_box_7
(
    .clk         (clk),
    .rst_n       (rst_n),
    .frame_clr   (frame_clr),
    .din_vld     (in_de),
    .din         (in_y_w),
    .out_vld     (y_b7_de_w),
    .out_filtered(y_b7_filtered_w)
);

stream_rgb_center_delay_3x3
#(
    .H_DISP(H_DISP),
    .V_DISP(V_DISP)
)
u_skin_rgb_delay1
(
    .clk            (clk),
    .rst_n          (rst_n),
    .frame_clr      (frame_clr),
    .din_vld        (in_de),
    .din_rgb        (in_rgb),
    .out_vld        (rgb_core_de_s1_w),
    .out_center_rgb (rgb_core_s1_w)
);

stream_rgb_delay2_3x3
#(
    .H_DISP(H_DISP),
    .V_DISP(V_DISP)
)
u_skin_rgb_delay2
(
    .clk            (clk),
    .rst_n          (rst_n),
    .frame_clr      (frame_clr),
    .din_vld        (rgb_core_de_s1_w),
    .din_rgb        (rgb_core_s1_w),
    .out_vld        (rgb_core_de_w),
    .out_center_rgb (rgb_core_w)
);

stream_plane_delay2_3x3
#(
    .H_DISP(H_DISP),
    .V_DISP(V_DISP)
)
u_skin_level1_spread_delay2
(
    .clk        (clk),
    .rst_n      (rst_n),
    .frame_clr  (frame_clr),
    .din_vld    (y_b1_de_w),
    .din        (y_b1_spread_w),
    .out_vld    (level1_spread_de_w),
    .out_center (level1_spread_w)
);

assign level1_spread_align_de_w = level1_spread_de_pipe_r[3];
assign level1_spread_align_w = level1_spread_de_pipe_r[3] ? level1_spread_pipe3_r : 8'd0;
assign rgb_core_align_de_w = rgb_core_de_pipe_r[5];

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        level1_spread_de_pipe_r <= 4'd0;
        level1_spread_pipe0_r <= 8'd0;
        level1_spread_pipe1_r <= 8'd0;
        level1_spread_pipe2_r <= 8'd0;
        level1_spread_pipe3_r <= 8'd0;
        rgb_core_de_pipe_r <= 6'd0;
        y_b7_de_pipe_r <= 6'd0;
        y_b7_pipe0_r <= 8'd0;
        y_b7_pipe1_r <= 8'd0;
        y_b7_pipe2_r <= 8'd0;
        y_b7_pipe3_r <= 8'd0;
        y_b7_pipe4_r <= 8'd0;
        y_b7_pipe5_r <= 8'd0;
        metric_de_r <= 1'b0;
        metric_rgb_r <= 24'd0;
        metric_level1_filtered_r <= 8'd0;
        metric_level2_filtered_r <= 8'd0;
        metric_level1_spread_r <= 8'd0;
        metric_req_de_r <= 1'b0;
        metric_req_ready_r <= 1'b0;
        metric_level1_filtered_req_r <= 8'd0;
        metric_level2_filtered_req_r <= 8'd0;
        metric_level1_spread_req_r <= 8'd0;
        metric_rgb_fetch_de_r <= 1'b0;
        metric_rgb_fetch_ready_r <= 1'b0;
        metric_rgb_fetch_r <= 24'd0;
        metric_level1_filtered_fetch_r <= 8'd0;
        metric_level2_filtered_fetch_r <= 8'd0;
        metric_level1_spread_fetch_r <= 8'd0;
        metric_mul_de_r <= 1'b0;
        metric_mul_rgb_r <= 24'd0;
        metric_mul_level1_filtered_r <= 8'd0;
        metric_mul_level2_filtered_r <= 8'd0;
        metric_mul_level1_spread_r <= 8'd0;
        metric_r_y_mul_r <= 16'd0;
        metric_g_y_mul_r <= 16'd0;
        metric_b_y_mul_r <= 16'd0;
        metric_r_cb_mul_r <= 16'd0;
        metric_g_cb_mul_r <= 16'd0;
        metric_b_cb_mul_r <= 16'd0;
        metric_r_cr_mul_r <= 16'd0;
        metric_g_cr_mul_r <= 16'd0;
        metric_b_cr_mul_r <= 16'd0;
        align_de_r <= 1'b0;
        align_rgb_r <= 24'd0;
        align_y_r <= 8'd0;
        align_cb_r <= 8'd0;
        align_cr_r <= 8'd0;
        level1_filtered_r <= 8'd0;
        level2_filtered_r <= 8'd0;
        level1_spread_r <= 8'd0;
        skin_abs_de_r <= 1'b0;
        skin_abs_rgb_r <= 24'd0;
        skin_abs_y_r <= 8'd0;
        skin_abs_cb_r <= 8'd0;
        skin_abs_cr_r <= 8'd0;
        skin_abs_level1_filtered_r <= 8'd0;
        skin_abs_level2_filtered_r <= 8'd0;
        skin_abs_level1_spread_r <= 8'd0;
        skin_abs_warm_diff_r <= 9'sd0;
        skin_abs_cb_abs_r <= 8'd0;
        skin_abs_cr_abs_r <= 8'd0;
        skin_cmp_de_r <= 1'b0;
        skin_cmp_rgb_r <= 24'd0;
        skin_cmp_y_r <= 8'd0;
        skin_cmp_cb_r <= 8'd0;
        skin_cmp_cr_r <= 8'd0;
        skin_cmp_level1_filtered_r <= 8'd0;
        skin_cmp_level2_filtered_r <= 8'd0;
        skin_cmp_level1_spread_r <= 8'd0;
        skin_cmp_warm_diff_r <= 9'sd0;
        skin_cmp_sat_sum_r <= 9'd0;
        skin_match_de_r <= 1'b0;
        skin_match_rgb_r <= 24'd0;
        skin_match_delta_raw_r <= 9'sd0;
        skin_match_detail_gate_r <= 8'd0;
        skin_match_hit_r <= 1'b0;
        skin_match_bypass_rgb_r <= 24'd0;
        skin_match_startup_bypass_r <= 1'b0;
        skin_match_level_off_r <= 1'b0;
        alpha_base_de_r <= 1'b0;
        alpha_base_rgb_r <= 24'd0;
        alpha_base_delta_r <= 9'sd0;
        alpha_base_alpha_r <= 8'd0;
        alpha_base_detail_gate_r <= 8'd0;
        alpha_base_bypass_rgb_r <= 24'd0;
        alpha_base_startup_bypass_r <= 1'b0;
        alpha_base_level_off_r <= 1'b0;
        alpha_mul_de_r <= 1'b0;
        alpha_mul_rgb_r <= 24'd0;
        alpha_mul_delta_r <= 9'sd0;
        alpha_gate_mul_r <= 17'd0;
        alpha_mul_bypass_rgb_r <= 24'd0;
        alpha_mul_startup_bypass_r <= 1'b0;
        alpha_mul_level_off_r <= 1'b0;
        match_de_r <= 1'b0;
        match_rgb_r <= 24'd0;
        match_delta_y_r <= 9'sd0;
        match_alpha_r <= 8'd0;
        match_bypass_rgb_r <= 24'd0;
        match_startup_bypass_r <= 1'b0;
        match_level_off_r <= 1'b0;
        blend_de_s0_r <= 1'b0;
        blend_rgb_s0_r <= 24'd0;
        blend_delta_y_s0_r <= 9'sd0;
        blend_alpha_s0_r <= 8'd0;
        blend_bypass_rgb_s0_r <= 24'd0;
        startup_bypass_s0_r <= 1'b0;
        skin_level_off_s0_r <= 1'b0;
        blend_de_s1_r <= 1'b0;
        blend_rgb_s1_r <= 24'd0;
        blend_mul_s1_r <= 18'sd0;
        blend_bypass_rgb_s1_r <= 24'd0;
        startup_bypass_s1_r <= 1'b0;
        skin_level_off_s1_r <= 1'b0;
        blend_de_s2_r <= 1'b0;
        blend_rgb_s2_r <= 24'd0;
        blend_bypass_rgb_s2_r <= 24'd0;
        blend_round_s2_r <= 18'sd0;
        startup_bypass_s2_r <= 1'b0;
        skin_level_off_s2_r <= 1'b0;
        blend_de_s3_r <= 1'b0;
        blend_rgb_s3_r <= 24'd0;
        blend_bypass_rgb_s3_r <= 24'd0;
        blend_delta_apply_s3_r <= 10'sd0;
        startup_bypass_s3_r <= 1'b0;
        skin_level_off_s3_r <= 1'b0;
        blend_de_s4_r <= 1'b0;
        blend_r_sum_s4_r <= 20'sd0;
        blend_g_sum_s4_r <= 20'sd0;
        blend_b_sum_s4_r <= 20'sd0;
        blend_bypass_rgb_s4_r <= 24'd0;
        startup_bypass_s4_r <= 1'b0;
        skin_level_off_s4_r <= 1'b0;
        blend_de_s5_r <= 1'b0;
        blend_rgb_s5_r <= 24'd0;
        blend_bypass_rgb_s5_r <= 24'd0;
        startup_bypass_s5_r <= 1'b0;
        skin_level_off_s5_r <= 1'b0;
        out_de_r <= 1'b0;
        out_rgb_r <= 24'd0;
        out_x_r <= 11'd0;
        out_y_r <= 11'd0;
        skin_off_wr_ptr_r <= {SKIN_OFF_FIFO_AW{1'b0}};
        skin_off_rd_ptr_r <= {SKIN_OFF_FIFO_AW{1'b0}};
        skin_off_level_r <= {(SKIN_OFF_FIFO_AW + 1){1'b0}};
    end else if (frame_clr) begin
        level1_spread_de_pipe_r <= 4'd0;
        level1_spread_pipe0_r <= 8'd0;
        level1_spread_pipe1_r <= 8'd0;
        level1_spread_pipe2_r <= 8'd0;
        level1_spread_pipe3_r <= 8'd0;
        rgb_core_de_pipe_r <= 6'd0;
        y_b7_de_pipe_r <= 6'd0;
        y_b7_pipe0_r <= 8'd0;
        y_b7_pipe1_r <= 8'd0;
        y_b7_pipe2_r <= 8'd0;
        y_b7_pipe3_r <= 8'd0;
        y_b7_pipe4_r <= 8'd0;
        y_b7_pipe5_r <= 8'd0;
        metric_de_r <= 1'b0;
        metric_rgb_r <= 24'd0;
        metric_level1_filtered_r <= 8'd0;
        metric_level2_filtered_r <= 8'd0;
        metric_level1_spread_r <= 8'd0;
        metric_req_de_r <= 1'b0;
        metric_req_ready_r <= 1'b0;
        metric_level1_filtered_req_r <= 8'd0;
        metric_level2_filtered_req_r <= 8'd0;
        metric_level1_spread_req_r <= 8'd0;
        metric_rgb_fetch_de_r <= 1'b0;
        metric_rgb_fetch_ready_r <= 1'b0;
        metric_rgb_fetch_r <= 24'd0;
        metric_level1_filtered_fetch_r <= 8'd0;
        metric_level2_filtered_fetch_r <= 8'd0;
        metric_level1_spread_fetch_r <= 8'd0;
        metric_mul_de_r <= 1'b0;
        metric_mul_rgb_r <= 24'd0;
        metric_mul_level1_filtered_r <= 8'd0;
        metric_mul_level2_filtered_r <= 8'd0;
        metric_mul_level1_spread_r <= 8'd0;
        metric_r_y_mul_r <= 16'd0;
        metric_g_y_mul_r <= 16'd0;
        metric_b_y_mul_r <= 16'd0;
        metric_r_cb_mul_r <= 16'd0;
        metric_g_cb_mul_r <= 16'd0;
        metric_b_cb_mul_r <= 16'd0;
        metric_r_cr_mul_r <= 16'd0;
        metric_g_cr_mul_r <= 16'd0;
        metric_b_cr_mul_r <= 16'd0;
        align_de_r <= 1'b0;
        align_rgb_r <= 24'd0;
        align_y_r <= 8'd0;
        align_cb_r <= 8'd0;
        align_cr_r <= 8'd0;
        level1_filtered_r <= 8'd0;
        level2_filtered_r <= 8'd0;
        level1_spread_r <= 8'd0;
        skin_abs_de_r <= 1'b0;
        skin_abs_rgb_r <= 24'd0;
        skin_abs_y_r <= 8'd0;
        skin_abs_cb_r <= 8'd0;
        skin_abs_cr_r <= 8'd0;
        skin_abs_level1_filtered_r <= 8'd0;
        skin_abs_level2_filtered_r <= 8'd0;
        skin_abs_level1_spread_r <= 8'd0;
        skin_abs_warm_diff_r <= 9'sd0;
        skin_abs_cb_abs_r <= 8'd0;
        skin_abs_cr_abs_r <= 8'd0;
        skin_cmp_de_r <= 1'b0;
        skin_cmp_rgb_r <= 24'd0;
        skin_cmp_y_r <= 8'd0;
        skin_cmp_cb_r <= 8'd0;
        skin_cmp_cr_r <= 8'd0;
        skin_cmp_level1_filtered_r <= 8'd0;
        skin_cmp_level2_filtered_r <= 8'd0;
        skin_cmp_level1_spread_r <= 8'd0;
        skin_cmp_warm_diff_r <= 9'sd0;
        skin_cmp_sat_sum_r <= 9'd0;
        skin_match_de_r <= 1'b0;
        skin_match_rgb_r <= 24'd0;
        skin_match_delta_raw_r <= 9'sd0;
        skin_match_detail_gate_r <= 8'd0;
        skin_match_hit_r <= 1'b0;
        skin_match_bypass_rgb_r <= 24'd0;
        skin_match_startup_bypass_r <= 1'b0;
        skin_match_level_off_r <= 1'b0;
        alpha_base_de_r <= 1'b0;
        alpha_base_rgb_r <= 24'd0;
        alpha_base_delta_r <= 9'sd0;
        alpha_base_alpha_r <= 8'd0;
        alpha_base_detail_gate_r <= 8'd0;
        alpha_base_bypass_rgb_r <= 24'd0;
        alpha_base_startup_bypass_r <= 1'b0;
        alpha_base_level_off_r <= 1'b0;
        alpha_mul_de_r <= 1'b0;
        alpha_mul_rgb_r <= 24'd0;
        alpha_mul_delta_r <= 9'sd0;
        alpha_gate_mul_r <= 17'd0;
        alpha_mul_bypass_rgb_r <= 24'd0;
        alpha_mul_startup_bypass_r <= 1'b0;
        alpha_mul_level_off_r <= 1'b0;
        match_de_r <= 1'b0;
        match_rgb_r <= 24'd0;
        match_delta_y_r <= 9'sd0;
        match_alpha_r <= 8'd0;
        match_bypass_rgb_r <= 24'd0;
        match_startup_bypass_r <= 1'b0;
        match_level_off_r <= 1'b0;
        blend_de_s0_r <= 1'b0;
        blend_rgb_s0_r <= 24'd0;
        blend_delta_y_s0_r <= 9'sd0;
        blend_alpha_s0_r <= 8'd0;
        blend_bypass_rgb_s0_r <= 24'd0;
        startup_bypass_s0_r <= 1'b0;
        skin_level_off_s0_r <= 1'b0;
        blend_de_s1_r <= 1'b0;
        blend_rgb_s1_r <= 24'd0;
        blend_mul_s1_r <= 18'sd0;
        blend_bypass_rgb_s1_r <= 24'd0;
        startup_bypass_s1_r <= 1'b0;
        skin_level_off_s1_r <= 1'b0;
        blend_de_s2_r <= 1'b0;
        blend_rgb_s2_r <= 24'd0;
        blend_bypass_rgb_s2_r <= 24'd0;
        blend_round_s2_r <= 18'sd0;
        startup_bypass_s2_r <= 1'b0;
        skin_level_off_s2_r <= 1'b0;
        blend_de_s3_r <= 1'b0;
        blend_rgb_s3_r <= 24'd0;
        blend_bypass_rgb_s3_r <= 24'd0;
        blend_delta_apply_s3_r <= 10'sd0;
        startup_bypass_s3_r <= 1'b0;
        skin_level_off_s3_r <= 1'b0;
        blend_de_s4_r <= 1'b0;
        blend_r_sum_s4_r <= 20'sd0;
        blend_g_sum_s4_r <= 20'sd0;
        blend_b_sum_s4_r <= 20'sd0;
        blend_bypass_rgb_s4_r <= 24'd0;
        startup_bypass_s4_r <= 1'b0;
        skin_level_off_s4_r <= 1'b0;
        blend_de_s5_r <= 1'b0;
        blend_rgb_s5_r <= 24'd0;
        blend_bypass_rgb_s5_r <= 24'd0;
        startup_bypass_s5_r <= 1'b0;
        skin_level_off_s5_r <= 1'b0;
        out_de_r <= 1'b0;
        out_rgb_r <= 24'd0;
        out_x_r <= 11'd0;
        out_y_r <= 11'd0;
        skin_off_wr_ptr_r <= {SKIN_OFF_FIFO_AW{1'b0}};
        skin_off_rd_ptr_r <= {SKIN_OFF_FIFO_AW{1'b0}};
        skin_off_level_r <= {(SKIN_OFF_FIFO_AW + 1){1'b0}};
    end else begin
        if (in_de) begin
            skin_off_wr_ptr_r <= skin_off_wr_ptr_r + {{(SKIN_OFF_FIFO_AW-1){1'b0}}, 1'b1};
        end

        if (skin_cmp_de_r && !skin_off_fifo_empty_w)
            skin_off_rd_ptr_r <= skin_off_rd_ptr_r + {{(SKIN_OFF_FIFO_AW-1){1'b0}}, 1'b1};

        if (in_de && !(skin_cmp_de_r && !skin_off_fifo_empty_w))
            skin_off_level_r <= skin_off_level_r + {{SKIN_OFF_FIFO_AW{1'b0}}, 1'b1};
        else if (!in_de && (skin_cmp_de_r && !skin_off_fifo_empty_w))
            skin_off_level_r <= skin_off_level_r - {{SKIN_OFF_FIFO_AW{1'b0}}, 1'b1};

        level1_spread_de_pipe_r <= {level1_spread_de_pipe_r[2:0], level1_spread_de_w};
        level1_spread_pipe0_r <= level1_spread_de_w ? level1_spread_w : 8'd0;
        level1_spread_pipe1_r <= level1_spread_de_pipe_r[0] ? level1_spread_pipe0_r : 8'd0;
        level1_spread_pipe2_r <= level1_spread_de_pipe_r[1] ? level1_spread_pipe1_r : 8'd0;
        level1_spread_pipe3_r <= level1_spread_de_pipe_r[2] ? level1_spread_pipe2_r : 8'd0;
        rgb_core_de_pipe_r <= {rgb_core_de_pipe_r[4:0], rgb_core_de_w};
        y_b7_de_pipe_r <= {y_b7_de_pipe_r[4:0], y_b7_de_w};
        y_b7_pipe0_r <= y_b7_de_w ? y_b7_filtered_w : 8'd0;
        y_b7_pipe1_r <= y_b7_de_pipe_r[0] ? y_b7_pipe0_r : 8'd0;
        y_b7_pipe2_r <= y_b7_de_pipe_r[1] ? y_b7_pipe1_r : 8'd0;
        y_b7_pipe3_r <= y_b7_de_pipe_r[2] ? y_b7_pipe2_r : 8'd0;
        y_b7_pipe4_r <= y_b7_de_pipe_r[3] ? y_b7_pipe3_r : 8'd0;
        y_b7_pipe5_r <= y_b7_de_pipe_r[4] ? y_b7_pipe4_r : 8'd0;

        metric_req_de_r <= metric_sample_de_w;
        metric_req_ready_r <= metric_sample_de_w && metric_rgb_ready_w;
        if (metric_sample_de_w) begin
            metric_level1_filtered_req_r <= y_b7_align_w;
            metric_level2_filtered_req_r <= y_b7_align_w;
            metric_level1_spread_req_r <= level1_spread_align_w;
        end else begin
            metric_level1_filtered_req_r <= 8'd0;
            metric_level2_filtered_req_r <= 8'd0;
            metric_level1_spread_req_r <= 8'd0;
        end

        metric_rgb_fetch_de_r <= metric_req_de_r;
        metric_rgb_fetch_ready_r <= metric_req_de_r && metric_req_ready_r;
        if (metric_req_de_r) begin
            metric_rgb_fetch_r <= metric_req_ready_r ? metric_rgb_read_w : 24'd0;
            metric_level1_filtered_fetch_r <= metric_level1_filtered_req_r;
            metric_level2_filtered_fetch_r <= metric_level2_filtered_req_r;
            metric_level1_spread_fetch_r <= metric_level1_spread_req_r;
        end else begin
            metric_rgb_fetch_r <= 24'd0;
            metric_level1_filtered_fetch_r <= 8'd0;
            metric_level2_filtered_fetch_r <= 8'd0;
            metric_level1_spread_fetch_r <= 8'd0;
        end

        metric_de_r <= metric_rgb_fetch_de_r;
        if (metric_rgb_fetch_de_r) begin
            metric_rgb_r <= metric_rgb_fetch_ready_r ? metric_rgb_fetch_r : 24'd0;
            metric_level1_filtered_r <= metric_level1_filtered_fetch_r;
            metric_level2_filtered_r <= metric_level2_filtered_fetch_r;
            metric_level1_spread_r <= metric_level1_spread_fetch_r;
        end else begin
            metric_rgb_r <= 24'd0;
            metric_level1_filtered_r <= 8'd0;
            metric_level2_filtered_r <= 8'd0;
            metric_level1_spread_r <= 8'd0;
        end

        metric_mul_de_r <= metric_de_r;
        if (metric_de_r) begin
            metric_mul_rgb_r <= metric_rgb_r;
            metric_mul_level1_filtered_r <= metric_level1_filtered_r;
            metric_mul_level2_filtered_r <= metric_level2_filtered_r;
            metric_mul_level1_spread_r <= metric_level1_spread_r;
            metric_r_y_mul_r <= metric_r_y_w;
            metric_g_y_mul_r <= metric_g_y_w;
            metric_b_y_mul_r <= metric_b_y_w;
            metric_r_cb_mul_r <= metric_r_cb_w;
            metric_g_cb_mul_r <= metric_g_cb_w;
            metric_b_cb_mul_r <= metric_b_cb_w;
            metric_r_cr_mul_r <= metric_r_cr_w;
            metric_g_cr_mul_r <= metric_g_cr_w;
            metric_b_cr_mul_r <= metric_b_cr_w;
        end else begin
            metric_mul_rgb_r <= 24'd0;
            metric_mul_level1_filtered_r <= 8'd0;
            metric_mul_level2_filtered_r <= 8'd0;
            metric_mul_level1_spread_r <= 8'd0;
            metric_r_y_mul_r <= 16'd0;
            metric_g_y_mul_r <= 16'd0;
            metric_b_y_mul_r <= 16'd0;
            metric_r_cb_mul_r <= 16'd0;
            metric_g_cb_mul_r <= 16'd0;
            metric_b_cb_mul_r <= 16'd0;
            metric_r_cr_mul_r <= 16'd0;
            metric_g_cr_mul_r <= 16'd0;
            metric_b_cr_mul_r <= 16'd0;
        end

        align_de_r <= metric_mul_de_r;
        if (metric_mul_de_r) begin
            align_rgb_r <= metric_mul_rgb_r;
            align_y_r <= metric_y_acc_w[15:8];
            align_cb_r <= clip_u8(metric_cb_acc_w >>> 8);
            align_cr_r <= clip_u8(metric_cr_acc_w >>> 8);
            level1_filtered_r <= metric_mul_level1_filtered_r;
            level2_filtered_r <= metric_mul_level2_filtered_r;
            level1_spread_r <= metric_mul_level1_spread_r;
        end else begin
            align_rgb_r <= 24'd0;
            align_y_r <= 8'd0;
            align_cb_r <= 8'd0;
            align_cr_r <= 8'd0;
            level1_filtered_r <= 8'd0;
            level2_filtered_r <= 8'd0;
            level1_spread_r <= 8'd0;
        end

        skin_abs_de_r <= align_de_r;
        if (align_de_r) begin
            skin_abs_rgb_r <= align_rgb_r;
            skin_abs_y_r <= align_y_r;
            skin_abs_cb_r <= align_cb_r;
            skin_abs_cr_r <= align_cr_r;
            skin_abs_level1_filtered_r <= level1_filtered_r;
            skin_abs_level2_filtered_r <= level2_filtered_r;
            skin_abs_level1_spread_r <= level1_spread_r;
            skin_abs_warm_diff_r <= $signed({1'b0, align_cr_r}) - $signed({1'b0, align_cb_r});
            skin_abs_cb_abs_r <= abs_diff_u8(align_cb_r, 8'd128);
            skin_abs_cr_abs_r <= abs_diff_u8(align_cr_r, 8'd128);
        end else begin
            skin_abs_rgb_r <= 24'd0;
            skin_abs_y_r <= 8'd0;
            skin_abs_cb_r <= 8'd0;
            skin_abs_cr_r <= 8'd0;
            skin_abs_level1_filtered_r <= 8'd0;
            skin_abs_level2_filtered_r <= 8'd0;
            skin_abs_level1_spread_r <= 8'd0;
            skin_abs_warm_diff_r <= 9'sd0;
            skin_abs_cb_abs_r <= 8'd0;
            skin_abs_cr_abs_r <= 8'd0;
        end

        skin_cmp_de_r <= skin_abs_de_r;
        if (skin_abs_de_r) begin
            skin_cmp_rgb_r <= skin_abs_rgb_r;
            skin_cmp_y_r <= skin_abs_y_r;
            skin_cmp_cb_r <= skin_abs_cb_r;
            skin_cmp_cr_r <= skin_abs_cr_r;
            skin_cmp_level1_filtered_r <= skin_abs_level1_filtered_r;
            skin_cmp_level2_filtered_r <= skin_abs_level2_filtered_r;
            skin_cmp_level1_spread_r <= skin_abs_level1_spread_r;
            skin_cmp_warm_diff_r <= skin_abs_warm_diff_r;
            skin_cmp_sat_sum_r <= {1'b0, skin_abs_cb_abs_r} + {1'b0, skin_abs_cr_abs_r};
        end else begin
            skin_cmp_rgb_r <= 24'd0;
            skin_cmp_y_r <= 8'd0;
            skin_cmp_cb_r <= 8'd0;
            skin_cmp_cr_r <= 8'd0;
            skin_cmp_level1_filtered_r <= 8'd0;
            skin_cmp_level2_filtered_r <= 8'd0;
            skin_cmp_level1_spread_r <= 8'd0;
            skin_cmp_warm_diff_r <= 9'sd0;
            skin_cmp_sat_sum_r <= 9'd0;
        end

        skin_match_de_r <= skin_cmp_de_r;
        if (skin_cmp_de_r) begin
            skin_match_rgb_r <= skin_cmp_rgb_r;
            skin_match_delta_raw_r <= skin_delta_raw_w;
            skin_match_detail_gate_r <= skin_detail_gate_w;
            skin_match_hit_r <= skin_match_hit_w;
            skin_match_bypass_rgb_r <= current_rgb_w;
            skin_match_startup_bypass_r <= startup_bypass_w;
            skin_match_level_off_r <= (cfg_runtime_skin_level_sel == SKIN_LEVEL_OFF);
        end else begin
            skin_match_rgb_r <= 24'd0;
            skin_match_delta_raw_r <= 9'sd0;
            skin_match_detail_gate_r <= 8'd0;
            skin_match_hit_r <= 1'b0;
            skin_match_bypass_rgb_r <= 24'd0;
            skin_match_startup_bypass_r <= 1'b0;
            skin_match_level_off_r <= 1'b0;
        end

        alpha_base_de_r <= skin_match_de_r;
        if (skin_match_de_r) begin
            alpha_base_rgb_r <= skin_match_rgb_r;
            alpha_base_delta_r <= delta_clamped_w;
            alpha_base_alpha_r <= alpha_base_w;
            alpha_base_detail_gate_r <= skin_match_detail_gate_r;
            alpha_base_bypass_rgb_r <= skin_match_bypass_rgb_r;
            alpha_base_startup_bypass_r <= skin_match_startup_bypass_r;
            alpha_base_level_off_r <= skin_match_level_off_r;
        end else begin
            alpha_base_rgb_r <= 24'd0;
            alpha_base_delta_r <= 9'sd0;
            alpha_base_alpha_r <= 8'd0;
            alpha_base_detail_gate_r <= 8'd0;
            alpha_base_bypass_rgb_r <= 24'd0;
            alpha_base_startup_bypass_r <= 1'b0;
            alpha_base_level_off_r <= 1'b0;
        end

        alpha_mul_de_r <= alpha_base_de_r;
        if (alpha_base_de_r) begin
            alpha_mul_rgb_r <= alpha_base_rgb_r;
            alpha_mul_delta_r <= alpha_base_delta_r;
            alpha_gate_mul_r <= {9'd0, alpha_base_alpha_r} * {9'd0, alpha_base_detail_gate_r};
            alpha_mul_bypass_rgb_r <= alpha_base_bypass_rgb_r;
            alpha_mul_startup_bypass_r <= alpha_base_startup_bypass_r;
            alpha_mul_level_off_r <= alpha_base_level_off_r;
        end else begin
            alpha_mul_rgb_r <= 24'd0;
            alpha_mul_delta_r <= 9'sd0;
            alpha_gate_mul_r <= 17'd0;
            alpha_mul_bypass_rgb_r <= 24'd0;
            alpha_mul_startup_bypass_r <= 1'b0;
            alpha_mul_level_off_r <= 1'b0;
        end

        match_de_r <= alpha_mul_de_r;
        match_rgb_r <= alpha_mul_de_r ? alpha_mul_rgb_r : 24'd0;
        match_delta_y_r <= alpha_mul_delta_r;
        match_alpha_r <= alpha_gated_w;
        match_bypass_rgb_r <= alpha_mul_de_r ? alpha_mul_bypass_rgb_r : 24'd0;
        match_startup_bypass_r <= alpha_mul_de_r ? alpha_mul_startup_bypass_r : 1'b0;
        match_level_off_r <= alpha_mul_de_r ? alpha_mul_level_off_r : 1'b0;

        blend_de_s0_r <= match_de_r;
        blend_rgb_s0_r <= match_de_r ? match_rgb_r : 24'd0;
        blend_delta_y_s0_r <= match_delta_y_r;
        blend_alpha_s0_r <= match_alpha_r;
        blend_bypass_rgb_s0_r <= match_de_r ? match_bypass_rgb_r : 24'd0;
        startup_bypass_s0_r <= match_de_r ? match_startup_bypass_r : 1'b0;
        skin_level_off_s0_r <= match_de_r ? match_level_off_r : 1'b0;

        blend_de_s1_r <= blend_de_s0_r;
        blend_rgb_s1_r <= blend_de_s0_r ? blend_rgb_s0_r : 24'd0;
        blend_mul_s1_r <= blend_mul_s1_w;
        blend_bypass_rgb_s1_r <= blend_de_s0_r ? blend_bypass_rgb_s0_r : 24'd0;
        startup_bypass_s1_r <= blend_de_s0_r ? startup_bypass_s0_r : 1'b0;
        skin_level_off_s1_r <= blend_de_s0_r ? skin_level_off_s0_r : 1'b0;

        if (skin_cmp_de_r) begin
            if (out_x_r == H_DISP - 11'd1) begin
                out_x_r <= 11'd0;
                if (out_y_r == V_DISP - 11'd1)
                    out_y_r <= 11'd0;
                else
                    out_y_r <= out_y_r + 11'd1;
            end else begin
                out_x_r <= out_x_r + 11'd1;
            end
        end

        blend_de_s2_r <= blend_de_s1_r;
        blend_rgb_s2_r <= blend_de_s1_r ? blend_rgb_s1_r : 24'd0;
        blend_bypass_rgb_s2_r <= blend_de_s1_r ? blend_bypass_rgb_s1_r : 24'd0;
        blend_round_s2_r <= blend_mul_s1_r + ((blend_mul_s1_r >= 18'sd0) ? 18'sd128 : -18'sd128);
        startup_bypass_s2_r <= startup_bypass_s1_r;
        skin_level_off_s2_r <= skin_level_off_s1_r;

        blend_de_s3_r <= blend_de_s2_r;
        blend_rgb_s3_r <= blend_de_s2_r ? blend_rgb_s2_r : 24'd0;
        blend_bypass_rgb_s3_r <= blend_de_s2_r ? blend_bypass_rgb_s2_r : 24'd0;
        blend_delta_apply_s3_r <= blend_delta_apply_s3_w;
        startup_bypass_s3_r <= startup_bypass_s2_r;
        skin_level_off_s3_r <= skin_level_off_s2_r;

        blend_de_s4_r <= blend_de_s3_r;
        if (blend_de_s3_r) begin
            blend_r_sum_s4_r <= $signed({1'b0, blend_rgb_s3_r[23:16]}) + blend_delta_apply_s3_r;
            blend_g_sum_s4_r <= $signed({1'b0, blend_rgb_s3_r[15:8]}) + blend_delta_apply_s3_r;
            blend_b_sum_s4_r <= $signed({1'b0, blend_rgb_s3_r[7:0]}) + blend_delta_apply_s3_r;
            blend_bypass_rgb_s4_r <= blend_bypass_rgb_s3_r;
            startup_bypass_s4_r <= startup_bypass_s3_r;
            skin_level_off_s4_r <= skin_level_off_s3_r;
        end else begin
            blend_r_sum_s4_r <= 20'sd0;
            blend_g_sum_s4_r <= 20'sd0;
            blend_b_sum_s4_r <= 20'sd0;
            blend_bypass_rgb_s4_r <= 24'd0;
            startup_bypass_s4_r <= 1'b0;
            skin_level_off_s4_r <= 1'b0;
        end

        blend_de_s5_r <= blend_de_s4_r;
        if (blend_de_s4_r) begin
            blend_rgb_s5_r <= {out_r_w, out_g_w, out_b_w};
            blend_bypass_rgb_s5_r <= blend_bypass_rgb_s4_r;
            startup_bypass_s5_r <= startup_bypass_s4_r;
            skin_level_off_s5_r <= skin_level_off_s4_r;
        end else begin
            blend_rgb_s5_r <= 24'd0;
            blend_bypass_rgb_s5_r <= 24'd0;
            startup_bypass_s5_r <= 1'b0;
            skin_level_off_s5_r <= 1'b0;
        end

        out_de_r <= blend_de_s5_r;
        if (blend_de_s5_r) begin
            if (skin_level_off_s5_r || startup_bypass_s5_r)
                out_rgb_r <= blend_bypass_rgb_s5_r;
            else
                out_rgb_r <= blend_rgb_s5_r;
        end else begin
            out_rgb_r <= 24'd0;
        end
    end
end

assign out_de  = out_de_r;
assign out_rgb = out_rgb_r;

endmodule

module stream_plane_box7x7_mean
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
    output  reg     [7:0]   out_filtered
);

    localparam [10:0] H_LAST_COL = H_DISP - 1;

    wire [7:0] line1_q;
    wire [7:0] line2_q;
    wire [7:0] line3_q;
    wire [7:0] line4_q;
    wire [7:0] line5_q;
    wire [7:0] line6_q;

    (* preserve, syn_preserve = 1 *) reg         din_vld_d1;
    (* preserve, syn_preserve = 1 *) reg         din_vld_d2;
    (* preserve, syn_preserve = 1 *) reg         din_vld_d3;
    (* preserve, syn_preserve = 1 *) reg         din_vld_d4;
    (* preserve, syn_preserve = 1 *) reg         din_vld_d5;
    (* preserve, syn_preserve = 1 *) reg         din_vld_d6;
    reg  [7:0]  din_d1;
    reg  [7:0]  din_d2;
    reg  [7:0]  din_d3;
    reg  [7:0]  din_d4;
    reg  [7:0]  din_d5;
    reg  [7:0]  din_d6;
    (* preserve, syn_preserve = 1 *) reg  [11:0] col_cnt;
    (* preserve, syn_preserve = 1 *) reg  [11:0] row_cnt;
    (* preserve, syn_preserve = 1 *) reg  [10:0] col_d1;
    (* preserve, syn_preserve = 1 *) reg  [10:0] col_d2;
    (* preserve, syn_preserve = 1 *) reg  [10:0] col_d3;
    (* preserve, syn_preserve = 1 *) reg  [10:0] col_d4;
    (* preserve, syn_preserve = 1 *) reg  [10:0] col_d5;
    (* preserve, syn_preserve = 1 *) reg  [10:0] col_d6;
    (* preserve, syn_preserve = 1 *) reg  [11:0] row_d1;
    (* preserve, syn_preserve = 1 *) reg  [11:0] row_d2;
    (* preserve, syn_preserve = 1 *) reg  [11:0] row_d3;
    (* preserve, syn_preserve = 1 *) reg  [11:0] row_d4;
    (* preserve, syn_preserve = 1 *) reg  [11:0] row_d5;
    (* preserve, syn_preserve = 1 *) reg  [11:0] row_d6;
    reg  [7:0]  line1_q_d1;
    reg  [7:0]  line1_q_d2;
    reg  [7:0]  line1_q_d3;
    reg  [7:0]  line1_q_d4;
    reg  [7:0]  line1_q_d5;
    reg  [7:0]  line2_q_d1;
    reg  [7:0]  line2_q_d2;
    reg  [7:0]  line2_q_d3;
    reg  [7:0]  line2_q_d4;
    reg  [7:0]  line3_q_d1;
    reg  [7:0]  line3_q_d2;
    reg  [7:0]  line3_q_d3;
    reg  [7:0]  line4_q_d1;
    reg  [7:0]  line4_q_d2;
    reg  [7:0]  line5_q_d1;

    reg         win_vld_r;
    reg  [10:0] win_col_r;
    reg  [7:0]  w00_r; reg [7:0] w01_r; reg [7:0] w02_r; reg [7:0] w03_r; reg [7:0] w04_r; reg [7:0] w05_r; reg [7:0] w06_r;
    reg  [7:0]  w10_r; reg [7:0] w11_r; reg [7:0] w12_r; reg [7:0] w13_r; reg [7:0] w14_r; reg [7:0] w15_r; reg [7:0] w16_r;
    reg  [7:0]  w20_r; reg [7:0] w21_r; reg [7:0] w22_r; reg [7:0] w23_r; reg [7:0] w24_r; reg [7:0] w25_r; reg [7:0] w26_r;
    reg  [7:0]  w30_r; reg [7:0] w31_r; reg [7:0] w32_r; reg [7:0] w33_r; reg [7:0] w34_r; reg [7:0] w35_r; reg [7:0] w36_r;
    reg  [7:0]  w40_r; reg [7:0] w41_r; reg [7:0] w42_r; reg [7:0] w43_r; reg [7:0] w44_r; reg [7:0] w45_r; reg [7:0] w46_r;
    reg  [7:0]  w50_r; reg [7:0] w51_r; reg [7:0] w52_r; reg [7:0] w53_r; reg [7:0] w54_r; reg [7:0] w55_r; reg [7:0] w56_r;
    reg  [7:0]  w60_r; reg [7:0] w61_r; reg [7:0] w62_r; reg [7:0] w63_r; reg [7:0] w64_r; reg [7:0] w65_r; reg [7:0] w66_r;

    reg         pair_vld_r;
    reg  [10:0] pair_col_r;
    reg  [8:0]  p00_r; reg [8:0] p01_r; reg [8:0] p02_r; reg [8:0] p03_r;
    reg  [8:0]  p10_r; reg [8:0] p11_r; reg [8:0] p12_r; reg [8:0] p13_r;
    reg  [8:0]  p20_r; reg [8:0] p21_r; reg [8:0] p22_r; reg [8:0] p23_r;
    reg  [8:0]  p30_r; reg [8:0] p31_r; reg [8:0] p32_r; reg [8:0] p33_r;
    reg  [8:0]  p40_r; reg [8:0] p41_r; reg [8:0] p42_r; reg [8:0] p43_r;
    reg  [8:0]  p50_r; reg [8:0] p51_r; reg [8:0] p52_r; reg [8:0] p53_r;
    reg  [8:0]  p60_r; reg [8:0] p61_r; reg [8:0] p62_r; reg [8:0] p63_r;

    reg         half_vld_r;
    reg  [10:0] half_col_r;
    reg  [9:0]  h00_r; reg [9:0] h01_r;
    reg  [9:0]  h10_r; reg [9:0] h11_r;
    reg  [9:0]  h20_r; reg [9:0] h21_r;
    reg  [9:0]  h30_r; reg [9:0] h31_r;
    reg  [9:0]  h40_r; reg [9:0] h41_r;
    reg  [9:0]  h50_r; reg [9:0] h51_r;
    reg  [9:0]  h60_r; reg [9:0] h61_r;

    reg         row_vld_r;
    reg  [10:0] row_col_r;
    reg  [10:0] row0_sum_r;
    reg  [10:0] row1_sum_r;
    reg  [10:0] row2_sum_r;
    reg  [10:0] row3_sum_r;
    reg  [10:0] row4_sum_r;
    reg  [10:0] row5_sum_r;
    reg  [10:0] row6_sum_r;

    reg         row_pair_vld_r;
    reg  [10:0] row_pair_col_r;
    reg  [11:0] rp01_sum_r;
    reg  [11:0] rp23_sum_r;
    reg  [11:0] rp45_sum_r;
    reg  [11:0] rp6_sum_r;

    reg         total_half_vld_r;
    reg  [10:0] total_half_col_r;
    reg  [12:0] th03_sum_r;
    reg  [12:0] th46_sum_r;

    reg         total_vld_r;
    reg  [10:0] total_col_r;
    reg  [13:0] total_sum_r;

    reg         mul_vld_r;
    reg  [10:0] mul_col_r;
    reg  [25:0] total_mul_r;

    wire [7:0] row0_src_w = (row_d6 < 12'd6) ? 8'd0 : line6_q;
    wire [7:0] row1_src_w = (row_d6 < 12'd5) ? 8'd0 : line5_q_d1;
    wire [7:0] row2_src_w = (row_d6 < 12'd4) ? 8'd0 : line4_q_d2;
    wire [7:0] row3_src_w = (row_d6 < 12'd3) ? 8'd0 : line3_q_d3;
    wire [7:0] row4_src_w = (row_d6 < 12'd2) ? 8'd0 : line2_q_d4;
    wire [7:0] row5_src_w = (row_d6 < 12'd1) ? 8'd0 : line1_q_d5;
    wire [7:0] row6_src_w = din_d6;
    wire [25:0] filtered_round_full_w = (total_mul_r + 26'd65536) >> 17;
    wire [8:0]  filtered_round_w = filtered_round_full_w[8:0];

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
        .wren       (din_vld_d1 && (row_d1 != 12'd0)),
        .wraddress  (col_d1),
        .data       (line1_q),
        .rdaddress  (col_d1),
        .q          (line2_q)
    );

    m4k_linebuf_2048x8 u_line_buf_3
    (
        .clock      (clk),
        .wren       (din_vld_d2 && (row_d2 > 12'd1)),
        .wraddress  (col_d2),
        .data       (line2_q),
        .rdaddress  (col_d2),
        .q          (line3_q)
    );

    m4k_linebuf_2048x8 u_line_buf_4
    (
        .clock      (clk),
        .wren       (din_vld_d3 && (row_d3 > 12'd2)),
        .wraddress  (col_d3),
        .data       (line3_q),
        .rdaddress  (col_d3),
        .q          (line4_q)
    );

    m4k_linebuf_2048x8 u_line_buf_5
    (
        .clock      (clk),
        .wren       (din_vld_d4 && (row_d4 > 12'd3)),
        .wraddress  (col_d4),
        .data       (line4_q),
        .rdaddress  (col_d4),
        .q          (line5_q)
    );

    m4k_linebuf_2048x8 u_line_buf_6
    (
        .clock      (clk),
        .wren       (din_vld_d5 && (row_d5 > 12'd4)),
        .wraddress  (col_d5),
        .data       (line5_q),
        .rdaddress  (col_d5),
        .q          (line6_q)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            col_cnt <= 12'd0; row_cnt <= 12'd0;
            din_vld_d1 <= 1'b0; din_vld_d2 <= 1'b0; din_vld_d3 <= 1'b0; din_vld_d4 <= 1'b0; din_vld_d5 <= 1'b0; din_vld_d6 <= 1'b0;
            din_d1 <= 8'd0; din_d2 <= 8'd0; din_d3 <= 8'd0; din_d4 <= 8'd0; din_d5 <= 8'd0; din_d6 <= 8'd0;
            col_d1 <= 11'd0; col_d2 <= 11'd0; col_d3 <= 11'd0; col_d4 <= 11'd0; col_d5 <= 11'd0; col_d6 <= 11'd0;
            row_d1 <= 12'd0; row_d2 <= 12'd0; row_d3 <= 12'd0; row_d4 <= 12'd0; row_d5 <= 12'd0; row_d6 <= 12'd0;
            line1_q_d1 <= 8'd0; line1_q_d2 <= 8'd0; line1_q_d3 <= 8'd0; line1_q_d4 <= 8'd0; line1_q_d5 <= 8'd0;
            line2_q_d1 <= 8'd0; line2_q_d2 <= 8'd0; line2_q_d3 <= 8'd0; line2_q_d4 <= 8'd0;
            line3_q_d1 <= 8'd0; line3_q_d2 <= 8'd0; line3_q_d3 <= 8'd0;
            line4_q_d1 <= 8'd0; line4_q_d2 <= 8'd0; line5_q_d1 <= 8'd0;
            win_vld_r <= 1'b0; win_col_r <= 11'd0;
            w00_r <= 8'd0; w01_r <= 8'd0; w02_r <= 8'd0; w03_r <= 8'd0; w04_r <= 8'd0; w05_r <= 8'd0; w06_r <= 8'd0;
            w10_r <= 8'd0; w11_r <= 8'd0; w12_r <= 8'd0; w13_r <= 8'd0; w14_r <= 8'd0; w15_r <= 8'd0; w16_r <= 8'd0;
            w20_r <= 8'd0; w21_r <= 8'd0; w22_r <= 8'd0; w23_r <= 8'd0; w24_r <= 8'd0; w25_r <= 8'd0; w26_r <= 8'd0;
            w30_r <= 8'd0; w31_r <= 8'd0; w32_r <= 8'd0; w33_r <= 8'd0; w34_r <= 8'd0; w35_r <= 8'd0; w36_r <= 8'd0;
            w40_r <= 8'd0; w41_r <= 8'd0; w42_r <= 8'd0; w43_r <= 8'd0; w44_r <= 8'd0; w45_r <= 8'd0; w46_r <= 8'd0;
            w50_r <= 8'd0; w51_r <= 8'd0; w52_r <= 8'd0; w53_r <= 8'd0; w54_r <= 8'd0; w55_r <= 8'd0; w56_r <= 8'd0;
            w60_r <= 8'd0; w61_r <= 8'd0; w62_r <= 8'd0; w63_r <= 8'd0; w64_r <= 8'd0; w65_r <= 8'd0; w66_r <= 8'd0;
            pair_vld_r <= 1'b0; pair_col_r <= 11'd0;
            p00_r <= 9'd0; p01_r <= 9'd0; p02_r <= 9'd0; p03_r <= 9'd0; p10_r <= 9'd0; p11_r <= 9'd0; p12_r <= 9'd0; p13_r <= 9'd0;
            p20_r <= 9'd0; p21_r <= 9'd0; p22_r <= 9'd0; p23_r <= 9'd0; p30_r <= 9'd0; p31_r <= 9'd0; p32_r <= 9'd0; p33_r <= 9'd0;
            p40_r <= 9'd0; p41_r <= 9'd0; p42_r <= 9'd0; p43_r <= 9'd0; p50_r <= 9'd0; p51_r <= 9'd0; p52_r <= 9'd0; p53_r <= 9'd0;
            p60_r <= 9'd0; p61_r <= 9'd0; p62_r <= 9'd0; p63_r <= 9'd0;
            half_vld_r <= 1'b0; half_col_r <= 11'd0;
            h00_r <= 10'd0; h01_r <= 10'd0; h10_r <= 10'd0; h11_r <= 10'd0; h20_r <= 10'd0; h21_r <= 10'd0; h30_r <= 10'd0; h31_r <= 10'd0;
            h40_r <= 10'd0; h41_r <= 10'd0; h50_r <= 10'd0; h51_r <= 10'd0; h60_r <= 10'd0; h61_r <= 10'd0;
            row_vld_r <= 1'b0; row_col_r <= 11'd0;
            row0_sum_r <= 11'd0; row1_sum_r <= 11'd0; row2_sum_r <= 11'd0; row3_sum_r <= 11'd0; row4_sum_r <= 11'd0; row5_sum_r <= 11'd0; row6_sum_r <= 11'd0;
            row_pair_vld_r <= 1'b0; row_pair_col_r <= 11'd0; rp01_sum_r <= 12'd0; rp23_sum_r <= 12'd0; rp45_sum_r <= 12'd0; rp6_sum_r <= 12'd0;
            total_half_vld_r <= 1'b0; total_half_col_r <= 11'd0; th03_sum_r <= 13'd0; th46_sum_r <= 13'd0;
            total_vld_r <= 1'b0; total_col_r <= 11'd0; total_sum_r <= 14'd0;
            mul_vld_r <= 1'b0; mul_col_r <= 11'd0; total_mul_r <= 26'd0;
            out_vld <= 1'b0; out_filtered <= 8'd0;
        end else if (frame_clr) begin
            col_cnt <= 12'd0; row_cnt <= 12'd0;
            din_vld_d1 <= 1'b0; din_vld_d2 <= 1'b0; din_vld_d3 <= 1'b0; din_vld_d4 <= 1'b0; din_vld_d5 <= 1'b0; din_vld_d6 <= 1'b0;
            win_vld_r <= 1'b0; pair_vld_r <= 1'b0; half_vld_r <= 1'b0; row_vld_r <= 1'b0; row_pair_vld_r <= 1'b0; total_half_vld_r <= 1'b0; total_vld_r <= 1'b0; mul_vld_r <= 1'b0;
            out_vld <= 1'b0; out_filtered <= 8'd0;
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

            din_vld_d1 <= din_vld;    din_d1 <= din;    col_d1 <= col_cnt[10:0]; row_d1 <= row_cnt;
            din_vld_d2 <= din_vld_d1; din_d2 <= din_d1; col_d2 <= col_d1;        row_d2 <= row_d1; line1_q_d1 <= line1_q;
            din_vld_d3 <= din_vld_d2; din_d3 <= din_d2; col_d3 <= col_d2;        row_d3 <= row_d2; line1_q_d2 <= line1_q_d1; line2_q_d1 <= line2_q;
            din_vld_d4 <= din_vld_d3; din_d4 <= din_d3; col_d4 <= col_d3;        row_d4 <= row_d3; line1_q_d3 <= line1_q_d2; line2_q_d2 <= line2_q_d1; line3_q_d1 <= line3_q;
            din_vld_d5 <= din_vld_d4; din_d5 <= din_d4; col_d5 <= col_d4;        row_d5 <= row_d4; line1_q_d4 <= line1_q_d3; line2_q_d3 <= line2_q_d2; line3_q_d2 <= line3_q_d1; line4_q_d1 <= line4_q;
            din_vld_d6 <= din_vld_d5; din_d6 <= din_d5; col_d6 <= col_d5;        row_d6 <= row_d5; line1_q_d5 <= line1_q_d4; line2_q_d4 <= line2_q_d3; line3_q_d3 <= line3_q_d2; line4_q_d2 <= line4_q_d1; line5_q_d1 <= line5_q;

            win_vld_r <= din_vld_d6;
            win_col_r <= col_d6;
            if (din_vld_d6) begin
                if (col_d6 == H_LAST_COL) begin
                    w00_r <= 8'd0; w01_r <= 8'd0; w02_r <= 8'd0; w03_r <= 8'd0; w04_r <= 8'd0; w05_r <= 8'd0; w06_r <= 8'd0;
                    w10_r <= 8'd0; w11_r <= 8'd0; w12_r <= 8'd0; w13_r <= 8'd0; w14_r <= 8'd0; w15_r <= 8'd0; w16_r <= 8'd0;
                    w20_r <= 8'd0; w21_r <= 8'd0; w22_r <= 8'd0; w23_r <= 8'd0; w24_r <= 8'd0; w25_r <= 8'd0; w26_r <= 8'd0;
                    w30_r <= 8'd0; w31_r <= 8'd0; w32_r <= 8'd0; w33_r <= 8'd0; w34_r <= 8'd0; w35_r <= 8'd0; w36_r <= 8'd0;
                    w40_r <= 8'd0; w41_r <= 8'd0; w42_r <= 8'd0; w43_r <= 8'd0; w44_r <= 8'd0; w45_r <= 8'd0; w46_r <= 8'd0;
                    w50_r <= 8'd0; w51_r <= 8'd0; w52_r <= 8'd0; w53_r <= 8'd0; w54_r <= 8'd0; w55_r <= 8'd0; w56_r <= 8'd0;
                    w60_r <= 8'd0; w61_r <= 8'd0; w62_r <= 8'd0; w63_r <= 8'd0; w64_r <= 8'd0; w65_r <= 8'd0; w66_r <= 8'd0;
                end else begin
                    w00_r <= w01_r; w01_r <= w02_r; w02_r <= w03_r; w03_r <= w04_r; w04_r <= w05_r; w05_r <= w06_r; w06_r <= row0_src_w;
                    w10_r <= w11_r; w11_r <= w12_r; w12_r <= w13_r; w13_r <= w14_r; w14_r <= w15_r; w15_r <= w16_r; w16_r <= row1_src_w;
                    w20_r <= w21_r; w21_r <= w22_r; w22_r <= w23_r; w23_r <= w24_r; w24_r <= w25_r; w25_r <= w26_r; w26_r <= row2_src_w;
                    w30_r <= w31_r; w31_r <= w32_r; w32_r <= w33_r; w33_r <= w34_r; w34_r <= w35_r; w35_r <= w36_r; w36_r <= row3_src_w;
                    w40_r <= w41_r; w41_r <= w42_r; w42_r <= w43_r; w43_r <= w44_r; w44_r <= w45_r; w45_r <= w46_r; w46_r <= row4_src_w;
                    w50_r <= w51_r; w51_r <= w52_r; w52_r <= w53_r; w53_r <= w54_r; w54_r <= w55_r; w55_r <= w56_r; w56_r <= row5_src_w;
                    w60_r <= w61_r; w61_r <= w62_r; w62_r <= w63_r; w63_r <= w64_r; w64_r <= w65_r; w65_r <= w66_r; w66_r <= row6_src_w;
                end
            end

            pair_vld_r <= win_vld_r;
            pair_col_r <= win_col_r;
            p00_r <= {1'b0, w00_r} + {1'b0, w01_r}; p01_r <= {1'b0, w02_r} + {1'b0, w03_r}; p02_r <= {1'b0, w04_r} + {1'b0, w05_r}; p03_r <= {1'b0, w06_r};
            p10_r <= {1'b0, w10_r} + {1'b0, w11_r}; p11_r <= {1'b0, w12_r} + {1'b0, w13_r}; p12_r <= {1'b0, w14_r} + {1'b0, w15_r}; p13_r <= {1'b0, w16_r};
            p20_r <= {1'b0, w20_r} + {1'b0, w21_r}; p21_r <= {1'b0, w22_r} + {1'b0, w23_r}; p22_r <= {1'b0, w24_r} + {1'b0, w25_r}; p23_r <= {1'b0, w26_r};
            p30_r <= {1'b0, w30_r} + {1'b0, w31_r}; p31_r <= {1'b0, w32_r} + {1'b0, w33_r}; p32_r <= {1'b0, w34_r} + {1'b0, w35_r}; p33_r <= {1'b0, w36_r};
            p40_r <= {1'b0, w40_r} + {1'b0, w41_r}; p41_r <= {1'b0, w42_r} + {1'b0, w43_r}; p42_r <= {1'b0, w44_r} + {1'b0, w45_r}; p43_r <= {1'b0, w46_r};
            p50_r <= {1'b0, w50_r} + {1'b0, w51_r}; p51_r <= {1'b0, w52_r} + {1'b0, w53_r}; p52_r <= {1'b0, w54_r} + {1'b0, w55_r}; p53_r <= {1'b0, w56_r};
            p60_r <= {1'b0, w60_r} + {1'b0, w61_r}; p61_r <= {1'b0, w62_r} + {1'b0, w63_r}; p62_r <= {1'b0, w64_r} + {1'b0, w65_r}; p63_r <= {1'b0, w66_r};

            half_vld_r <= pair_vld_r;
            half_col_r <= pair_col_r;
            h00_r <= {1'b0, p00_r} + {1'b0, p01_r}; h01_r <= {1'b0, p02_r} + {1'b0, p03_r};
            h10_r <= {1'b0, p10_r} + {1'b0, p11_r}; h11_r <= {1'b0, p12_r} + {1'b0, p13_r};
            h20_r <= {1'b0, p20_r} + {1'b0, p21_r}; h21_r <= {1'b0, p22_r} + {1'b0, p23_r};
            h30_r <= {1'b0, p30_r} + {1'b0, p31_r}; h31_r <= {1'b0, p32_r} + {1'b0, p33_r};
            h40_r <= {1'b0, p40_r} + {1'b0, p41_r}; h41_r <= {1'b0, p42_r} + {1'b0, p43_r};
            h50_r <= {1'b0, p50_r} + {1'b0, p51_r}; h51_r <= {1'b0, p52_r} + {1'b0, p53_r};
            h60_r <= {1'b0, p60_r} + {1'b0, p61_r}; h61_r <= {1'b0, p62_r} + {1'b0, p63_r};

            row_vld_r <= half_vld_r;
            row_col_r <= half_col_r;
            row0_sum_r <= {1'b0, h00_r} + {1'b0, h01_r};
            row1_sum_r <= {1'b0, h10_r} + {1'b0, h11_r};
            row2_sum_r <= {1'b0, h20_r} + {1'b0, h21_r};
            row3_sum_r <= {1'b0, h30_r} + {1'b0, h31_r};
            row4_sum_r <= {1'b0, h40_r} + {1'b0, h41_r};
            row5_sum_r <= {1'b0, h50_r} + {1'b0, h51_r};
            row6_sum_r <= {1'b0, h60_r} + {1'b0, h61_r};

            row_pair_vld_r <= row_vld_r;
            row_pair_col_r <= row_col_r;
            rp01_sum_r <= {1'b0, row0_sum_r} + {1'b0, row1_sum_r};
            rp23_sum_r <= {1'b0, row2_sum_r} + {1'b0, row3_sum_r};
            rp45_sum_r <= {1'b0, row4_sum_r} + {1'b0, row5_sum_r};
            rp6_sum_r <= {1'b0, row6_sum_r};

            total_half_vld_r <= row_pair_vld_r;
            total_half_col_r <= row_pair_col_r;
            th03_sum_r <= {1'b0, rp01_sum_r} + {1'b0, rp23_sum_r};
            th46_sum_r <= {1'b0, rp45_sum_r} + {1'b0, rp6_sum_r};

            total_vld_r <= total_half_vld_r;
            total_col_r <= total_half_col_r;
            total_sum_r <= {1'b0, th03_sum_r} + {1'b0, th46_sum_r};

            mul_vld_r <= total_vld_r;
            mul_col_r <= total_col_r;
            total_mul_r <= total_sum_r * 12'd2675;

            out_vld <= mul_vld_r;
            if (mul_vld_r)
                out_filtered <= (mul_col_r == H_LAST_COL) ? 8'd0 : filtered_round_w[7:0];
            else
                out_filtered <= 8'd0;
        end
    end

endmodule

module stream_plane_box3x3_stats
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
    output  reg     [7:0]   out_spread
);

    localparam [10:0] H_LAST_COL = H_DISP - 1;

    function [7:0] min2_u8;
        input [7:0] a;
        input [7:0] b;
        begin
            min2_u8 = (a < b) ? a : b;
        end
    endfunction

    function [7:0] max2_u8;
        input [7:0] a;
        input [7:0] b;
        begin
            max2_u8 = (a > b) ? a : b;
        end
    endfunction

    wire [7:0] line1_q;
    wire [7:0] line2_q;
    wire [7:0] next_top_src_w;
    wire [7:0] next_mid_src_w;
    wire [7:0] shift_m11_w;
    wire [7:0] shift_m12_w;
    wire [7:0] shift_m13_w;
    wire [7:0] shift_m21_w;
    wire [7:0] shift_m22_w;
    wire [7:0] shift_m23_w;
    wire [7:0] shift_m31_w;
    wire [7:0] shift_m32_w;
    wire [7:0] shift_m33_w;

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

    reg  [7:0]  matrix_11;
    reg  [7:0]  matrix_12;
    reg  [7:0]  matrix_13;
    reg  [7:0]  matrix_21;
    reg  [7:0]  matrix_22;
    reg  [7:0]  matrix_23;
    reg  [7:0]  matrix_31;
    reg  [7:0]  matrix_32;
    reg  [7:0]  matrix_33;
    reg         pix_vld;
    reg         filt_vld_r;
    reg  [7:0]  center_s1_r;
    reg  [7:0]  p11_s1_r;
    reg  [7:0]  p12_s1_r;
    reg  [7:0]  p13_s1_r;
    reg  [7:0]  p21_s1_r;
    reg  [7:0]  p23_s1_r;
    reg  [7:0]  p31_s1_r;
    reg  [7:0]  p32_s1_r;
    reg  [7:0]  p33_s1_r;

    reg         stats_row_vld_r;
    reg  [7:0]  center_s2_r;
    reg  [10:0] filtered_row0_r;
    reg  [10:0] filtered_row1_r;
    reg  [10:0] filtered_row2_r;
    reg  [7:0]  min_row0_r;
    reg  [7:0]  min_row1_r;
    reg  [7:0]  min_row2_r;
    reg  [7:0]  max_row0_r;
    reg  [7:0]  max_row1_r;
    reg  [7:0]  max_row2_r;
    reg         stats_all_vld_r;
    reg  [7:0]  center_s3_r;
    reg  [11:0] filtered_sum_r;
    reg  [7:0]  min_all_r;
    reg  [7:0]  max_all_r;

    wire [10:0] filtered_row0_next_w =
        {3'd0, p11_s1_r} + {2'd0, p12_s1_r, 1'b0} + {3'd0, p13_s1_r};
    wire [10:0] filtered_row1_next_w =
        {2'd0, p21_s1_r, 1'b0} + {1'd0, center_s1_r, 2'b00} + {2'd0, p23_s1_r, 1'b0};
    wire [10:0] filtered_row2_next_w =
        {3'd0, p31_s1_r} + {2'd0, p32_s1_r, 1'b0} + {3'd0, p33_s1_r};
    wire [7:0] min_row0_next_w = min2_u8(min2_u8(p11_s1_r, p12_s1_r), p13_s1_r);
    wire [7:0] min_row1_next_w = min2_u8(min2_u8(p21_s1_r, center_s1_r), p23_s1_r);
    wire [7:0] min_row2_next_w = min2_u8(min2_u8(p31_s1_r, p32_s1_r), p33_s1_r);
    wire [7:0] max_row0_next_w = max2_u8(max2_u8(p11_s1_r, p12_s1_r), p13_s1_r);
    wire [7:0] max_row1_next_w = max2_u8(max2_u8(p21_s1_r, center_s1_r), p23_s1_r);
    wire [7:0] max_row2_next_w = max2_u8(max2_u8(p31_s1_r, p32_s1_r), p33_s1_r);

    wire [11:0] filtered_sum_next_w =
        {1'b0, filtered_row0_r} + {1'b0, filtered_row1_r} + {1'b0, filtered_row2_r};
    wire [7:0] min_all_next_w = min2_u8(min2_u8(min_row0_r, min_row1_r), min_row2_r);
    wire [7:0] max_all_next_w = max2_u8(max2_u8(max_row0_r, max_row1_r), max_row2_r);
    wire [7:0] filtered_px_w = (filtered_sum_r + 12'd8) >> 4;
    wire [7:0] spread_w = max_all_r - min_all_r;

    assign next_top_src_w = (row_d2 < 12'd2) ? 8'd0 : line2_q;
    assign next_mid_src_w = (row_d2 == 12'd0) ? 8'd0 : line1_q_d1;
    assign shift_m11_w = matrix_12;
    assign shift_m12_w = matrix_13;
    assign shift_m13_w = next_top_src_w;
    assign shift_m21_w = matrix_22;
    assign shift_m22_w = matrix_23;
    assign shift_m23_w = next_mid_src_w;
    assign shift_m31_w = matrix_32;
    assign shift_m32_w = matrix_33;
    assign shift_m33_w = din_d2;

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
        .wren       (din_vld_d1 && (row_d1 != 12'd0)),
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
            din_vld_d2 <= 1'b0;
            din_d1 <= 8'd0;
            din_d2 <= 8'd0;
            col_d1 <= 11'd0;
            col_d2 <= 11'd0;
            row_d1 <= 12'd0;
            row_d2 <= 12'd0;
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
            pix_vld <= 1'b0;
            filt_vld_r <= 1'b0;
            center_s1_r <= 8'd0;
            p11_s1_r <= 8'd0;
            p12_s1_r <= 8'd0;
            p13_s1_r <= 8'd0;
            p21_s1_r <= 8'd0;
            p23_s1_r <= 8'd0;
            p31_s1_r <= 8'd0;
            p32_s1_r <= 8'd0;
            p33_s1_r <= 8'd0;
            stats_row_vld_r <= 1'b0;
            center_s2_r <= 8'd0;
            filtered_row0_r <= 11'd0;
            filtered_row1_r <= 11'd0;
            filtered_row2_r <= 11'd0;
            min_row0_r <= 8'd0;
            min_row1_r <= 8'd0;
            min_row2_r <= 8'd0;
            max_row0_r <= 8'd0;
            max_row1_r <= 8'd0;
            max_row2_r <= 8'd0;
            stats_all_vld_r <= 1'b0;
            center_s3_r <= 8'd0;
            filtered_sum_r <= 12'd0;
            min_all_r <= 8'd0;
            max_all_r <= 8'd0;
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
            matrix_11 <= 8'd0;
            matrix_12 <= 8'd0;
            matrix_13 <= 8'd0;
            matrix_21 <= 8'd0;
            matrix_22 <= 8'd0;
            matrix_23 <= 8'd0;
            matrix_31 <= 8'd0;
            matrix_32 <= 8'd0;
            matrix_33 <= 8'd0;
            pix_vld <= 1'b0;
            filt_vld_r <= 1'b0;
            center_s1_r <= 8'd0;
            p11_s1_r <= 8'd0;
            p12_s1_r <= 8'd0;
            p13_s1_r <= 8'd0;
            p21_s1_r <= 8'd0;
            p23_s1_r <= 8'd0;
            p31_s1_r <= 8'd0;
            p32_s1_r <= 8'd0;
            p33_s1_r <= 8'd0;
            stats_row_vld_r <= 1'b0;
            center_s2_r <= 8'd0;
            filtered_row0_r <= 11'd0;
            filtered_row1_r <= 11'd0;
            filtered_row2_r <= 11'd0;
            min_row0_r <= 8'd0;
            min_row1_r <= 8'd0;
            min_row2_r <= 8'd0;
            max_row0_r <= 8'd0;
            max_row1_r <= 8'd0;
            max_row2_r <= 8'd0;
            stats_all_vld_r <= 1'b0;
            center_s3_r <= 8'd0;
            filtered_sum_r <= 12'd0;
            min_all_r <= 8'd0;
            max_all_r <= 8'd0;
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
                    matrix_11 <= 8'd0;
                    matrix_12 <= 8'd0;
                    matrix_13 <= 8'd0;
                    matrix_21 <= 8'd0;
                    matrix_22 <= 8'd0;
                    matrix_23 <= 8'd0;
                    matrix_31 <= 8'd0;
                    matrix_32 <= 8'd0;
                    matrix_33 <= 8'd0;
                end else begin
                    matrix_11 <= shift_m11_w;
                    matrix_12 <= shift_m12_w;
                    matrix_13 <= shift_m13_w;
                    matrix_21 <= shift_m21_w;
                    matrix_22 <= shift_m22_w;
                    matrix_23 <= shift_m23_w;
                    matrix_31 <= shift_m31_w;
                    matrix_32 <= shift_m32_w;
                    matrix_33 <= shift_m33_w;
                end
                pix_vld <= 1'b1;
            end else begin
                pix_vld <= 1'b0;
            end

            filt_vld_r <= pix_vld;
            if (pix_vld) begin
                center_s1_r <= matrix_22;
                p11_s1_r <= matrix_11;
                p12_s1_r <= matrix_12;
                p13_s1_r <= matrix_13;
                p21_s1_r <= matrix_21;
                p23_s1_r <= matrix_23;
                p31_s1_r <= matrix_31;
                p32_s1_r <= matrix_32;
                p33_s1_r <= matrix_33;
            end else begin
                center_s1_r <= 8'd0;
                p11_s1_r <= 8'd0;
                p12_s1_r <= 8'd0;
                p13_s1_r <= 8'd0;
                p21_s1_r <= 8'd0;
                p23_s1_r <= 8'd0;
                p31_s1_r <= 8'd0;
                p32_s1_r <= 8'd0;
                p33_s1_r <= 8'd0;
            end

            stats_row_vld_r <= filt_vld_r;
            if (filt_vld_r) begin
                center_s2_r <= center_s1_r;
                filtered_row0_r <= filtered_row0_next_w;
                filtered_row1_r <= filtered_row1_next_w;
                filtered_row2_r <= filtered_row2_next_w;
                min_row0_r <= min_row0_next_w;
                min_row1_r <= min_row1_next_w;
                min_row2_r <= min_row2_next_w;
                max_row0_r <= max_row0_next_w;
                max_row1_r <= max_row1_next_w;
                max_row2_r <= max_row2_next_w;
            end else begin
                center_s2_r <= 8'd0;
                filtered_row0_r <= 11'd0;
                filtered_row1_r <= 11'd0;
                filtered_row2_r <= 11'd0;
                min_row0_r <= 8'd0;
                min_row1_r <= 8'd0;
                min_row2_r <= 8'd0;
                max_row0_r <= 8'd0;
                max_row1_r <= 8'd0;
                max_row2_r <= 8'd0;
            end

            stats_all_vld_r <= stats_row_vld_r;
            if (stats_row_vld_r) begin
                center_s3_r <= center_s2_r;
                filtered_sum_r <= filtered_sum_next_w;
                min_all_r <= min_all_next_w;
                max_all_r <= max_all_next_w;
            end else begin
                center_s3_r <= 8'd0;
                filtered_sum_r <= 12'd0;
                min_all_r <= 8'd0;
                max_all_r <= 8'd0;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_vld <= 1'b0;
            out_center <= 8'd0;
            out_filtered <= 8'd0;
            out_spread <= 8'd0;
        end else if (frame_clr) begin
            out_vld <= 1'b0;
            out_center <= 8'd0;
            out_filtered <= 8'd0;
            out_spread <= 8'd0;
        end else begin
            out_vld <= stats_all_vld_r;
            if (stats_all_vld_r) begin
                out_center <= center_s3_r;
                out_filtered <= filtered_px_w;
                out_spread <= spread_w;
            end else begin
                out_center <= 8'd0;
                out_filtered <= 8'd0;
                out_spread <= 8'd0;
            end
        end
    end

endmodule
