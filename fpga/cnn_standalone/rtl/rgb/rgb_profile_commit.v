`timescale 1ns/1ns

module rgb_profile_commit
(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       frame_epoch,
    input  wire       request_valid,
    input  wire [1:0] request_color_mode,
    input  wire [3:0] request_stage_view,
    input  wire [1:0] request_skin_level,
    input  wire [1:0] request_color_temp,
    output reg  [1:0] active_color_mode,
    output reg  [3:0] active_stage_view,
    output reg  [1:0] active_skin_level,
    output reg  [1:0] active_color_temp,
    output reg        pending
);

localparam [1:0] COLOR_MODE_BALANCED = 2'd1;
localparam [3:0] STAGE_VIEW_FINAL    = 4'd12;
localparam [1:0] SKIN_LEVEL_OFF      = 2'd0;
localparam [1:0] COLOR_TEMP_NEUTRAL  = 2'd0;

reg [1:0] pending_color_mode_r;
reg [3:0] pending_stage_view_r;
reg [1:0] pending_skin_level_r;
reg [1:0] pending_color_temp_r;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        active_color_mode    <= COLOR_MODE_BALANCED;
        active_stage_view    <= STAGE_VIEW_FINAL;
        active_skin_level    <= SKIN_LEVEL_OFF;
        active_color_temp    <= COLOR_TEMP_NEUTRAL;
        pending_color_mode_r <= COLOR_MODE_BALANCED;
        pending_stage_view_r <= STAGE_VIEW_FINAL;
        pending_skin_level_r <= SKIN_LEVEL_OFF;
        pending_color_temp_r <= COLOR_TEMP_NEUTRAL;
        pending              <= 1'b0;
    end else if (frame_epoch) begin
        if (request_valid) begin
            active_color_mode <= request_color_mode;
            active_stage_view <= request_stage_view;
            active_skin_level <= request_skin_level;
            active_color_temp <= request_color_temp;
        end else if (pending) begin
            active_color_mode <= pending_color_mode_r;
            active_stage_view <= pending_stage_view_r;
            active_skin_level <= pending_skin_level_r;
            active_color_temp <= pending_color_temp_r;
        end
        pending <= 1'b0;
    end else if (request_valid) begin
        pending_color_mode_r <= request_color_mode;
        pending_stage_view_r <= request_stage_view;
        pending_skin_level_r <= request_skin_level;
        pending_color_temp_r <= request_color_temp;
        pending              <= 1'b1;
    end
end

endmodule
