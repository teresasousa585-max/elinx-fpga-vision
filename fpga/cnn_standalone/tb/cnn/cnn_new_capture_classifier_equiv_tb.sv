`timescale 1ns/1ps

/*
 * All-dataset classifier oracle:
 *   - RAW files are converted to the exact 32x32 density contract in the TB;
 *   - the untouched source classifier/weight copy and the target session
 *     wrapper receive the same 1024 legal tokens;
 *   - digit, unknown and distance must match exactly for every sample.
 *
 * Label accuracy is reported, not asserted.  This task integrates the
 * verified model as-is and does not hide known model errors by relabelling.
 */
module cnn_new_capture_classifier_equiv_tb;

localparam integer H_VALID = 1280;
localparam integer V_VALID = 720;
localparam integer TOTAL_PIXELS = H_VALID * V_VALID;
localparam integer SEARCH_X = 320;
localparam integer SEARCH_Y = 104;
localparam integer CELL_W = 20;
localparam integer CELL_H = 16;
localparam integer RESULT_TIMEOUT = 400000;
localparam [1:0] CMD_RESET = 2'd0;
localparam [1:0] CMD_START = 2'd1;
localparam [1:0] CMD_FEATURE = 2'd2;

reg clk = 1'b0;
always #20 clk = ~clk; // 25 MHz production classifier domain

reg rst_n;
reg source_frame_clr;
reg source_feature_valid;
reg source_feature_done;
reg [9:0] source_feature_index;
reg [5:0] source_feature_value;
wire source_candidate_valid;
wire [3:0] source_candidate_digit;
wire source_candidate_unknown;
wire [15:0] source_candidate_distance;

reg target_cmd_valid;
reg [22:0] target_cmd_data;
wire target_return_valid;
wire [25:0] target_return_data;
reg target_return_empty;
wire target_classifier_idle;
wire target_protocol_error;

reg [7:0] raw_mem [0:TOTAL_PIXELS-1];
reg [5:0] feature_mem [0:1023];

reg source_result_seen;
reg [3:0] source_result_digit;
reg source_result_unknown;
reg [15:0] source_result_distance;
reg target_result_seen;
reg [3:0] target_result_digit;
reg target_result_unknown;
reg [15:0] target_result_distance;
integer return_nonempty_cycles;

integer checks;
integer total_cases;
integer exact_matches;
integer label_correct;
integer label_unknown;
integer class_total [0:9];
integer class_correct [0:9];
integer class_unknown [0:9];
integer confusion [0:9][0:9];

gesture_cnn_flat_classifier u_source_classifier
(
    .clk               (clk),
    .rst_n             (rst_n),
    .frame_clr         (source_frame_clr),
    .feature_valid     (source_feature_valid),
    .feature_frame_done(source_feature_done),
    .feature_index     (source_feature_index),
    .feature_value     (source_feature_value),
    .candidate_valid   (source_candidate_valid),
    .candidate_digit   (source_candidate_digit),
    .candidate_unknown (source_candidate_unknown),
    .candidate_distance(source_candidate_distance)
);

cnn_classifier_session_25m u_target_wrapper
(
    .clk                    (clk),
    .rst_n                  (rst_n),
    .cmd_valid              (target_cmd_valid),
    .cmd_data               (target_cmd_data),
    .return_ready           (1'b1),
    .return_empty           (target_return_empty),
    .return_valid           (target_return_valid),
    .return_data            (target_return_data),
    .classifier_idle        (target_classifier_idle),
    .protocol_error         (target_protocol_error),
    .feature_write_pulse    (),
    .bbox_write_pulse       (),
    .wrapper_state_debug    (),
    .classifier_state_debug (),
    .active_session_debug   ()
);

task check_ok;
    input condition;
    input [8*160-1:0] message;
    begin
        checks = checks + 1;
        if (!condition)
            $fatal(1, "%0s", message);
    end
endtask

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        source_result_seen <= 1'b0;
        source_result_digit <= 4'd0;
        source_result_unknown <= 1'b1;
        source_result_distance <= 16'd0;
        target_result_seen <= 1'b0;
        target_result_digit <= 4'd0;
        target_result_unknown <= 1'b1;
        target_result_distance <= 16'd0;
        target_return_empty <= 1'b1;
        return_nonempty_cycles <= 0;
    end else begin
        if (source_candidate_valid) begin
            source_result_seen <= 1'b1;
            source_result_digit <= source_candidate_digit;
            source_result_unknown <= source_candidate_unknown;
            source_result_distance <= source_candidate_distance;
        end

        if (target_return_valid) begin
            target_return_empty <= 1'b0;
            return_nonempty_cycles <= 2;
            if (target_return_data[25]) begin
                target_result_seen <= 1'b1;
                target_result_unknown <= target_return_data[20];
                target_result_digit <= target_return_data[19:16];
                target_result_distance <= target_return_data[15:0];
            end else if (target_return_data[20]) begin
                $fatal(1, "target wrapper emitted protocol FAULT for a legal dataset token stream");
            end
        end else if (return_nonempty_cycles > 1) begin
            return_nonempty_cycles <= return_nonempty_cycles - 1;
        end else if (return_nonempty_cycles == 1) begin
            return_nonempty_cycles <= 0;
            target_return_empty <= 1'b1;
        end
    end
end

task reset_design;
    begin
        rst_n = 1'b0;
        source_frame_clr = 1'b0;
        source_feature_valid = 1'b0;
        target_cmd_valid = 1'b0;
        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (3) @(posedge clk);
    end
endtask

task load_raw;
    input string path;
    integer fd;
    integer bytes_read;
    begin
        fd = $fopen(path, "rb");
        check_ok(fd != 0, "failed to open RAW dataset sample");
        bytes_read = $fread(raw_mem, fd);
        $fclose(fd);
        check_ok(bytes_read == TOTAL_PIXELS, "RAW dataset sample length is not 921600 bytes");
    end
endtask

task build_features;
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
                for (sub_y = 0; sub_y < CELL_H; sub_y = sub_y + 1) begin
                    for (sub_x = 0; sub_x < CELL_W; sub_x = sub_x + 1) begin
                        raw_index = ((SEARCH_Y + cell_y * CELL_H + sub_y) * H_VALID)
                                  + SEARCH_X + cell_x * CELL_W + sub_x;
                        if (raw_mem[raw_index] <= 8'd112)
                            count = count + 1;
                    end
                end
                feature_mem[cell_y * 32 + cell_x] = count >> 3;
            end
        end
    end
endtask

task pulse_source_clear;
    begin
        @(negedge clk);
        source_frame_clr = 1'b1;
        @(posedge clk);
        @(negedge clk);
        source_frame_clr = 1'b0;
    end
endtask

task send_target_command;
    input [1:0] command;
    input [3:0] session;
    begin
        @(negedge clk);
        target_cmd_data = {command, session, 17'd0};
        target_cmd_valid = 1'b1;
        @(posedge clk);
        @(negedge clk);
        target_cmd_valid = 1'b0;
    end
endtask

task send_feature_both;
    input [3:0] session;
    input [9:0] index;
    input [5:0] value;
    begin
        @(negedge clk);
        source_feature_done = (index == 10'd1023);
        source_feature_index = index;
        source_feature_value = value;
        source_feature_valid = 1'b1;
        target_cmd_data = {CMD_FEATURE, session, (index == 10'd1023), index, value};
        target_cmd_valid = 1'b1;
        @(posedge clk);
        @(negedge clk);
        source_feature_valid = 1'b0;
        target_cmd_valid = 1'b0;
    end
endtask

task wait_target_idle;
    integer watchdog;
    begin
        watchdog = 0;
        while (!target_classifier_idle && (watchdog < 100)) begin
            @(posedge clk);
            watchdog = watchdog + 1;
        end
        check_ok(target_classifier_idle, "target wrapper did not return to IDLE");
    end
endtask

task run_case;
    input integer case_index;
    input integer expected;
    input string sample;
    input string path;
    integer index;
    integer watchdog;
    reg [3:0] session;
    begin
        session = (case_index % 15) + 1;
        source_result_seen = 1'b0;
        target_result_seen = 1'b0;
        load_raw(path);
        build_features();
        pulse_source_clear();
        send_target_command(CMD_RESET, session);
        wait_target_idle();
        send_target_command(CMD_START, session);

        for (index = 0; index < 1024; index = index + 1)
            send_feature_both(session, index[9:0], feature_mem[index]);

        watchdog = 0;
        while (!(source_result_seen && target_result_seen)
            && (watchdog < RESULT_TIMEOUT)) begin
            @(posedge clk);
            watchdog = watchdog + 1;
        end
        check_ok(source_result_seen, "source classifier result timeout");
        check_ok(target_result_seen, "target wrapper result timeout");
        check_ok(!target_protocol_error, "target wrapper protocol_error on legal dataset stream");
        check_ok(source_result_digit == target_result_digit,
                 "source/target candidate digit mismatch");
        check_ok(source_result_unknown == target_result_unknown,
                 "source/target candidate unknown mismatch");
        check_ok(source_result_distance == target_result_distance,
                 "source/target candidate distance mismatch");

        total_cases = total_cases + 1;
        exact_matches = exact_matches + 1;
        class_total[expected] = class_total[expected] + 1;
        if (target_result_unknown) begin
            label_unknown = label_unknown + 1;
            class_unknown[expected] = class_unknown[expected] + 1;
        end else begin
            confusion[expected][target_result_digit] =
                confusion[expected][target_result_digit] + 1;
            if (target_result_digit == expected[3:0]) begin
                label_correct = label_correct + 1;
                class_correct[expected] = class_correct[expected] + 1;
            end
        end
        $display("CNN_DATASET_CASE index=%0d sample=%s expected=%0d digit=%0d unknown=%0d distance=%0d cycles=%0d",
                 case_index, sample, expected, target_result_digit,
                 target_result_unknown, target_result_distance, watchdog);
        wait_target_idle();
    end
endtask

string manifest_path;
string sample_from_manifest;
string path_from_manifest;
integer label_from_manifest;
integer manifest_fd;
integer scan_count;
integer case_index;
integer i;
integer j;

initial begin
    checks = 0;
    total_cases = 0;
    exact_matches = 0;
    label_correct = 0;
    label_unknown = 0;
    source_feature_done = 1'b0;
    source_feature_index = 10'd0;
    source_feature_value = 6'd0;
    target_cmd_data = 23'd0;
    for (i = 0; i < 10; i = i + 1) begin
        class_total[i] = 0;
        class_correct[i] = 0;
        class_unknown[i] = 0;
        for (j = 0; j < 10; j = j + 1)
            confusion[i][j] = 0;
    end

    reset_design();
    manifest_path = "";
    check_ok($value$plusargs("MANIFEST=%s", manifest_path), "missing MANIFEST plusarg");
    manifest_fd = $fopen(manifest_path, "r");
    check_ok(manifest_fd != 0, "failed to open dataset manifest");
    case_index = 0;
    while (!$feof(manifest_fd)) begin
        scan_count = $fscanf(manifest_fd, "%d %s %s\n",
                             label_from_manifest, sample_from_manifest,
                             path_from_manifest);
        if (scan_count == 3) begin
            check_ok((label_from_manifest >= 0) && (label_from_manifest <= 9),
                     "manifest label outside 0..9");
            run_case(case_index, label_from_manifest,
                     sample_from_manifest, path_from_manifest);
            case_index = case_index + 1;
        end
    end
    $fclose(manifest_fd);

    $display("CNN_DATASET_RESULT total=%0d source_target_exact=%0d correct=%0d unknown=%0d accuracy_x10000=%0d",
             total_cases, exact_matches, label_correct, label_unknown,
             (total_cases == 0) ? 0 : (label_correct * 10000 / total_cases));
    for (i = 0; i < 10; i = i + 1) begin
        $display("CNN_DATASET_CLASS label=%0d total=%0d correct=%0d unknown=%0d accuracy_x10000=%0d",
                 i, class_total[i], class_correct[i], class_unknown[i],
                 (class_total[i] == 0) ? 0 : (class_correct[i] * 10000 / class_total[i]));
        $display("CNN_DATASET_CONFUSION label=%0d pred0=%0d pred1=%0d pred2=%0d pred3=%0d pred4=%0d pred5=%0d pred6=%0d pred7=%0d pred8=%0d pred9=%0d",
                 i, confusion[i][0], confusion[i][1], confusion[i][2],
                 confusion[i][3], confusion[i][4], confusion[i][5],
                 confusion[i][6], confusion[i][7], confusion[i][8],
                 confusion[i][9]);
    end
    check_ok(total_cases > 0, "empty dataset run");
    check_ok(exact_matches == total_cases, "not all source/target results matched");
    $display("cnn_new_capture_classifier_equiv_tb PASS checks=%0d total=%0d exact=%0d",
             checks, total_cases, exact_matches);
    $finish;
end

endmodule
