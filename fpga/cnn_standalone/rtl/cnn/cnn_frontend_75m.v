`timescale 1ns/1ns

module cnn_frontend_75m
(
    input  wire        clk,
    input  wire        rst_n,
    input  wire [1:0]  active_mode,
    input  wire        frame_prefetch_start,
    input  wire        frame_epoch,
    input  wire        in_de,
    input  wire [7:0]  in_raw8,
    input  wire [10:0] in_x,
    input  wire [10:0] in_y,

    input  wire        forward_ready,
    input  wire        forward_empty,
    output wire        forward_valid,
    output wire [22:0] forward_data,

    input  wire        return_valid,
    input  wire [25:0] return_data,

    output reg         cnn_digit_valid,
    output reg  [3:0]  cnn_digit,
    output reg         accepted_frame_pulse,
    output reg         dropped_frame_pulse,
    output reg  [10:0] accepted_token_count,
    output reg         feature_overflow_error,
    output reg         protocol_fault_error,
    output wire [3:0]  session_debug,
    output wire        session_ready_debug,
    output wire        inference_inflight_debug
);

localparam [1:0] MODE_CNN    = 2'd3;
localparam [1:0] CMD_RESET   = 2'd0;
localparam [1:0] CMD_START   = 2'd1;
localparam [1:0] CMD_FEATURE = 2'd2;

wire return_is_result_w = return_data[25];
wire [3:0] return_session_w = return_data[24:21];
wire return_is_fault_w = !return_is_result_w && return_data[20];
wire return_unknown_w = return_data[20];
wire [3:0] return_digit_w = return_data[19:16];

reg [1:0] mode_last_r;
reg [3:0] session_id_r;
reg       session_ready_r;
reg       inference_inflight_r;
reg       accept_frame_r;
reg       protocol_fault_pending_r;

reg       reset_pending_r;
reg [3:0] reset_session_r;
reg       start_pending_r;

wire feature_valid_w;
wire feature_done_w;
wire [9:0] feature_index_w;
wire [5:0] feature_value_w;
wire feature_overflow_w;
wire feature_backlog_w;
wire feature_ready_w;
wire feature_in_de_w = in_de && accept_frame_r && !feature_overflow_w;

wire fwd_select_reset_w = reset_pending_r;
wire fwd_select_start_w = !reset_pending_r && start_pending_r;
wire fwd_select_feature_w = !reset_pending_r && !start_pending_r
                          && feature_valid_w;
wire forward_fire_w = forward_valid && forward_ready;

wire mode_transition_w = frame_prefetch_start && (active_mode != mode_last_r);
wire cnn_transition_w = mode_transition_w
                      && ((active_mode == MODE_CNN) || (mode_last_r == MODE_CNN));
wire session_incomplete_w = inference_inflight_r
                          && (accepted_token_count != 11'd1024);
wire current_return_fault_w = return_valid && return_is_fault_w
                            && (return_session_w == session_id_r);
wire session_fault_w = frame_prefetch_start
                     && (feature_overflow_w || feature_backlog_w
                      || session_incomplete_w
                      || protocol_fault_pending_r
                      || current_return_fault_w);
wire session_restart_w = cnn_transition_w || session_fault_w;
wire [3:0] next_session_w = session_id_r + 4'd1;
wire frame_accept_w = (active_mode == MODE_CNN)
                    && session_ready_r
                    && !inference_inflight_r
                    && forward_empty
                    && forward_ready
                    && !reset_pending_r
                    && !start_pending_r
                    && !feature_overflow_w;

wire stabilizer_clear_w = session_restart_w;
reg candidate_valid_r;
reg [3:0] candidate_digit_r;
reg candidate_unknown_r;
wire stable_valid_w;
wire [3:0] stable_digit_w;
wire stable_unknown_w;

reg stable_valid_last_r;
reg [3:0] stable_digit_last_r;
reg stable_unknown_last_r;
reg display_pending_r;
reg display_pending_valid_r;
reg [3:0] display_pending_digit_r;

assign forward_valid = fwd_select_reset_w
                     || fwd_select_start_w
                     || fwd_select_feature_w;
assign forward_data = fwd_select_reset_w
                    ? {CMD_RESET, reset_session_r, 17'd0}
                    : fwd_select_start_w
                    ? {CMD_START, session_id_r, 17'd0}
                    : {CMD_FEATURE, session_id_r, feature_done_w,
                       feature_index_w, feature_value_w};
assign feature_ready_w = forward_ready
                       && !reset_pending_r
                       && !start_pending_r;
assign session_debug = session_id_r;
assign session_ready_debug = session_ready_r;
assign inference_inflight_debug = inference_inflight_r;

cnn_feature_32x32 u_cnn_feature_32x32
(
    .clk                (clk),
    .rst_n              (rst_n),
    .frame_clr          (frame_prefetch_start),
    .in_de              (feature_in_de_w),
    .in_raw             (in_raw8),
    .in_xpos            (in_x),
    .in_ypos            (in_y),
    .feature_ready      (feature_ready_w),
    .feature_valid      (feature_valid_w),
    .feature_frame_done (feature_done_w),
    .feature_index      (feature_index_w),
    .feature_value      (feature_value_w),
    .bbox_valid         (),
    .bbox_left          (),
    .bbox_right         (),
    .bbox_top           (),
    .bbox_bottom        (),
    .feature_overflow   (feature_overflow_w),
    .feature_backlog    (feature_backlog_w)
);

cnn_digit_stabilizer u_cnn_digit_stabilizer
(
    .clk               (clk),
    .rst_n             (rst_n),
    .clear             (stabilizer_clear_w),
    .candidate_valid   (candidate_valid_r),
    .candidate_digit   (candidate_digit_r),
    .candidate_unknown (candidate_unknown_r),
    .stable_valid      (stable_valid_w),
    .stable_digit      (stable_digit_w),
    .display_unknown   (stable_unknown_w)
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        mode_last_r <= 2'd0;
        session_id_r <= 4'd0;
        session_ready_r <= 1'b0;
        inference_inflight_r <= 1'b0;
        accept_frame_r <= 1'b0;
        reset_pending_r <= 1'b0;
        reset_session_r <= 4'd0;
        start_pending_r <= 1'b0;
        accepted_frame_pulse <= 1'b0;
        dropped_frame_pulse <= 1'b0;
        accepted_token_count <= 11'd0;
        feature_overflow_error <= 1'b0;
        protocol_fault_error <= 1'b0;
        protocol_fault_pending_r <= 1'b0;
        candidate_valid_r <= 1'b0;
        candidate_digit_r <= 4'd0;
        candidate_unknown_r <= 1'b1;
        stable_valid_last_r <= 1'b0;
        stable_digit_last_r <= 4'd0;
        stable_unknown_last_r <= 1'b1;
        display_pending_r <= 1'b0;
        display_pending_valid_r <= 1'b0;
        display_pending_digit_r <= 4'd0;
        cnn_digit_valid <= 1'b0;
        cnn_digit <= 4'd0;
    end else begin
        accepted_frame_pulse <= 1'b0;
        dropped_frame_pulse <= 1'b0;
        candidate_valid_r <= 1'b0;

        if (forward_fire_w) begin
            if (fwd_select_reset_w)
                reset_pending_r <= 1'b0;
            else if (fwd_select_start_w)
                start_pending_r <= 1'b0;
            else if (fwd_select_feature_w)
                accepted_token_count <= accepted_token_count + 11'd1;
        end

        if (return_valid) begin
            if (!return_is_result_w) begin
                if (return_session_w == session_id_r) begin
                    if (return_is_fault_w) begin
                        session_ready_r <= 1'b0;
                        protocol_fault_pending_r <= 1'b1;
                        protocol_fault_error <= 1'b1;
                    end else begin
                        session_ready_r <= 1'b1;
                        protocol_fault_pending_r <= 1'b0;
                    end
                end
            end else if ((return_session_w == session_id_r)
                      && (active_mode == MODE_CNN)
                      && inference_inflight_r) begin
                candidate_valid_r <= 1'b1;
                candidate_digit_r <= return_digit_w;
                candidate_unknown_r <= return_unknown_w;
                inference_inflight_r <= 1'b0;
                feature_overflow_error <= 1'b0;
                protocol_fault_error <= 1'b0;
            end
        end

        if ((stable_valid_w != stable_valid_last_r)
         || (stable_digit_w != stable_digit_last_r)
         || (stable_unknown_w != stable_unknown_last_r)) begin
            stable_valid_last_r <= stable_valid_w;
            stable_digit_last_r <= stable_digit_w;
            stable_unknown_last_r <= stable_unknown_w;
            display_pending_r <= 1'b1;
            display_pending_valid_r <= stable_valid_w && !stable_unknown_w;
            display_pending_digit_r <= stable_digit_w;
        end

        if (frame_epoch && (active_mode == MODE_CNN) && display_pending_r) begin
            cnn_digit_valid <= display_pending_valid_r;
            cnn_digit <= display_pending_digit_r;
            display_pending_r <= 1'b0;
        end

        if (frame_prefetch_start) begin
            mode_last_r <= active_mode;
            accept_frame_r <= 1'b0;

            if (session_restart_w) begin
                session_id_r <= next_session_w;
                session_ready_r <= 1'b0;
                inference_inflight_r <= 1'b0;
                candidate_valid_r <= 1'b0;
                protocol_fault_pending_r <= 1'b0;
                reset_pending_r <= 1'b1;
                reset_session_r <= next_session_w;
                start_pending_r <= 1'b0;
                accepted_token_count <= 11'd0;
                feature_overflow_error <= feature_overflow_w || feature_backlog_w
                                        || session_incomplete_w;
                display_pending_r <= 1'b0;
                display_pending_valid_r <= 1'b0;
                display_pending_digit_r <= 4'd0;
                cnn_digit_valid <= 1'b0;
                cnn_digit <= 4'd0;
                stable_valid_last_r <= 1'b0;
                stable_digit_last_r <= 4'd0;
                stable_unknown_last_r <= 1'b1;
                if (cnn_transition_w)
                    protocol_fault_error <= 1'b0;
                if (active_mode == MODE_CNN)
                    dropped_frame_pulse <= 1'b1;
            end else if (active_mode == MODE_CNN) begin
                if (frame_accept_w) begin
                    accept_frame_r <= 1'b1;
                    start_pending_r <= 1'b1;
                    inference_inflight_r <= 1'b1;
                    accepted_token_count <= 11'd0;
                    accepted_frame_pulse <= 1'b1;
                end else begin
                    dropped_frame_pulse <= 1'b1;
                end
            end
        end
    end
end

endmodule
