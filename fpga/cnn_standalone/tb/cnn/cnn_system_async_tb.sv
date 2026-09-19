`timescale 1ns/1ps

/* End-to-end asynchronous CNN-session regression.
 *
 * The first part replays one real new_capture RAW frame with 720p raster
 * spacing at a 60 Hz physical-frame cadence.  Because inference starts near
 * the end of an accepted frame and lasts about 10 ms at 25 MHz, admission is
 * expected to alternate ACCEPT/DROP and deliver about 30 results/s.
 *
 * The second part covers mode-exit abort, session wrap, stale return filtering,
 * malformed-command FAULT recovery, truncated-frame recovery, and coupled
 * reset requests from either clock domain. */
module cnn_system_async_tb;

localparam integer H_VALID = 1280;
localparam integer V_VALID = 720;
localparam integer TOTAL_PIXELS = H_VALID * V_VALID;
localparam integer FRAME_CYCLES_75M = 1250000;
localparam integer ROI_START_CYCLES = 104 * 1650 + 320;
localparam integer LINE_BLANK_CYCLES = 1010;
localparam [1:0] MODE_RGB = 2'd0;
localparam [1:0] MODE_CNN = 2'd3;
localparam [1:0] CMD_FEATURE = 2'd2;
localparam [2:0] WRAP_IDLE = 3'd0;
localparam [2:0] WRAP_COLLECT = 3'd1;
localparam [2:0] WRAP_INFER = 3'd2;

reg clk75 = 1'b0;
reg clk25 = 1'b0;
reg clk25_enable = 1'b1;
always #6.666 clk75 = ~clk75;
always #20 if (clk25_enable) clk25 = ~clk25;

reg reset_root_n;
reg [1:0] mode;
reg prefetch;
reg epoch;
reg de;
reg [7:0] raw;
reg [10:0] x;
reg [10:0] y;

wire digit_valid;
wire [3:0] digit;
wire accept;
wire drop;
wire [10:0] token_count;
wire overflow;
wire fault75;
wire proto25;
wire feature_write;
wire bbox_write;
wire [3:0] session;
wire ready;
wire inflight;
wire [2:0] wrapper_state;
wire [3:0] classifier_state;

reg [7:0] raw_mem [0:TOTAL_PIXELS-1];
reg [5:0] expected_feature [0:1023];
integer checks;
integer cycle75;
integer accepted_frames;
integer dropped_frames;
integer result_count;
integer stale_result_count;
integer result_cycle [0:7];
integer feature_count;
integer expected_index;
integer frame_start_cycle;
integer frame_number;
reg monitor_features;
reg protocol_injection;
reg [3:0] previous_session;
string sample_path;
integer sample_fd;
integer bytes_read;
integer i;

cnn_system dut (
    .clk_75m(clk75), .clk_25m(clk25), .reset_root_n(reset_root_n),
    .active_mode(mode), .frame_prefetch_start(prefetch),
    .frame_epoch(epoch), .in_de(de), .in_raw8(raw), .in_x(x), .in_y(y),
    .cnn_digit_valid(digit_valid), .cnn_digit(digit),
    .accepted_frame_pulse(accept), .dropped_frame_pulse(drop),
    .accepted_token_count(token_count),
    .feature_overflow_error(overflow),
    .protocol_fault_error_75m(fault75),
    .protocol_error_25m(proto25),
    .feature_write_pulse_25m(feature_write),
    .bbox_write_pulse_25m(bbox_write),
    .session_debug(session), .session_ready_debug(ready),
    .inference_inflight_debug(inflight),
    .wrapper_state_debug(wrapper_state),
    .classifier_state_debug(classifier_state)
);

task check_ok;
    input condition;
    input [8*128-1:0] message;
    begin
        checks = checks + 1;
        if (!condition)
            $fatal(1, "%0s", message);
    end
endtask

task build_feature_oracle;
    integer cell_x;
    integer cell_y;
    integer sub_x;
    integer sub_y;
    integer count;
    integer raw_index;
    begin
        for (cell_y = 0; cell_y < 32; cell_y = cell_y + 1) begin
            for (cell_x = 0; cell_x < 32; cell_x = cell_x + 1) begin
                count = 0;
                for (sub_y = 0; sub_y < 16; sub_y = sub_y + 1) begin
                    for (sub_x = 0; sub_x < 20; sub_x = sub_x + 1) begin
                        raw_index = ((104 + cell_y * 16 + sub_y) * H_VALID)
                                  + 320 + cell_x * 20 + sub_x;
                        if (raw_mem[raw_index] <= 8'd112)
                            count = count + 1;
                    end
                end
                expected_feature[cell_y * 32 + cell_x] = count >> 3;
            end
        end
    end
endtask

task wait_session_ready;
    integer watchdog;
    begin
        watchdog = 0;
        while (!ready && watchdog < 2000) begin
            @(posedge clk75);
            #1;
            watchdog = watchdog + 1;
        end
        check_ok(ready, "timeout waiting for RESET_ACK/session ready");
    end
endtask

task pulse_boundary;
    input expect_accept;
    input expect_drop;
    begin
        @(negedge clk75);
        prefetch = 1'b1;
        epoch = 1'b1;
        @(posedge clk75);
        #1;
        check_ok(accept == expect_accept, "frame admission ACCEPT mismatch");
        check_ok(drop == expect_drop, "frame admission DROP mismatch");
        if (expect_accept)
            accepted_frames = accepted_frames + 1;
        if (expect_drop)
            dropped_frames = dropped_frames + 1;
        @(negedge clk75);
        prefetch = 1'b0;
        epoch = 1'b0;
    end
endtask

task replay_physical_frame;
    input expect_accept;
    input expect_drop;
    integer pixel_x;
    integer pixel_y;
    integer raw_index;
    begin
        frame_start_cycle = cycle75;
        feature_count = 0;
        expected_index = 0;
        monitor_features = expect_accept;
        pulse_boundary(expect_accept, expect_drop);

        repeat (ROI_START_CYCLES) @(posedge clk75);
        for (pixel_y = 104; pixel_y < 616; pixel_y = pixel_y + 1) begin
            for (pixel_x = 320; pixel_x < 960; pixel_x = pixel_x + 1) begin
                raw_index = pixel_y * H_VALID + pixel_x;
                @(negedge clk75);
                de = 1'b1;
                raw = raw_mem[raw_index];
                x = pixel_x[10:0];
                y = pixel_y[10:0];
            end
            @(negedge clk75);
            de = 1'b0;
            raw = 8'd0;
            x = 11'd0;
            y = 11'd0;
            repeat (LINE_BLANK_CYCLES) @(posedge clk75);
        end

        while (cycle75 < frame_start_cycle + FRAME_CYCLES_75M - 2)
            @(posedge clk75);
        #1;
        if (expect_accept) begin
            check_ok(feature_count == 1024,
                     "accepted physical frame did not deliver exactly 1024 features");
            check_ok(token_count == 1024 && !overflow,
                     "accepted frame token count/overflow status mismatch");
        end else begin
            check_ok(feature_count == 0,
                     "dropped physical frame emitted a feature token");
        end
        monitor_features = 1'b0;
        frame_number = frame_number + 1;
    end
endtask

task wait_wrapper_state;
    input [2:0] wanted;
    input integer limit;
    integer watchdog;
    begin
        watchdog = 0;
        while (wrapper_state != wanted && watchdog < limit) begin
            @(posedge clk25);
            #1;
            watchdog = watchdog + 1;
        end
        check_ok(wrapper_state == wanted, "timeout waiting for wrapper state");
    end
endtask

task wait_fault75;
    integer watchdog;
    begin
        watchdog = 0;
        while (!fault75 && watchdog < 2000) begin
            @(posedge clk75);
            #1;
            watchdog = watchdog + 1;
        end
        check_ok(fault75 && proto25, "ordered protocol FAULT did not cross to 75 MHz");
    end
endtask

always @(posedge clk75) begin
    cycle75 = cycle75 + 1;
    if (reset_root_n && dut.cnn_rst_n_75m_w && dut.return_pop_valid_w
        && dut.return_pop_data_w[25]) begin
        if ((dut.return_pop_data_w[24:21] == session)
         && (mode == MODE_CNN) && inflight) begin
            check_ok(!dut.return_pop_data_w[20],
                     "known dataset sample unexpectedly classified UNKNOWN");
            check_ok(dut.return_pop_data_w[19:16] == 4'd1,
                     "real digit-1 sample produced the wrong classification");
            result_cycle[result_count] = cycle75;
            result_count = result_count + 1;
        end else begin
            /* An ordered result may already be in the return FIFO when a
             * frame-boundary mode change installs a new session.  The
             * frontend contract is to drain and ignore that stale payload. */
            stale_result_count = stale_result_count + 1;
        end
    end
end

always @(posedge clk25) begin
    if (reset_root_n && dut.cnn_rst_n_25m_w
        && dut.forward_pop_valid_w && !protocol_injection
        && dut.forward_pop_data_w[22:21] == CMD_FEATURE) begin
        check_ok(monitor_features, "DROP frame emitted feature token");
        check_ok(dut.forward_pop_data_w[15:6] == expected_index[9:0],
                 "feature index was not strict 0..1023");
        check_ok(dut.forward_pop_data_w[5:0] == expected_feature[expected_index],
                 "system feature differs from real RAW oracle");
        check_ok(dut.forward_pop_data_w[16] == (expected_index == 1023),
                 "feature done encoding differs from index1023 contract");
        expected_index = expected_index + 1;
        feature_count = feature_count + 1;
    end
end

initial begin
    checks = 0;
    cycle75 = 0;
    accepted_frames = 0;
    dropped_frames = 0;
    result_count = 0;
    stale_result_count = 0;
    feature_count = 0;
    expected_index = 0;
    frame_number = 0;
    monitor_features = 1'b0;
    protocol_injection = 1'b0;
    reset_root_n = 1'b0;
    mode = MODE_RGB;
    prefetch = 1'b0;
    epoch = 1'b0;
    de = 1'b0;
    raw = 8'd0;
    x = 11'd0;
    y = 11'd0;

    sample_path = "new_capture/1/raw8_digit_1_20260622_153700_344_0000.raw";
    void'($value$plusargs("CNN_SAMPLE=%s", sample_path));
    sample_fd = $fopen(sample_path, "rb");
    check_ok(sample_fd != 0, "failed to open real CNN RAW sample");
    bytes_read = $fread(raw_mem, sample_fd);
    $fclose(sample_fd);
    check_ok(bytes_read == TOTAL_PIXELS, "CNN RAW sample is not 921600 bytes");
    build_feature_oracle();

    repeat (5) @(posedge clk75);
    reset_root_n = 1'b1;
    repeat (8) @(posedge clk75);

    /* Eight physical boundaries: entry DROP, then three complete
     * ACCEPT/DROP pairs, followed by a fourth ACCEPT. */
    mode = MODE_CNN;
    replay_physical_frame(1'b0, 1'b1); // frame 0: RESET/ACK admission
    check_ok(ready, "entry RESET_ACK did not return within one physical frame");
    replay_physical_frame(1'b1, 1'b0); // frame 1: inference 1
    check_ok(inflight && wrapper_state == WRAP_INFER,
             "full production inference was not busy at frame end");
    replay_physical_frame(1'b0, 1'b1); // frame 2: busy drop
    check_ok(result_count == 1 && !inflight,
             "first full inference did not finish during busy-drop frame");
    replay_physical_frame(1'b1, 1'b0); // frame 3: inference 2
    replay_physical_frame(1'b0, 1'b1); // frame 4: busy drop
    check_ok(result_count == 2, "second accepted frame produced no result");
    replay_physical_frame(1'b1, 1'b0); // frame 5: inference 3
    replay_physical_frame(1'b0, 1'b1); // frame 6: busy drop
    check_ok(result_count == 3, "third accepted frame produced no result");
    check_ok((result_cycle[1] - result_cycle[0]) > 2400000
          && (result_cycle[1] - result_cycle[0]) < 2600000
          && (result_cycle[2] - result_cycle[1]) > 2400000
          && (result_cycle[2] - result_cycle[1]) < 2600000,
             "result cadence is not approximately 30 results/s");
    replay_physical_frame(1'b1, 1'b0); // frame 7 commits stable digit
    check_ok(digit_valid && digit == 4'd1,
             "three consistent results were not committed at frame epoch");
    check_ok(accepted_frames == 4 && dropped_frames == 4,
             "eight-frame physical admission did not alternate 4 ACCEPT/4 DROP");

    /* Exit while the fourth production inference is active.  RESET must
     * abort it, clear visible OSD state, and return the wrapper to IDLE. */
    check_ok(inflight && wrapper_state == WRAP_INFER,
             "fourth inference was not active before mode-exit test");
    previous_session = session;
    mode = MODE_RGB;
    pulse_boundary(1'b0, 1'b0);
    check_ok(session == previous_session + 4'd1,
             "CNN exit did not allocate a new session");
    check_ok(!digit_valid && !inflight,
             "CNN exit did not clear visible digit/inflight state");
    wait_session_ready();
    wait_wrapper_state(WRAP_IDLE, 2000);

    /* Re-entry resets again.  A delayed RESULT and FAULT from the previous
     * session must be drained without affecting current status or display. */
    previous_session = session;
    mode = MODE_CNN;
    pulse_boundary(1'b0, 1'b1);
    check_ok(session == previous_session + 4'd1,
             "CNN re-entry did not allocate a new session");
    wait_session_ready();
    force dut.return_pop_valid_w = 1'b1;
    force dut.return_pop_data_w = {1'b1, previous_session, 1'b0, 4'd7, 16'd1};
    @(posedge clk75); #1;
    release dut.return_pop_valid_w;
    release dut.return_pop_data_w;
    check_ok(!digit_valid && ready && !fault75,
             "stale RESULT changed current display/session state");
    force dut.return_pop_valid_w = 1'b1;
    force dut.return_pop_data_w = {1'b0, previous_session, 1'b1, 20'd0};
    @(posedge clk75); #1;
    release dut.return_pop_valid_w;
    release dut.return_pop_data_w;
    check_ok(ready && !fault75, "stale FAULT poisoned the current session");

    /* Repeated legal mode transitions exercise 4-bit session wrap. */
    while (session != 4'hf) begin
        previous_session = session;
        mode = (mode == MODE_CNN) ? MODE_RGB : MODE_CNN;
        pulse_boundary(1'b0, mode == MODE_CNN);
        check_ok(session == previous_session + 4'd1,
                 "session id did not increment on mode transition");
        wait_session_ready();
    end
    previous_session = session;
    mode = (mode == MODE_CNN) ? MODE_RGB : MODE_CNN;
    pulse_boundary(1'b0, mode == MODE_CNN);
    check_ok(previous_session == 4'hf && session == 4'h0,
             "session id did not wrap 15 to 0");
    wait_session_ready();

    /* Enter CNN if needed, accept a session, then inject a same-session
     * out-of-order feature.  The wrapper must return an ordered FAULT and
     * the next boundary must reset/recover to a fresh session. */
    if (mode != MODE_CNN) begin
        mode = MODE_CNN;
        pulse_boundary(1'b0, 1'b1);
        wait_session_ready();
    end
    pulse_boundary(1'b1, 1'b0);
    wait_wrapper_state(WRAP_COLLECT, 2000);
    protocol_injection = 1'b1;
    force dut.forward_pop_valid_w = 1'b1;
    force dut.forward_pop_data_w = {CMD_FEATURE, session, 1'b0, 10'd2, 6'd7};
    @(posedge clk25); #1;
    release dut.forward_pop_valid_w;
    release dut.forward_pop_data_w;
    protocol_injection = 1'b0;
    wait_fault75();
    previous_session = session;
    pulse_boundary(1'b0, 1'b1);
    check_ok(session == previous_session + 4'd1,
             "protocol FAULT did not restart the session at next boundary");
    wait_session_ready();
    check_ok(fault75 && !proto25,
             "RESET/ACK recovery must clear wrapper FAULT while keeping OSD error sticky until a good RESULT");
    pulse_boundary(1'b1, 1'b0);
    check_ok(inflight, "protocol-fault recovery did not admit a new frame");

    /* No ROI is sent for that accepted frame.  The next boundary detects the
     * incomplete 0/1024 token contract, restarts, and recovers admission. */
    previous_session = session;
    pulse_boundary(1'b0, 1'b1);
    check_ok(session == previous_session + 4'd1 && overflow,
             "truncated accepted frame did not restart with feature error");
    wait_session_ready();
    pulse_boundary(1'b1, 1'b0);
    check_ok(inflight && overflow,
             "truncated-frame RESET/ACK did not recover admission with error status held sticky");
    mode = MODE_RGB;
    pulse_boundary(1'b0, 1'b0);
    wait_session_ready();

    /* The common asynchronous root must clear the complete island even when
     * one local clock is stopped; release remains local-clock synchronized. */
    @(negedge clk75);
    reset_root_n = 1'b0;
    #1;
    check_ok(!dut.cnn_rst_n_75m_w && !dut.cnn_rst_n_25m_w,
             "common reset root did not clear the coupled island");
    @(negedge clk75);
    reset_root_n = 1'b1;
    repeat (4) @(posedge clk75);
    repeat (2) @(posedge clk25);
    check_ok(dut.cnn_rst_n_75m_w && dut.cnn_rst_n_25m_w,
             "coupled island did not synchronously release in both domains");

    @(negedge clk25);
    clk25_enable = 1'b0;
    reset_root_n = 1'b0;
    #1;
    check_ok(!dut.cnn_rst_n_75m_w && !dut.cnn_rst_n_25m_w,
             "stopped 25 MHz clock blocked asynchronous island assertion");
    reset_root_n = 1'b1;
    repeat (4) @(posedge clk75);
    check_ok(dut.cnn_rst_n_75m_w && !dut.cnn_rst_n_25m_w,
             "stopped domain released without a local clock edge");
    clk25_enable = 1'b1;
    repeat (3) @(posedge clk25);
    check_ok(dut.cnn_rst_n_25m_w,
             "25 MHz island did not release after its clock resumed");

    $display("cnn_system_async_tb PASS checks=%0d physical_frames=%0d accepts=%0d drops=%0d results=%0d result_delta=%0d/%0d",
             checks, frame_number, accepted_frames, dropped_frames,
             result_count, result_cycle[1]-result_cycle[0],
             result_cycle[2]-result_cycle[1]);
    $finish;
end

endmodule
