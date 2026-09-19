`timescale 1ns/1ps

/* Pixel-accurate CNN display-path check:
 * source RAW/x/y -> production RGB pipeline -> CNN branch of mode mux ->
 * unified OSD (6 cycles).  The RGB core reconstructs coordinates
 * from the DE raster, so this test drives complete 1280-pixel active lines
 * instead of unrealistic isolated DE pulses. */
module cnn_rgb_osd_alignment_tb;

localparam integer H_DISP = 1280;
localparam integer V_DISP = 720;
localparam integer RGB_LATENCY = 179;
localparam integer OSD_LATENCY = 6;
/* Registered producer-to-consumer boundary contributes one cycle. */
localparam integer TOTAL_LATENCY = RGB_LATENCY + 1 + OSD_LATENCY;
localparam [1:0] MODE_CNN = 2'd3;

reg clk = 1'b0;
always #5 clk = ~clk;
reg rst_n;
reg [1:0] active_mode;
reg [1:0] gesture_view;
reg in_vs;
reg in_de;
reg [10:0] in_x;
reg [10:0] in_y;
reg [7:0] in_raw;

wire rgb_fs;
wire rgb_fe;
wire rgb_hs;
wire rgb_vs;
wire rgb_de;
wire [10:0] rgb_x;
wire [10:0] rgb_y;
wire [7:0] rgb_raw;
wire [23:0] rgb_pixel;
wire mux_fs;
wire mux_fe;
wire mux_hs;
wire mux_vs;
wire mux_de;
wire [10:0] mux_x;
wire [10:0] mux_y;
wire [7:0] mux_raw;
wire [23:0] mux_rgb;
wire out_de;
wire [10:0] out_x;
wire [10:0] out_y;
wire [7:0] out_raw;
wire [23:0] out_rgb;

integer checks;
integer cycle_count;
integer launch_cycle [0:9];
reg case_seen [0:9];
integer seen_count;
integer frame_case_base;
integer i;

rgb_video_pipeline #(
    .H_DISP(H_DISP), .V_DISP(V_DISP), .EXTERNAL_LATENCY(RGB_LATENCY)
) u_rgb_pipeline (
    .clk(clk), .rst_n(rst_n),
    .in_frame_start(1'b0), .in_frame_end(1'b0),
    .in_hs(1'b0), .in_vs(in_vs), .in_de(in_de),
    .in_x(in_x), .in_y(in_y), .in_raw8(in_raw),
    .in_rgb888({in_raw, in_raw, in_raw}),
    .active_color_mode(2'd1), .active_stage_view(4'd0),
    .active_skin_level(2'd0), .active_color_temp(2'd0),
    .out_frame_start(rgb_fs), .out_frame_end(rgb_fe),
    .out_hs(rgb_hs), .out_vs(rgb_vs), .out_de(rgb_de),
    .out_x(rgb_x), .out_y(rgb_y), .out_raw8(rgb_raw),
    .out_rgb888(rgb_pixel)
);

video_mode_mux4 u_mode_mux (
    .active_mode(active_mode),
    .raw_frame_start(1'b0), .raw_frame_end(1'b0),
    .raw_hs(1'b0), .raw_vs(1'b0), .raw_de(1'b0),
    .raw_x(11'd0), .raw_y(11'd0), .raw_raw8(8'd0),
    .raw_rgb888(24'h110000),
    .rgb_frame_start(1'b0), .rgb_frame_end(1'b0),
    .rgb_hs(1'b0), .rgb_vs(1'b0), .rgb_de(1'b0),
    .rgb_x(11'd0), .rgb_y(11'd0), .rgb_raw8(8'd0),
    .rgb_rgb888(24'h001100),
    .edge_frame_start(1'b0), .edge_frame_end(1'b0),
    .edge_hs(1'b0), .edge_vs(1'b0), .edge_de(1'b0),
    .edge_x(11'd0), .edge_y(11'd0), .edge_raw8(8'd0),
    .edge_rgb888(24'h000011),
    .cnn_frame_start(rgb_fs), .cnn_frame_end(rgb_fe),
    .cnn_hs(rgb_hs), .cnn_vs(rgb_vs), .cnn_de(rgb_de),
    .cnn_x(rgb_x), .cnn_y(rgb_y), .cnn_raw8(rgb_raw),
    .cnn_rgb888(rgb_pixel),
    .out_frame_start(mux_fs), .out_frame_end(mux_fe),
    .out_hs(mux_hs), .out_vs(mux_vs), .out_de(mux_de),
    .out_x(mux_x), .out_y(mux_y), .out_raw8(mux_raw),
    .out_rgb888(mux_rgb)
);

video_osd_overlay u_osd (
    .clk(clk), .rst_n(rst_n), .active_mode(active_mode),
    .fps_tens(4'd6), .fps_ones(4'd0),
    .status_setting(1'b0), .status_snapshot(1'b0),
    .status_error(1'b0), .rgb_color_mode(2'd1),
    .rgb_stage_view(4'd0), .rgb_skin_level(2'd0),
    .rgb_color_temp(2'd0), .edge_mode(2'd0),
    .edge_threshold_index(4'd3), .edge_filter(1'b0),
    .gesture_view(gesture_view), .cnn_digit_valid(1'b0),
    .cnn_digit(4'd0), .in_frame_start(mux_fs),
    .in_frame_end(mux_fe), .in_hs(mux_hs), .in_vs(mux_vs),
    .in_de(mux_de), .in_x(mux_x), .in_y(mux_y),
    .in_raw8(mux_raw), .in_rgb888(mux_rgb),
    .out_frame_start(), .out_frame_end(), .out_hs(), .out_vs(),
    .out_de(out_de), .out_x(out_x), .out_y(out_y),
    .out_raw8(out_raw), .out_rgb888(out_rgb)
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

function [7:0] source_raw;
    input [1:0] view;
    input integer px;
    input integer py;
    begin
        source_raw = 8'd200;
        if (view == 2'd0 && px == 500 && py == 300)
            source_raw = 8'd42;
        else if (view == 2'd1 && py == 200
              && px >= 319 && px <= 321)
            source_raw = 8'd16;
        else if (view == 2'd1 && px == 959 && py == 615)
            source_raw = 8'd16;
        else if (view == 2'd2 && px == 319 && py == 105)
            source_raw = 8'd0;
        else if (view == 2'd2 && px == 320 && py == 104)
            source_raw = 8'd0;
        else if (view == 2'd2 && px == 321 && py == 105)
            source_raw = 8'd112;
        else if (view == 2'd2 && px == 322 && py == 105)
            source_raw = 8'd113;
        else if (view == 2'd2 && px == 959 && py == 615)
            source_raw = 8'd0;
    end
endfunction

task mark_launch;
    input [1:0] view;
    input integer px;
    input integer py;
    begin
        if (view == 2'd0 && px == 500 && py == 300)
            launch_cycle[0] = cycle_count + 1;
        else if (view == 2'd1 && px == 319 && py == 200)
            launch_cycle[1] = cycle_count + 1;
        else if (view == 2'd1 && px == 320 && py == 200)
            launch_cycle[2] = cycle_count + 1;
        else if (view == 2'd1 && px == 321 && py == 200)
            launch_cycle[3] = cycle_count + 1;
        else if (view == 2'd1 && px == 959 && py == 615)
            launch_cycle[4] = cycle_count + 1;
        else if (view == 2'd2 && px == 319 && py == 105)
            launch_cycle[5] = cycle_count + 1;
        else if (view == 2'd2 && px == 320 && py == 104)
            launch_cycle[6] = cycle_count + 1;
        else if (view == 2'd2 && px == 321 && py == 105)
            launch_cycle[7] = cycle_count + 1;
        else if (view == 2'd2 && px == 322 && py == 105)
            launch_cycle[8] = cycle_count + 1;
        else if (view == 2'd2 && px == 959 && py == 615)
            launch_cycle[9] = cycle_count + 1;
    end
endtask

task check_case;
    input integer case_id;
    input [7:0] expected_raw;
    input [23:0] expected_rgb;
    begin
        check_ok(!case_seen[case_id], "aligned target pixel appeared more than once");
        check_ok(out_raw == expected_raw, "aligned RAW sideband differs from source pixel");
        check_ok(out_rgb == expected_rgb, "CNN ROI/MASK overlay color differs at aligned coordinate");
        check_ok((cycle_count - launch_cycle[case_id]) == TOTAL_LATENCY,
                 "RGB plus registered boundary plus OSD latency mismatch");
        case_seen[case_id] = 1'b1;
        seen_count = seen_count + 1;
        $display("CNN_ALIGN_CASE id=%0d view=%0d xy=%0d,%0d raw=%0d rgb=%06h latency=%0d",
                 case_id, gesture_view, out_x, out_y, out_raw, out_rgb,
                 cycle_count-launch_cycle[case_id]);
    end
endtask

task run_raster;
    input [1:0] view;
    input integer last_y;
    integer px;
    integer py;
    integer seen_before;
    integer expected_new;
    begin
        gesture_view = view;
        seen_before = seen_count;
        expected_new = (view == 2'd0) ? 1 : ((view == 2'd1) ? 4 : 5);
        @(negedge clk);
        in_vs = 1'b1;
        in_de = 1'b0;
        @(negedge clk);
        in_vs = 1'b0;
        for (py = 0; py <= last_y; py = py + 1) begin
            for (px = 0; px < H_DISP; px = px + 1) begin
                @(negedge clk);
                in_de = 1'b1;
                in_x = px[10:0];
                in_y = py[10:0];
                in_raw = source_raw(view, px, py);
                mark_launch(view, px, py);
            end
        end
        @(negedge clk);
        in_de = 1'b0;
        in_x = 11'd0;
        in_y = 11'd0;
        in_raw = 8'd0;
        repeat (TOTAL_LATENCY + 12) @(posedge clk);
        #1;
        check_ok(seen_count == seen_before + expected_new,
                 "continuous raster did not cover every expected alignment target");
    end
endtask

always @(posedge clk) begin
    cycle_count = cycle_count + 1;
    #1;
    if (rst_n && out_de) begin
        if (gesture_view == 2'd0 && out_x == 500 && out_y == 300)
            check_case(0, 8'd42, 24'h2a2a2a);
        else if (gesture_view == 2'd1 && out_x == 319 && out_y == 200)
            check_case(1, 8'd16, 24'h101010);
        else if (gesture_view == 2'd1 && out_x == 320 && out_y == 200)
            check_case(2, 8'd16, 24'h00ff00);
        else if (gesture_view == 2'd1 && out_x == 321 && out_y == 200)
            check_case(3, 8'd16, 24'h101010);
        else if (gesture_view == 2'd1 && out_x == 959 && out_y == 615)
            check_case(4, 8'd16, 24'h00ff00);
        else if (gesture_view == 2'd2 && out_x == 319 && out_y == 105)
            check_case(5, 8'd0, 24'h000000);
        else if (gesture_view == 2'd2 && out_x == 320 && out_y == 104)
            check_case(6, 8'd0, 24'h00ff00);
        else if (gesture_view == 2'd2 && out_x == 321 && out_y == 105)
            check_case(7, 8'd112, 24'hff0000);
        else if (gesture_view == 2'd2 && out_x == 322 && out_y == 105)
            check_case(8, 8'd113, 24'h717171);
        else if (gesture_view == 2'd2 && out_x == 959 && out_y == 615)
            check_case(9, 8'd0, 24'h00ff00);
    end
end

initial begin
    checks = 0;
    cycle_count = 0;
    seen_count = 0;
    rst_n = 1'b0;
    active_mode = MODE_CNN;
    gesture_view = 2'd0;
    in_vs = 1'b0;
    in_de = 1'b0;
    in_x = 11'd0;
    in_y = 11'd0;
    in_raw = 8'd0;
    for (i = 0; i < 10; i = i + 1) begin
        launch_cycle[i] = -1;
        case_seen[i] = 1'b0;
    end
    repeat (6) @(posedge clk);
    rst_n = 1'b1;
    repeat (4) @(posedge clk);

    run_raster(2'd0, 300); // CLEAN
    run_raster(2'd1, 615); // ROI border/interior/exterior
    run_raster(2'd2, 615); // MASK threshold/border/exterior

    check_ok(seen_count == 10, "incomplete CNN RGB/ROI/MASK alignment matrix");
    $display("cnn_rgb_osd_alignment_tb PASS checks=%0d cases=%0d total_latency=%0d",
             checks, seen_count, TOTAL_LATENCY);
    $finish;
end

endmodule
