`timescale 1ns/1ps

/* Directed coverage for the two-slot output skid path in cnn_feature_32x32.
 * A 32x32 search window makes every pixel complete one feature cell, so the
 * active/pending collision can be exercised without a long video replay. */
module cnn_feature_collision_tb;

reg clk = 1'b0;
always #5 clk = ~clk;

reg rst_n;
reg frame_clr;
reg in_de;
reg [7:0] in_raw;
reg [10:0] in_x;
reg [10:0] in_y;
reg ready;
wire valid;
wire done;
wire [9:0] index;
wire [5:0] value;
wire overflow;
wire backlog;

integer checks;
integer accepted;
integer expected_index;

cnn_feature_32x32 #(
    .SEARCH_X (0),
    .SEARCH_Y (0),
    .SEARCH_W (32),
    .SEARCH_H (32)
) dut (
    .clk(clk), .rst_n(rst_n), .frame_clr(frame_clr),
    .in_de(in_de), .in_raw(in_raw), .in_xpos(in_x), .in_ypos(in_y),
    .feature_ready(ready), .feature_valid(valid),
    .feature_frame_done(done), .feature_index(index),
    .feature_value(value), .bbox_valid(), .bbox_left(), .bbox_right(),
    .bbox_top(), .bbox_bottom(), .feature_overflow(overflow),
    .feature_backlog(backlog)
);

task check_ok;
    input condition;
    input [8*96-1:0] message;
    begin
        checks = checks + 1;
        if (!condition)
            $fatal(1, "%0s", message);
    end
endtask

task drive_pixel;
    input [10:0] px;
    input ready_value;
    begin
        @(negedge clk);
        in_de = 1'b1;
        in_raw = 8'd0;
        in_x = px;
        in_y = 11'd0;
        ready = ready_value;
        @(posedge clk);
        #1;
    end
endtask

task clear_frame;
    begin
        @(negedge clk);
        in_de = 1'b0;
        ready = 1'b0;
        frame_clr = 1'b1;
        @(posedge clk);
        #1;
        @(negedge clk);
        frame_clr = 1'b0;
    end
endtask

always @(posedge clk) begin
    if (rst_n && valid && ready) begin
        check_ok(index == expected_index[9:0],
                 "feature token missing, duplicated, or reordered");
        check_ok(value == 6'd0, "1x1 dark-cell density must truncate to zero");
        check_ok(!done, "early directed token asserted frame done");
        expected_index = expected_index + 1;
        accepted = accepted + 1;
    end
end

initial begin
    checks = 0;
    accepted = 0;
    expected_index = 0;
    rst_n = 1'b0;
    frame_clr = 1'b0;
    in_de = 1'b0;
    in_raw = 8'd0;
    in_x = 11'd0;
    in_y = 11'd0;
    ready = 1'b0;
    repeat (3) @(posedge clk);
    rst_n = 1'b1;
    clear_frame();

    /* Pixel 0 creates active, pixel 1 creates pending.  When pixel 2
     * completes, ready simultaneously consumes active: pending advances to
     * active and the new token must refill pending instead of being lost.
     * Pixel 3 is also retained while those three tokens drain. */
    drive_pixel(11'd0, 1'b0);
    drive_pixel(11'd1, 1'b0);
    drive_pixel(11'd2, 1'b0);
    check_ok(valid && dut.pending_valid_r && !overflow,
             "directed setup did not fill active and pending slots");
    drive_pixel(11'd3, 1'b1);
    @(negedge clk);
    in_de = 1'b0;
    ready = 1'b1;
    repeat (4) @(posedge clk);
    #1;
    check_ok(accepted == 4 && expected_index == 4,
             "active/pending collision lost one of the first four tokens");
    check_ok(!valid && !dut.pending_valid_r && !backlog && !overflow,
             "collision drain left backlog or overflow");

    /* With ready held low, a third completed token genuinely exceeds the
     * active+pending capacity.  Overflow must be sticky until frame_clr. */
    clear_frame();
    accepted = 0;
    expected_index = 0;
    drive_pixel(11'd0, 1'b0);
    drive_pixel(11'd1, 1'b0);
    drive_pixel(11'd2, 1'b0);
    drive_pixel(11'd3, 1'b0);
    check_ok(overflow && valid && dut.pending_valid_r,
             "true two-slot overrun did not assert sticky overflow");
    repeat (3) @(posedge clk);
    #1;
    check_ok(overflow, "overflow was not sticky before frame clear");
    clear_frame();
    @(posedge clk);
    #1;
    check_ok(!overflow && !backlog && !valid && !dut.pending_valid_r,
             "frame clear did not recover feature skid state");

    /* Recovery starts a fresh strict index stream. */
    drive_pixel(11'd0, 1'b1);
    @(negedge clk);
    in_de = 1'b0;
    ready = 1'b1;
    repeat (3) @(posedge clk);
    #1;
    check_ok(accepted == 1 && expected_index == 1 && !overflow,
             "post-overflow recovery did not restart at feature index zero");

    $display("cnn_feature_collision_tb PASS checks=%0d", checks);
    $finish;
end

endmodule
