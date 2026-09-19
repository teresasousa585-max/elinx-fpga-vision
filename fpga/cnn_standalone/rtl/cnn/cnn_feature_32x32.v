`timescale 1ns/1ns

module cnn_feature_32x32
#(
    parameter SEARCH_X = 320,
    parameter SEARCH_Y = 104,
    parameter SEARCH_W = 640,
    parameter SEARCH_H = 512,
    parameter DARK_TH  = 8'd112
)
(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        frame_clr,
    input  wire        in_de,
    input  wire [7:0]  in_raw,
    input  wire [10:0] in_xpos,
    input  wire [10:0] in_ypos,
    input  wire        feature_ready,
    output reg         feature_valid,
    output reg         feature_frame_done,
    output reg  [9:0]  feature_index,
    output reg  [5:0]  feature_value,
    output reg         bbox_valid,
    output reg  [6:0]  bbox_left,
    output reg  [6:0]  bbox_right,
    output reg  [6:0]  bbox_top,
    output reg  [6:0]  bbox_bottom,
    output reg         feature_overflow,
    output wire        feature_backlog
);

localparam integer FEATURE_ROWS = 32;
localparam integer FEATURE_COLS = 32;
localparam integer CELL_W_PIXELS = SEARCH_W / FEATURE_COLS;
localparam integer CELL_H_PIXELS = SEARCH_H / FEATURE_ROWS;
localparam integer SEARCH_X1_INT = SEARCH_X + SEARCH_W - 1;
localparam integer SEARCH_Y1_INT = SEARCH_Y + SEARCH_H - 1;
localparam integer CELL_W_LAST_INT = CELL_W_PIXELS - 1;
localparam integer CELL_H_LAST_INT = CELL_H_PIXELS - 1;
localparam [10:0] SEARCH_X0 = SEARCH_X[10:0];
localparam [10:0] SEARCH_Y0 = SEARCH_Y[10:0];
localparam [10:0] SEARCH_X1 = SEARCH_X1_INT[10:0];
localparam [10:0] SEARCH_Y1 = SEARCH_Y1_INT[10:0];
localparam [4:0]  CELL_W_LAST = CELL_W_LAST_INT[4:0];
localparam [3:0]  CELL_H_LAST = CELL_H_LAST_INT[3:0];
localparam [8:0]  ACTIVE_COUNT_TH = 9'd80;

reg [8:0] col_acc [0:FEATURE_COLS-1];
reg [4:0] cell_x_r;
reg [4:0] cell_y_r;
reg [4:0] sub_x_r;
reg [3:0] sub_y_r;
reg       pix_valid_s1_r;
reg       pix_dark_s1_r;
reg       pix_cell_last_s1_r;
reg [4:0] pix_cell_x_s1_r;
reg [4:0] pix_cell_y_s1_r;
reg       pending_valid_r;
reg       pending_frame_done_r;
reg [9:0] pending_index_r;
reg [5:0] pending_value_r;

wire feature_slot_free_w;
wire roi_pixel_w;
wire roi_line_end_w;
wire dark_pixel_w;
wire cell_last_w;
wire density_token_w;
wire density_final_token_w;
wire [8:0] col_count_next_w;
wire [5:0] density_value_w;
wire [9:0] density_feature_index_w;
wire active_cell_w;
wire [6:0] bbox_cell_left_w;
wire [6:0] bbox_cell_right_w;
wire [6:0] bbox_cell_top_w;
wire [6:0] bbox_cell_bottom_w;

integer init_i;

assign feature_slot_free_w = !feature_valid || feature_ready;
assign feature_backlog = feature_valid || pending_valid_r || pix_valid_s1_r;
assign roi_pixel_w = in_de &&
                     (in_xpos >= SEARCH_X0) && (in_xpos <= SEARCH_X1) &&
                     (in_ypos >= SEARCH_Y0) && (in_ypos <= SEARCH_Y1);
assign roi_line_end_w = roi_pixel_w && (in_xpos == SEARCH_X1);
assign dark_pixel_w = in_raw <= DARK_TH;
assign cell_last_w = roi_pixel_w && (sub_x_r == CELL_W_LAST) && (sub_y_r == CELL_H_LAST);
assign density_token_w = pix_valid_s1_r && pix_cell_last_s1_r;
assign density_final_token_w = density_token_w &&
                               (pix_cell_x_s1_r == 5'd31) &&
                               (pix_cell_y_s1_r == 5'd31);
assign col_count_next_w = col_acc[pix_cell_x_s1_r] + {8'd0, pix_dark_s1_r};
assign density_value_w = col_count_next_w[8:3];
assign density_feature_index_w = {pix_cell_y_s1_r, pix_cell_x_s1_r};
assign active_cell_w = col_count_next_w >= ACTIVE_COUNT_TH;
assign bbox_cell_left_w = {1'b0, pix_cell_x_s1_r, 1'b0};
assign bbox_cell_right_w = bbox_cell_left_w + 7'd1;
assign bbox_cell_top_w = {1'b0, pix_cell_y_s1_r, 1'b0};
assign bbox_cell_bottom_w = bbox_cell_top_w + 7'd1;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        feature_valid <= 1'b0;
        feature_frame_done <= 1'b0;
        feature_index <= 10'd0;
        feature_value <= 6'd0;
        bbox_valid <= 1'b0;
        bbox_left <= 7'd0;
        bbox_right <= 7'd0;
        bbox_top <= 7'd0;
        bbox_bottom <= 7'd0;
        cell_x_r <= 5'd0;
        cell_y_r <= 5'd0;
        sub_x_r <= 5'd0;
        sub_y_r <= 4'd0;
        pix_valid_s1_r <= 1'b0;
        pix_dark_s1_r <= 1'b0;
        pix_cell_last_s1_r <= 1'b0;
        pix_cell_x_s1_r <= 5'd0;
        pix_cell_y_s1_r <= 5'd0;
        pending_valid_r <= 1'b0;
        pending_frame_done_r <= 1'b0;
        pending_index_r <= 10'd0;
        pending_value_r <= 6'd0;
        feature_overflow <= 1'b0;
        for (init_i = 0; init_i < FEATURE_COLS; init_i = init_i + 1)
            col_acc[init_i] <= 9'd0;
    end else begin
        if (frame_clr) begin
            feature_valid <= 1'b0;
            feature_frame_done <= 1'b0;
            feature_index <= 10'd0;
            feature_value <= 6'd0;
            bbox_valid <= 1'b0;
            bbox_left <= 7'd0;
            bbox_right <= 7'd0;
            bbox_top <= 7'd0;
            bbox_bottom <= 7'd0;
            cell_x_r <= 5'd0;
            cell_y_r <= 5'd0;
            sub_x_r <= 5'd0;
            sub_y_r <= 4'd0;
            pix_valid_s1_r <= 1'b0;
            pix_dark_s1_r <= 1'b0;
            pix_cell_last_s1_r <= 1'b0;
            pix_cell_x_s1_r <= 5'd0;
            pix_cell_y_s1_r <= 5'd0;
            pending_valid_r <= 1'b0;
            pending_frame_done_r <= 1'b0;
            pending_index_r <= 10'd0;
            pending_value_r <= 6'd0;
            feature_overflow <= 1'b0;
            for (init_i = 0; init_i < FEATURE_COLS; init_i = init_i + 1)
                col_acc[init_i] <= 9'd0;
        end else begin
            if (feature_valid && feature_ready) begin
                feature_valid <= 1'b0;
                feature_frame_done <= 1'b0;
            end

            if (pix_valid_s1_r) begin
                if (pix_cell_last_s1_r) begin
                    col_acc[pix_cell_x_s1_r] <= 9'd0;
                    if (active_cell_w) begin
                        if (!bbox_valid) begin
                            bbox_valid <= 1'b1;
                            bbox_left <= bbox_cell_left_w;
                            bbox_right <= bbox_cell_right_w;
                            bbox_top <= bbox_cell_top_w;
                            bbox_bottom <= bbox_cell_bottom_w;
                        end else begin
                            if (bbox_left > bbox_cell_left_w)
                                bbox_left <= bbox_cell_left_w;
                            if (bbox_right < bbox_cell_right_w)
                                bbox_right <= bbox_cell_right_w;
                            if (bbox_top > bbox_cell_top_w)
                                bbox_top <= bbox_cell_top_w;
                            if (bbox_bottom < bbox_cell_bottom_w)
                                bbox_bottom <= bbox_cell_bottom_w;
                        end
                    end
                end else begin
                    col_acc[pix_cell_x_s1_r] <= col_count_next_w;
                end
            end

            if (feature_slot_free_w) begin
                if (pending_valid_r) begin
                    feature_valid <= 1'b1;
                    feature_frame_done <= pending_frame_done_r;
                    feature_index <= pending_index_r;
                    feature_value <= pending_value_r;
                    // If a new cell completes while the older pending token
                    // advances into the active slot, keep the new token in
                    // the pending slot.  Clearing pending unconditionally
                    // here silently dropped one token under backpressure.
                    if (density_token_w) begin
                        pending_valid_r <= 1'b1;
                        pending_frame_done_r <= density_final_token_w;
                        pending_index_r <= density_feature_index_w;
                        pending_value_r <= density_value_w;
                    end else begin
                        pending_valid_r <= 1'b0;
                    end
                end else if (density_token_w) begin
                    feature_valid <= 1'b1;
                    feature_frame_done <= density_final_token_w;
                    feature_index <= density_feature_index_w;
                    feature_value <= density_value_w;
                end
            end else if (density_token_w && !pending_valid_r) begin
                pending_valid_r <= 1'b1;
                pending_frame_done_r <= density_final_token_w;
                pending_index_r <= density_feature_index_w;
                pending_value_r <= density_value_w;
            end else if (density_token_w) begin
                // Input pixels cannot be back-pressured.  Preserve the older
                // pending token and make any impossible two-slot overrun
                // explicit so the session controller can abort safely.
                feature_overflow <= 1'b1;
            end

            pix_valid_s1_r <= roi_pixel_w;
            pix_dark_s1_r <= dark_pixel_w;
            pix_cell_last_s1_r <= cell_last_w;
            pix_cell_x_s1_r <= cell_x_r;
            pix_cell_y_s1_r <= cell_y_r;

            if (roi_pixel_w) begin
                if (roi_line_end_w) begin
                    cell_x_r <= 5'd0;
                    sub_x_r <= 5'd0;
                    if (sub_y_r == CELL_H_LAST) begin
                        sub_y_r <= 4'd0;
                        if (cell_y_r == 5'd31)
                            cell_y_r <= 5'd0;
                        else
                            cell_y_r <= cell_y_r + 5'd1;
                    end else begin
                        sub_y_r <= sub_y_r + 4'd1;
                    end
                end else if (sub_x_r == CELL_W_LAST) begin
                    sub_x_r <= 5'd0;
                    cell_x_r <= cell_x_r + 5'd1;
                end else begin
                    sub_x_r <= sub_x_r + 5'd1;
                end
            end
        end
    end
end

endmodule
