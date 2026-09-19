`timescale 1ns/1ps

/* Real RAW replay against an independent zero-time feature oracle. */
module cnn_new_capture_feature_equiv_tb;

localparam integer H_VALID = 1280;
localparam integer V_VALID = 720;
localparam integer TOTAL_PIXELS = H_VALID * V_VALID;
localparam integer SEARCH_X = 320;
localparam integer SEARCH_Y = 104;
localparam integer CELL_W = 20;
localparam integer CELL_H = 16;

reg clk = 1'b0;
always #6.666 clk = ~clk;
reg rst_n;
reg frame_clr;
reg in_de;
reg [7:0] in_raw;
reg [10:0] in_x;
reg [10:0] in_y;
wire feature_valid;
wire feature_done;
wire [9:0] feature_index;
wire [5:0] feature_value;
wire feature_overflow;
wire feature_backlog;
wire bbox_valid;
wire [6:0] bbox_left;
wire [6:0] bbox_right;
wire [6:0] bbox_top;
wire [6:0] bbox_bottom;

reg [7:0] raw_mem [0:TOTAL_PIXELS-1];
reg [5:0] expected_feature [0:1023];
integer token_count;
integer checks;
integer total_cases;

cnn_feature_32x32 u_dut
(
    .clk                (clk),
    .rst_n              (rst_n),
    .frame_clr          (frame_clr),
    .in_de              (in_de),
    .in_raw             (in_raw),
    .in_xpos            (in_x),
    .in_ypos            (in_y),
    .feature_ready      (1'b1),
    .feature_valid      (feature_valid),
    .feature_frame_done (feature_done),
    .feature_index      (feature_index),
    .feature_value      (feature_value),
    .bbox_valid         (bbox_valid),
    .bbox_left          (bbox_left),
    .bbox_right         (bbox_right),
    .bbox_top           (bbox_top),
    .bbox_bottom        (bbox_bottom),
    .feature_overflow   (feature_overflow),
    .feature_backlog    (feature_backlog)
);

task check_ok;
    input condition;
    input [8*140-1:0] message;
    begin
        checks = checks + 1;
        if (!condition)
            $fatal(1, "%0s", message);
    end
endtask

always begin
    @(posedge clk);
    #1;
    if (rst_n && feature_valid) begin
        check_ok(token_count < 1024, "feature producer emitted more than 1024 tokens");
        check_ok(feature_index == token_count[9:0], "feature index was lost, duplicated or reordered");
        check_ok(feature_value == expected_feature[token_count], "RTL feature value differs from RAW oracle");
        check_ok(feature_done == (token_count == 1023), "feature done flag differs from index1023 contract");
        token_count = token_count + 1;
    end
end

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

task build_expected;
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
                expected_feature[cell_y * 32 + cell_x] = count >> 3;
            end
        end
    end
endtask

task clear_frame;
    begin
        @(negedge clk);
        frame_clr = 1'b1;
        @(posedge clk);
        @(negedge clk);
        frame_clr = 1'b0;
        token_count = 0;
    end
endtask

task replay_roi;
    integer pixel_x;
    integer pixel_y;
    integer raw_index;
    begin
        for (pixel_y = SEARCH_Y; pixel_y < SEARCH_Y + 512; pixel_y = pixel_y + 1) begin
            for (pixel_x = SEARCH_X; pixel_x < SEARCH_X + 640; pixel_x = pixel_x + 1) begin
                raw_index = pixel_y * H_VALID + pixel_x;
                @(negedge clk);
                in_de = 1'b1;
                in_raw = raw_mem[raw_index];
                in_x = pixel_x[10:0];
                in_y = pixel_y[10:0];
            end
        end
        @(negedge clk);
        in_de = 1'b0;
        in_raw = 8'd0;
        in_x = 11'd0;
        in_y = 11'd0;
    end
endtask

task run_case;
    input integer case_index;
    input integer expected_label;
    input string sample;
    input string path;
    integer watchdog;
    begin
        load_raw(path);
        build_expected();
        clear_frame();
        replay_roi();
        watchdog = 0;
        while ((token_count < 1024 || feature_backlog) && watchdog < 100) begin
            @(posedge clk);
            #1;
            watchdog = watchdog + 1;
        end
        check_ok(token_count == 1024, "real RAW replay did not produce exactly 1024 tokens");
        check_ok(!feature_overflow, "real RAW replay overflowed the feature producer");
        check_ok(!feature_backlog, "feature producer did not drain after real RAW replay");
        total_cases = total_cases + 1;
        $display("CNN_FEATURE_CASE index=%0d sample=%s label=%0d tokens=%0d bbox=%0d,%0d,%0d,%0d valid=%0d",
                 case_index, sample, expected_label, token_count,
                 bbox_left, bbox_right, bbox_top, bbox_bottom, bbox_valid);
    end
endtask

string manifest_path;
string sample_from_manifest;
string path_from_manifest;
integer label_from_manifest;
integer manifest_fd;
integer scan_count;
integer case_index;

initial begin
    checks = 0;
    total_cases = 0;
    token_count = 0;
    rst_n = 1'b0;
    frame_clr = 1'b0;
    in_de = 1'b0;
    in_raw = 8'd0;
    in_x = 11'd0;
    in_y = 11'd0;
    repeat (5) @(posedge clk);
    rst_n = 1'b1;
    repeat (3) @(posedge clk);

    manifest_path = "";
    check_ok($value$plusargs("MANIFEST=%s", manifest_path), "missing MANIFEST plusarg");
    manifest_fd = $fopen(manifest_path, "r");
    check_ok(manifest_fd != 0, "failed to open feature replay manifest");
    case_index = 0;
    while (!$feof(manifest_fd)) begin
        scan_count = $fscanf(manifest_fd, "%d %s %s\n",
                             label_from_manifest, sample_from_manifest,
                             path_from_manifest);
        if (scan_count == 3) begin
            run_case(case_index, label_from_manifest,
                     sample_from_manifest, path_from_manifest);
            case_index = case_index + 1;
        end
    end
    $fclose(manifest_fd);
    check_ok(total_cases > 0, "empty feature replay run");
    $display("cnn_new_capture_feature_equiv_tb PASS checks=%0d cases=%0d tokens_per_case=1024",
             checks, total_cases);
    $finish;
end

endmodule
