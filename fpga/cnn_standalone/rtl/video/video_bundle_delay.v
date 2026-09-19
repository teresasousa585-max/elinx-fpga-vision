`timescale 1ns/1ns

module video_bundle_delay
#(
    parameter integer LATENCY = 179
)
(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        in_frame_start,
    input  wire        in_frame_end,
    input  wire        in_hs,
    input  wire        in_vs,
    input  wire        in_de,
    input  wire [10:0] in_x,
    input  wire [10:0] in_y,
    input  wire [7:0]  in_raw8,
    input  wire [23:0] in_rgb888,
    output wire        out_frame_start,
    output wire        out_frame_end,
    output wire        out_hs,
    output wire        out_vs,
    output wire        out_de,
    output wire [10:0] out_x,
    output wire [10:0] out_y,
    output wire [7:0]  out_raw8,
    output wire [23:0] out_rgb888
);

localparam integer BUNDLE_WIDTH = 59;

reg [BUNDLE_WIDTH-1:0] bundle_pipe_r [0:LATENCY];
reg [15:0]             fill_count_r;
reg                    pipe_ready_r;

integer i;

always @(posedge clk) begin
    bundle_pipe_r[0] <= {in_frame_start, in_frame_end, in_hs, in_vs,
                         in_de, in_x, in_y, in_raw8, in_rgb888};
    for (i = 1; i <= LATENCY; i = i + 1)
        bundle_pipe_r[i] <= bundle_pipe_r[i-1];
end

// The delayed bundle is pure data. Reset only the visibility guard so the
// large shift bank has no asynchronous clear, while stopped-clock assertion
// and stale-data suppression remain immediate at the module outputs.
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        fill_count_r <= 16'd0;
        pipe_ready_r <= 1'b0;
    end else if (!pipe_ready_r) begin
        if (fill_count_r == LATENCY) begin
            pipe_ready_r <= 1'b1;
        end else begin
            fill_count_r <= fill_count_r + 1'b1;
        end
    end
end

assign {out_frame_start, out_frame_end, out_hs, out_vs, out_de,
        out_x, out_y, out_raw8, out_rgb888} = pipe_ready_r
        ? bundle_pipe_r[LATENCY] : {BUNDLE_WIDTH{1'b0}};

endmodule
