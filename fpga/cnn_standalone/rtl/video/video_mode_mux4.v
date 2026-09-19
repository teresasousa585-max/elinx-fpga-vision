`timescale 1ns/1ns

module video_mode_mux4
(
    input  wire [1:0]  active_mode,

    input  wire        raw_frame_start, input wire raw_frame_end,
    input  wire        raw_hs, input wire raw_vs, input wire raw_de,
    input  wire [10:0] raw_x, input wire [10:0] raw_y,
    input  wire [7:0]  raw_raw8, input wire [23:0] raw_rgb888,

    input  wire        rgb_frame_start, input wire rgb_frame_end,
    input  wire        rgb_hs, input wire rgb_vs, input wire rgb_de,
    input  wire [10:0] rgb_x, input wire [10:0] rgb_y,
    input  wire [7:0]  rgb_raw8, input wire [23:0] rgb_rgb888,

    input  wire        edge_frame_start, input wire edge_frame_end,
    input  wire        edge_hs, input wire edge_vs, input wire edge_de,
    input  wire [10:0] edge_x, input wire [10:0] edge_y,
    input  wire [7:0]  edge_raw8, input wire [23:0] edge_rgb888,

    input  wire        cnn_frame_start, input wire cnn_frame_end,
    input  wire        cnn_hs, input wire cnn_vs, input wire cnn_de,
    input  wire [10:0] cnn_x, input wire [10:0] cnn_y,
    input  wire [7:0]  cnn_raw8, input wire [23:0] cnn_rgb888,

    output reg         out_frame_start, output reg out_frame_end,
    output reg         out_hs, output reg out_vs, output reg out_de,
    output reg  [10:0] out_x, output reg [10:0] out_y,
    output reg  [7:0]  out_raw8, output reg [23:0] out_rgb888
);

/* One case statement selects the complete bundle; no field has its own select. */
always @* begin
    out_frame_start = raw_frame_start;
    out_frame_end   = raw_frame_end;
    out_hs          = raw_hs;
    out_vs          = raw_vs;
    out_de          = raw_de;
    out_x           = raw_x;
    out_y           = raw_y;
    out_raw8        = raw_raw8;
    out_rgb888      = raw_rgb888;

    case (active_mode)
        2'd1: begin
            out_frame_start = rgb_frame_start; out_frame_end = rgb_frame_end;
            out_hs = rgb_hs; out_vs = rgb_vs; out_de = rgb_de;
            out_x = rgb_x; out_y = rgb_y; out_raw8 = rgb_raw8; out_rgb888 = rgb_rgb888;
        end
        2'd2: begin
            out_frame_start = edge_frame_start; out_frame_end = edge_frame_end;
            out_hs = edge_hs; out_vs = edge_vs; out_de = edge_de;
            out_x = edge_x; out_y = edge_y; out_raw8 = edge_raw8; out_rgb888 = edge_rgb888;
        end
        2'd3: begin
            out_frame_start = cnn_frame_start; out_frame_end = cnn_frame_end;
            out_hs = cnn_hs; out_vs = cnn_vs; out_de = cnn_de;
            out_x = cnn_x; out_y = cnn_y; out_raw8 = cnn_raw8; out_rgb888 = cnn_rgb888;
        end
        default: begin end
    endcase
end

endmodule
