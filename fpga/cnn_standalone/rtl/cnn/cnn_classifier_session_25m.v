`timescale 1ns/1ns

module cnn_classifier_session_25m
(
    input  wire        clk,
    input  wire        rst_n,

    input  wire        cmd_valid,
    input  wire [22:0] cmd_data,

    input  wire        return_ready,
    input  wire        return_empty,
    output wire        return_valid,
    output wire [25:0] return_data,

    output wire        classifier_idle,
    output reg         protocol_error,
    output wire        feature_write_pulse,
    output wire        bbox_write_pulse,
    output wire [2:0]  wrapper_state_debug,
    output wire [3:0]  classifier_state_debug,
    output wire [3:0]  active_session_debug
);

localparam [1:0] CMD_RESET   = 2'd0;
localparam [1:0] CMD_START   = 2'd1;
localparam [1:0] CMD_FEATURE = 2'd2;

localparam [2:0] WRAP_IDLE        = 3'd0;
localparam [2:0] WRAP_COLLECT     = 3'd1;
localparam [2:0] WRAP_INFER       = 3'd2;
localparam [2:0] WRAP_RESULT_WAIT = 3'd3;

wire [1:0] cmd_type_w    = cmd_data[22:21];
wire [3:0] cmd_session_w = cmd_data[20:17];
wire       cmd_done_w    = cmd_data[16];
wire [9:0] cmd_index_w   = cmd_data[15:6];
wire [5:0] cmd_value_w   = cmd_data[5:0];

reg [2:0] wrapper_state_r;
reg [3:0] active_session_r;
reg [9:0] expected_index_r;
reg       abort_pulse_r;

reg        response_pending_r;
reg [25:0] response_data_r;
reg        result_fifo_seen_nonempty_r;

wire reset_cmd_w = cmd_valid && (cmd_type_w == CMD_RESET);
wire feature_shape_ok_w = (cmd_index_w <= 10'd1023)
                        && (cmd_done_w == (cmd_index_w == 10'd1023));
wire accepted_feature_w = cmd_valid
                        && (cmd_type_w == CMD_FEATURE)
                        && (cmd_session_w == active_session_r)
                        && (wrapper_state_r == WRAP_COLLECT)
                        && (cmd_index_w == expected_index_r)
                        && feature_shape_ok_w;

wire classifier_candidate_valid_w;
wire [3:0] classifier_candidate_digit_w;
wire classifier_candidate_unknown_w;
wire [15:0] classifier_candidate_distance_w;
wire classifier_busy_w;
wire classifier_soft_reset_w = reset_cmd_w | abort_pulse_r;
wire response_fire_w = response_pending_r && return_ready;

assign return_valid = response_pending_r && return_ready;
assign return_data = response_data_r;
assign classifier_idle = (wrapper_state_r == WRAP_IDLE)
                       && !classifier_busy_w
                       && !response_pending_r
                       && return_empty;
assign wrapper_state_debug = wrapper_state_r;
assign active_session_debug = active_session_r;

cnn_flat_classifier u_cnn_flat_classifier
(
    .clk                 (clk),
    .rst_n               (rst_n),
    .soft_reset          (classifier_soft_reset_w),
    .frame_clr           (1'b0),
    .feature_valid       (accepted_feature_w),
    .feature_frame_done  (cmd_done_w),
    .feature_index       (cmd_index_w),
    .feature_value       (cmd_value_w),
    .candidate_valid     (classifier_candidate_valid_w),
    .candidate_digit     (classifier_candidate_digit_w),
    .candidate_unknown   (classifier_candidate_unknown_w),
    .candidate_distance  (classifier_candidate_distance_w),
    .busy                (classifier_busy_w),
    .feature_write_pulse (feature_write_pulse),
    .bbox_write_pulse    (bbox_write_pulse),
    .state_debug         (classifier_state_debug)
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        wrapper_state_r <= WRAP_IDLE;
        active_session_r <= 4'd0;
        expected_index_r <= 10'd0;
        abort_pulse_r <= 1'b0;
        protocol_error <= 1'b0;
        response_pending_r <= 1'b0;
        response_data_r <= 26'd0;
        result_fifo_seen_nonempty_r <= 1'b0;
    end else begin
        abort_pulse_r <= 1'b0;

        if (reset_cmd_w) begin
            wrapper_state_r <= WRAP_IDLE;
            active_session_r <= cmd_session_w;
            expected_index_r <= 10'd0;
            protocol_error <= 1'b0;
            result_fifo_seen_nonempty_r <= 1'b0;
            // RESET_ACK: type=0, session is authoritative; other fields zero.
            response_pending_r <= 1'b1;
            response_data_r <= {1'b0, cmd_session_w, 21'd0};
        end else begin
            if (response_fire_w)
                response_pending_r <= 1'b0;

            if (wrapper_state_r == WRAP_RESULT_WAIT) begin
                if (!return_empty)
                    result_fifo_seen_nonempty_r <= 1'b1;
                if (result_fifo_seen_nonempty_r && return_empty) begin
                    wrapper_state_r <= WRAP_IDLE;
                    result_fifo_seen_nonempty_r <= 1'b0;
                end
            end

            if (cmd_valid) begin
                case (cmd_type_w)
                    CMD_START: begin
                        if ((cmd_session_w == active_session_r)
                         && (wrapper_state_r == WRAP_IDLE)
                         && !response_pending_r) begin
                            wrapper_state_r <= WRAP_COLLECT;
                            expected_index_r <= 10'd0;
                        end else if (cmd_session_w == active_session_r) begin
                            protocol_error <= 1'b1;
                            abort_pulse_r <= 1'b1;
                            wrapper_state_r <= WRAP_IDLE;
                            expected_index_r <= 10'd0;
                            result_fifo_seen_nonempty_r <= 1'b0;
                            // FAULT: type=0, session, fault=1, payload=0.
                            // It shares the ordered return FIFO with ACK and
                            // RESULT so the 75 MHz side can restart safely.
                            response_pending_r <= 1'b1;
                            response_data_r <= {1'b0, active_session_r,
                                                1'b1, 20'd0};
                        end
                    end

                    CMD_FEATURE: begin
                        if (cmd_session_w != active_session_r) begin
                            // A stale token is harmless and is drained.
                        end else if (accepted_feature_w) begin
                            if (cmd_index_w == 10'd1023) begin
                                wrapper_state_r <= WRAP_INFER;
                                expected_index_r <= 10'd0;
                            end else begin
                                expected_index_r <= expected_index_r + 10'd1;
                            end
                        end else begin
                            protocol_error <= 1'b1;
                            abort_pulse_r <= 1'b1;
                            wrapper_state_r <= WRAP_IDLE;
                            expected_index_r <= 10'd0;
                            result_fifo_seen_nonempty_r <= 1'b0;
                            response_pending_r <= 1'b1;
                            response_data_r <= {1'b0, active_session_r,
                                                1'b1, 20'd0};
                        end
                    end

                    default: begin
                        protocol_error <= 1'b1;
                        abort_pulse_r <= 1'b1;
                        wrapper_state_r <= WRAP_IDLE;
                        expected_index_r <= 10'd0;
                        result_fifo_seen_nonempty_r <= 1'b0;
                        response_pending_r <= 1'b1;
                        response_data_r <= {1'b0, active_session_r,
                                            1'b1, 20'd0};
                    end
                endcase
            end else if (classifier_candidate_valid_w
                      && (wrapper_state_r == WRAP_INFER)) begin
                // RESULT: type=1, session, unknown, digit, margin.
                response_pending_r <= 1'b1;
                response_data_r <= {1'b1, active_session_r,
                                    classifier_candidate_unknown_w,
                                    classifier_candidate_digit_w,
                                    classifier_candidate_distance_w};
                wrapper_state_r <= WRAP_RESULT_WAIT;
                result_fifo_seen_nonempty_r <= 1'b0;
            end
        end
    end
end

endmodule
