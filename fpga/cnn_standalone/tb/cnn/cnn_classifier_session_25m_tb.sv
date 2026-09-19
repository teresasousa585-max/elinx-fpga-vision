`timescale 1ns/1ps

/* Direct protocol regression for the 25 MHz session wrapper.  The final
 * legal session uses the production classifier and production weight ROM. */
module cnn_classifier_session_25m_tb;

reg clk = 1'b0;
always #20 clk = ~clk;
reg rst_n;
reg cmd_valid;
reg [22:0] cmd_data;
reg return_ready;
reg return_empty;
wire return_valid;
wire [25:0] return_data;
wire classifier_idle;
wire protocol_error;
wire feature_write_pulse;
wire bbox_write_pulse;
wire [2:0] wrapper_state_debug;
wire [3:0] classifier_state_debug;
wire [3:0] active_session_debug;

integer checks;
integer feature_pulses;
integer bbox_pulses;
integer protocol_feature_base;
integer k;
reg [25:0] held_result;

localparam [1:0] CMD_RESET   = 2'd0;
localparam [1:0] CMD_START   = 2'd1;
localparam [1:0] CMD_FEATURE = 2'd2;
localparam [2:0] WRAP_IDLE        = 3'd0;
localparam [2:0] WRAP_COLLECT     = 3'd1;
localparam [2:0] WRAP_INFER       = 3'd2;
localparam [2:0] WRAP_RESULT_WAIT = 3'd3;

cnn_classifier_session_25m dut (
    .clk(clk), .rst_n(rst_n), .cmd_valid(cmd_valid), .cmd_data(cmd_data),
    .return_ready(return_ready), .return_empty(return_empty),
    .return_valid(return_valid), .return_data(return_data),
    .classifier_idle(classifier_idle), .protocol_error(protocol_error),
    .feature_write_pulse(feature_write_pulse), .bbox_write_pulse(bbox_write_pulse),
    .wrapper_state_debug(wrapper_state_debug), .classifier_state_debug(classifier_state_debug),
    .active_session_debug(active_session_debug)
);

task check_ok;
    input condition;
    input [8*108-1:0] message;
    begin
        checks = checks + 1;
        if (!condition)
            $fatal(1, "%0s", message);
    end
endtask

task send_cmd;
    input [1:0] cmd_type;
    input [3:0] session;
    input done;
    input [9:0] index;
    input [5:0] value;
    begin
        @(negedge clk);
        cmd_data = {cmd_type, session, done, index, value};
        cmd_valid = 1'b1;
        @(posedge clk);
        #1;
        @(negedge clk);
        cmd_valid = 1'b0;
    end
endtask

task reset_session;
    input [3:0] session;
    begin
        return_ready = 1'b1;
        return_empty = 1'b1;
        send_cmd(CMD_RESET, session, 1'b0, 10'd0, 6'd0);
        check_ok(return_valid && return_data == {1'b0,session,21'd0}, "RESET did not create authoritative RESET_ACK");
        check_ok(active_session_debug == session, "RESET did not install active session");
        @(posedge clk); #1;
        check_ok(!return_valid && wrapper_state_debug == WRAP_IDLE, "RESET_ACK did not clear back to IDLE");
    end
endtask

task wait_for_result_wait;
    integer watchdog;
    begin
        watchdog = 0;
        while ((wrapper_state_debug != WRAP_RESULT_WAIT) && (watchdog < 1000000)) begin
            @(posedge clk);
            #1;
            watchdog = watchdog + 1;
        end
        check_ok(wrapper_state_debug == WRAP_RESULT_WAIT, "timeout waiting for production classifier result");
    end
endtask

/* feature/bbox enables are combinational accepted_feature signals.  Sample
 * in the active region: the legal final token is still COLLECT before NBA
 * moves wrapper_state to INFER, then both enables correctly fall low. */
always @(posedge clk) begin
    if (rst_n) begin
        if (feature_write_pulse) begin
            check_ok(wrapper_state_debug == WRAP_COLLECT, "feature_write_pulse escaped COLLECT");
            feature_pulses = feature_pulses + 1;
        end
        if (bbox_write_pulse) begin
            check_ok(wrapper_state_debug == WRAP_COLLECT, "bbox_write_pulse escaped COLLECT");
            bbox_pulses = bbox_pulses + 1;
        end
        if ((wrapper_state_debug == WRAP_INFER || wrapper_state_debug == WRAP_RESULT_WAIT))
            check_ok(!feature_write_pulse && !bbox_write_pulse, "INFER/RESULT_WAIT generated a collection write pulse");
    end
end

initial begin
    checks = 0;
    feature_pulses = 0;
    bbox_pulses = 0;
    rst_n = 1'b0;
    cmd_valid = 1'b0;
    cmd_data = 23'd0;
    return_ready = 1'b1;
    return_empty = 1'b1;
    repeat (4) @(posedge clk);
    rst_n = 1'b1;
    repeat (2) @(posedge clk);

    /* RESET/ACK and strict index protocol: a jump after index 0 aborts. */
    reset_session(4'h1);
    send_cmd(CMD_START,4'h1,1'b0,10'd0,6'd0);
    #1; check_ok(wrapper_state_debug == WRAP_COLLECT, "START did not enter COLLECT");
    protocol_feature_base = feature_pulses;
    send_cmd(CMD_FEATURE,4'h1,1'b0,10'd0,6'd7);
    return_ready = 1'b0;
    send_cmd(CMD_FEATURE,4'h1,1'b0,10'd2,6'd8);
    @(posedge clk); #2;
    check_ok(protocol_error && wrapper_state_debug == WRAP_IDLE, "index jump did not raise protocol error and abort");
    held_result = return_data;
    check_ok(!held_result[25] && held_result[24:21] == 4'h1 && held_result[20], "index jump did not create session-tagged FAULT");
    repeat (2) begin @(posedge clk); #1; check_ok(!return_valid && return_data == held_result, "blocked FAULT payload was not stable"); end
    return_ready = 1'b1; @(posedge clk); #1;
    check_ok(feature_pulses == protocol_feature_base + 1 && bbox_pulses == feature_pulses, "index jump wrote a non-contiguous feature/bbox entry");

    /* done is legal only at index 1023. */
    reset_session(4'h2);
    send_cmd(CMD_START,4'h2,1'b0,10'd0,6'd0);
    send_cmd(CMD_FEATURE,4'h2,1'b1,10'd0,6'd9);
    #1; check_ok(protocol_error && wrapper_state_debug == WRAP_IDLE, "wrong feature done flag did not abort session");

    /* RESET is authoritative while COLLECT is partially populated. */
    reset_session(4'h3);
    send_cmd(CMD_START,4'h3,1'b0,10'd0,6'd0);
    send_cmd(CMD_FEATURE,4'h3,1'b0,10'd0,6'd11);
    #1; check_ok(wrapper_state_debug == WRAP_COLLECT, "COLLECT setup failed before RESET test");
    reset_session(4'h4);
    check_ok(!protocol_error && active_session_debug == 4'h4,
             "RESET during COLLECT did not discard partial session cleanly");

    /* A same-session command during INFER is a protocol error and aborts. */
    reset_session(4'h5);
    send_cmd(CMD_START,4'h5,1'b0,10'd0,6'd0);
    for (k = 0; k < 1024; k = k + 1)
        send_cmd(CMD_FEATURE,4'h5,(k == 1023),k[9:0],6'd0);
    #1; check_ok(wrapper_state_debug == WRAP_INFER, "legal final index 1023/done did not enter INFER");
    send_cmd(CMD_START,4'h5,1'b0,10'd0,6'd0);
    #1; check_ok(protocol_error && wrapper_state_debug == WRAP_IDLE, "same-session INFER command did not abort");

    /* A new RESET also aborts a real long-running INFER without waiting for
     * the classifier result or leaking the previous feature memory. */
    reset_session(4'h6);
    send_cmd(CMD_START,4'h6,1'b0,10'd0,6'd0);
    for (k = 0; k < 1024; k = k + 1)
        send_cmd(CMD_FEATURE,4'h6,(k == 1023),k[9:0],(k[5:0] ^ 6'h15));
    #1; check_ok(wrapper_state_debug == WRAP_INFER,
                 "long INFER setup failed before authoritative RESET test");
    reset_session(4'h7);
    check_ok(classifier_state_debug == 4'd0 && !protocol_error,
             "RESET during INFER did not soft-reset classifier/wrapper");

    /* Production-weight full inference.  The legal input is deliberately a
     * nonuniform 6-bit vector so the classifier and weight ROM are exercised
     * rather than a reset-only path. */
    reset_session(4'h8);
    send_cmd(CMD_START,4'h8,1'b0,10'd0,6'd0);
    for (k = 0; k < 1024; k = k + 1)
        send_cmd(CMD_FEATURE,4'h8,(k == 1023),k[9:0],(k[5:0] ^ 6'h15));
    #1; check_ok(wrapper_state_debug == WRAP_INFER, "production session did not enter INFER after final feature");
    return_ready = 1'b0;
    wait_for_result_wait();
    held_result = return_data;
    check_ok(held_result[25] && held_result[24:21] == 4'h8, "RESULT type/session encoding wrong");
    repeat (5) begin
        @(posedge clk); #1;
        check_ok(wrapper_state_debug == WRAP_RESULT_WAIT && return_data == held_result && !return_valid, "RESULT was not held while return FIFO was blocked");
    end
    @(negedge clk);
    return_ready = 1'b1;
    #1; check_ok(return_valid && return_data == held_result, "RESULT changed before return FIFO accepted it");
    @(posedge clk); #1;
    return_empty = 1'b0; /* model return FIFO now nonempty */
    @(posedge clk); #1;
    return_empty = 1'b1; /* and subsequently consumed by 75 MHz side */
    repeat (2) @(posedge clk); #1;
    check_ok(wrapper_state_debug == WRAP_IDLE && classifier_idle, "RESULT_WAIT did not return IDLE after FIFO consumption");

    /* RESET also replaces a blocked RESULT_WAIT payload with a new
     * authoritative ACK.  Use an invalid all-zero feature vector so this
     * second result is produced quickly without another long convolution. */
    reset_session(4'h9);
    send_cmd(CMD_START,4'h9,1'b0,10'd0,6'd0);
    for (k = 0; k < 1024; k = k + 1)
        send_cmd(CMD_FEATURE,4'h9,(k == 1023),k[9:0],6'd0);
    return_ready = 1'b0;
    wait_for_result_wait();
    send_cmd(CMD_RESET,4'ha,1'b0,10'd0,6'd0);
    #1;
    check_ok(wrapper_state_debug == WRAP_IDLE && active_session_debug == 4'ha,
             "RESET during RESULT_WAIT did not install new idle session");
    check_ok(!return_valid && return_data == {1'b0,4'ha,21'd0},
             "RESET during RESULT_WAIT did not replace blocked RESULT with ACK");
    return_ready = 1'b1;
    @(posedge clk); #1;
    check_ok(!return_valid && !protocol_error,
             "replacement RESET_ACK did not drain cleanly after RESULT_WAIT abort");
    check_ok(feature_pulses == bbox_pulses, "feature and bbox write pulse counts diverged");

    $display("cnn_classifier_session_25m_tb PASS checks=%0d feature_writes=%0d result=%h", checks, feature_pulses, held_result);
    $finish;
end

endmodule
