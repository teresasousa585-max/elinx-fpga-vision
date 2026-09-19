`timescale 1ns/1ns

module cnn_flat_classifier
#(
    parameter INPUT_COUNT = 1024,
    parameter CONV_OUT_CHANNELS = 4,
    parameter OUTPUT_COUNT = 10,
    parameter BBOX_ACTIVE_DENSITY_TH = 10,
    parameter BBOX_PADDING_CELLS = 2,
    parameter FEATURE_SUM_MAX = 30000,
    parameter CONFIDENCE_THRESHOLD = 1
)
(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        soft_reset,
    input  wire        frame_clr,
    input  wire        feature_valid,
    input  wire        feature_frame_done,
    input  wire [9:0]  feature_index,
    input  wire [5:0]  feature_value,
    output reg         candidate_valid,
    output reg  [3:0]  candidate_digit,
    output reg         candidate_unknown,
    output reg  [15:0] candidate_distance,
    output wire        busy,
    output wire        feature_write_pulse,
    output wire        bbox_write_pulse,
    output wire [3:0]  state_debug
);

localparam [3:0] ST_IDLE           = 4'd0;
localparam [3:0] ST_PREPARE        = 4'd1;
localparam [3:0] ST_CONV_BIAS      = 4'd2;
localparam [3:0] ST_CONV_BIAS_WAIT = 4'd3;
localparam [3:0] ST_CONV_BIAS_LOAD = 4'd4;
localparam [3:0] ST_CONV_ISSUE     = 4'd5;
localparam [3:0] ST_CONV_WAIT      = 4'd6;
localparam [3:0] ST_CONV_MAC       = 4'd7;
localparam [3:0] ST_CONV_SAVE      = 4'd8;
localparam [3:0] ST_FC_BIAS        = 4'd9;
localparam [3:0] ST_FC_BIAS_WAIT   = 4'd10;
localparam [3:0] ST_FC_BIAS_LOAD   = 4'd11;
localparam [3:0] ST_FC_ISSUE       = 4'd12;
localparam [3:0] ST_FC_WAIT        = 4'd13;
localparam [3:0] ST_FC_MAC         = 4'd14;
localparam [3:0] ST_FC_SCORE       = 4'd15;

localparam [9:0] INPUT_LAST = INPUT_COUNT - 10'd1;
localparam [1:0] CONV_CH_LAST = CONV_OUT_CHANNELS - 2'd1;
localparam [11:0] CONV_FLAT_LAST = (CONV_OUT_CHANNELS * INPUT_COUNT) - 12'd1;
localparam [3:0] OUTPUT_LAST = OUTPUT_COUNT - 4'd1;
localparam [5:0] BBOX_ACTIVE_TH = BBOX_ACTIVE_DENSITY_TH[5:0];
localparam [4:0] BBOX_PAD = BBOX_PADDING_CELLS[4:0];
localparam [15:0] FEATURE_SUM_MAX_U16 = FEATURE_SUM_MAX[15:0];

(* ramstyle = "M9K" *) reg [5:0] feature_mem [0:INPUT_COUNT-1];
(* ramstyle = "M9K" *) reg signed [23:0] conv_mem [0:(CONV_OUT_CHANNELS*INPUT_COUNT)-1];

reg [3:0] state_r;
reg [9:0] feature_rd_addr_r;
reg [5:0] feature_q_r;
reg [11:0] conv_rd_addr_r;
reg signed [23:0] conv_q_r;
reg [1:0] conv_ch_r;
reg [9:0] conv_idx_r;
reg [3:0] kernel_idx_r;
reg kernel_valid_r;
reg [11:0] conv_wr_addr_r;
reg [3:0] output_idx_r;
reg [11:0] fc_idx_r;
reg signed [47:0] acc_r;
reg signed [47:0] best_score_r;
reg signed [47:0] second_score_r;
reg [3:0] best_digit_r;
reg best_valid_r;
reg second_valid_r;
reg bbox_valid_r;
reg [4:0] bbox_left_r;
reg [4:0] bbox_right_r;
reg [4:0] bbox_top_r;
reg [4:0] bbox_bottom_r;
reg [15:0] feature_sum_r;

reg [5:0]  conv_w_addr_r;
reg [7:0]  conv_b_addr_r;
reg [15:0] fc_w_addr_r;
reg [7:0]  fc_b_addr_r;

wire signed [7:0] conv_w_q_w;
wire signed [31:0] conv_b_q_w;
wire signed [7:0] fc_w_q_w;
wire signed [31:0] fc_b_q_w;
wire signed [47:0] conv_b_ext_w;
wire signed [47:0] fc_b_ext_w;
wire signed [7:0] feature_ext_w;
wire signed [15:0] conv_product_w;
wire signed [47:0] conv_product_ext_w;
wire signed [31:0] fc_product_w;
wire signed [47:0] fc_product_ext_w;
wire signed [47:0] output_score_w;
wire score_gt_best_w;
wire score_gt_second_w;
wire signed [47:0] next_best_score_w;
wire signed [47:0] next_second_score_w;
wire [3:0] next_best_digit_w;
wire next_best_valid_w;
wire next_second_valid_w;
wire signed [47:0] next_margin_w;
wire [15:0] next_margin_u16_w;
wire [4:0] feature_x_w;
wire [4:0] feature_y_w;
wire feature_active_w;
wire [15:0] feature_value_u16_w;
wire [15:0] feature_sum_plus_w;
wire [4:0] bbox_left_pad_w;
wire [4:0] bbox_right_pad_w;
wire [4:0] bbox_top_pad_w;
wire [4:0] bbox_bottom_pad_w;
wire [5:0] norm_bbox_width_w;
wire [5:0] norm_bbox_height_w;
wire [4:0] conv_x_w;
wire [4:0] conv_y_w;
wire kernel_left_w;
wire kernel_right_w;
wire kernel_top_w;
wire kernel_bottom_w;
wire kernel_outside_w;
wire [4:0] norm_x_w;
wire [4:0] norm_y_w;
wire [10:0] norm_x_prod_w;
wire [10:0] norm_y_prod_w;
wire [5:0] norm_src_x_offset_w;
wire [5:0] norm_src_y_offset_w;
wire [5:0] norm_src_x_wide_w;
wire [5:0] norm_src_y_wide_w;
wire [9:0] norm_feature_rd_addr_w;
wire norm_input_invalid_w;
wire collect_write_w;

assign collect_write_w = feature_valid && (state_r == ST_IDLE) && !soft_reset;
assign busy = (state_r != ST_IDLE);
assign feature_write_pulse = collect_write_w;
assign bbox_write_pulse = collect_write_w;
assign state_debug = state_r;

assign conv_b_ext_w = $signed({{16{conv_b_q_w[31]}}, conv_b_q_w});
assign fc_b_ext_w = $signed({{16{fc_b_q_w[31]}}, fc_b_q_w});
assign feature_ext_w = $signed({2'b00, feature_q_r});
assign conv_product_w = conv_w_q_w * feature_ext_w;
assign conv_product_ext_w = $signed({{32{conv_product_w[15]}}, conv_product_w});
assign fc_product_w = $signed({{24{fc_w_q_w[7]}}, fc_w_q_w}) * $signed({{8{conv_q_r[23]}}, conv_q_r});
assign fc_product_ext_w = $signed({{16{fc_product_w[31]}}, fc_product_w});
assign output_score_w = acc_r;
assign score_gt_best_w = (!best_valid_r) || (output_score_w > best_score_r);
assign score_gt_second_w = (!second_valid_r) || (output_score_w > second_score_r);
assign next_best_score_w = score_gt_best_w ? output_score_w : best_score_r;
assign next_best_digit_w = score_gt_best_w ? output_idx_r : best_digit_r;
assign next_best_valid_w = 1'b1;
assign next_second_score_w = score_gt_best_w ? best_score_r :
                             (score_gt_second_w ? output_score_w : second_score_r);
assign next_second_valid_w = score_gt_best_w ? best_valid_r :
                             (score_gt_second_w ? 1'b1 : second_valid_r);
assign next_margin_w = next_second_valid_w ? (next_best_score_w - next_second_score_w) : 48'sd0;
assign next_margin_u16_w = (next_margin_w <= 48'sd0) ? 16'd0 :
                           (next_margin_w > 48'sd65535) ? 16'hffff :
                           next_margin_w[15:0];

assign feature_x_w = feature_index[4:0];
assign feature_y_w = feature_index[9:5];
assign feature_active_w = feature_value >= BBOX_ACTIVE_TH;
assign feature_value_u16_w = {10'd0, feature_value};
assign feature_sum_plus_w = feature_sum_r + feature_value_u16_w;
assign bbox_left_pad_w = (bbox_left_r > BBOX_PAD) ? (bbox_left_r - BBOX_PAD) : 5'd0;
assign bbox_right_pad_w = (bbox_right_r >= (5'd31 - BBOX_PAD)) ? 5'd31 : (bbox_right_r + BBOX_PAD);
assign bbox_top_pad_w = (bbox_top_r > BBOX_PAD) ? (bbox_top_r - BBOX_PAD) : 5'd0;
assign bbox_bottom_pad_w = (bbox_bottom_r >= (5'd31 - BBOX_PAD)) ? 5'd31 : (bbox_bottom_r + BBOX_PAD);
assign norm_bbox_width_w = {1'b0, bbox_right_pad_w} - {1'b0, bbox_left_pad_w} + 6'd1;
assign norm_bbox_height_w = {1'b0, bbox_bottom_pad_w} - {1'b0, bbox_top_pad_w} + 6'd1;

assign conv_x_w = conv_idx_r[4:0];
assign conv_y_w = conv_idx_r[9:5];
assign kernel_left_w = (kernel_idx_r == 4'd0) || (kernel_idx_r == 4'd3) || (kernel_idx_r == 4'd6);
assign kernel_right_w = (kernel_idx_r == 4'd2) || (kernel_idx_r == 4'd5) || (kernel_idx_r == 4'd8);
assign kernel_top_w = (kernel_idx_r == 4'd0) || (kernel_idx_r == 4'd1) || (kernel_idx_r == 4'd2);
assign kernel_bottom_w = (kernel_idx_r == 4'd6) || (kernel_idx_r == 4'd7) || (kernel_idx_r == 4'd8);
assign kernel_outside_w = (kernel_left_w && (conv_x_w == 5'd0)) ||
                          (kernel_right_w && (conv_x_w == 5'd31)) ||
                          (kernel_top_w && (conv_y_w == 5'd0)) ||
                          (kernel_bottom_w && (conv_y_w == 5'd31));
assign norm_x_w = kernel_left_w ? (conv_x_w - 5'd1) :
                  (kernel_right_w ? (conv_x_w + 5'd1) : conv_x_w);
assign norm_y_w = kernel_top_w ? (conv_y_w - 5'd1) :
                  (kernel_bottom_w ? (conv_y_w + 5'd1) : conv_y_w);
assign norm_x_prod_w = {6'd0, norm_x_w} * {5'd0, norm_bbox_width_w};
assign norm_y_prod_w = {6'd0, norm_y_w} * {5'd0, norm_bbox_height_w};
assign norm_src_x_offset_w = norm_x_prod_w[10:5];
assign norm_src_y_offset_w = norm_y_prod_w[10:5];
assign norm_src_x_wide_w = {1'b0, bbox_left_pad_w} + norm_src_x_offset_w;
assign norm_src_y_wide_w = {1'b0, bbox_top_pad_w} + norm_src_y_offset_w;
assign norm_feature_rd_addr_w = {norm_src_y_wide_w[4:0], norm_src_x_wide_w[4:0]};
assign norm_input_invalid_w = !bbox_valid_r || (feature_sum_r > FEATURE_SUM_MAX_U16);

cnn_weight_rom u_cnn_weight_rom
(
    .clk        (clk),
    .conv_w_addr(conv_w_addr_r),
    .conv_w_q   (conv_w_q_w),
    .conv_b_addr(conv_b_addr_r),
    .conv_b_q   (conv_b_q_w),
    .fc_w_addr  (fc_w_addr_r),
    .fc_w_q     (fc_w_q_w),
    .fc_b_addr  (fc_b_addr_r),
    .fc_b_q     (fc_b_q_w)
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        feature_q_r <= 6'd0;
        conv_q_r <= 24'sd0;
    end else if (soft_reset) begin
        feature_q_r <= 6'd0;
        conv_q_r <= 24'sd0;
    end else begin
        if (collect_write_w)
            feature_mem[feature_index] <= feature_value;
        feature_q_r <= feature_mem[feature_rd_addr_r];
        conv_q_r <= conv_mem[conv_rd_addr_r];
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state_r <= ST_IDLE;
        feature_rd_addr_r <= 10'd0;
        conv_rd_addr_r <= 12'd0;
        conv_ch_r <= 2'd0;
        conv_idx_r <= 10'd0;
        kernel_idx_r <= 4'd0;
        kernel_valid_r <= 1'b0;
        conv_wr_addr_r <= 12'd0;
        output_idx_r <= 4'd0;
        fc_idx_r <= 12'd0;
        acc_r <= 48'sd0;
        best_score_r <= 48'sh8000_0000_0000;
        second_score_r <= 48'sh8000_0000_0000;
        best_digit_r <= 4'd0;
        best_valid_r <= 1'b0;
        second_valid_r <= 1'b0;
        bbox_valid_r <= 1'b0;
        bbox_left_r <= 5'd31;
        bbox_right_r <= 5'd0;
        bbox_top_r <= 5'd31;
        bbox_bottom_r <= 5'd0;
        feature_sum_r <= 16'd0;
        conv_w_addr_r <= 6'd0;
        conv_b_addr_r <= 8'd0;
        fc_w_addr_r <= 16'd0;
        fc_b_addr_r <= 8'd0;
        candidate_valid <= 1'b0;
        candidate_digit <= 4'd0;
        candidate_unknown <= 1'b1;
        candidate_distance <= 16'd0;
    end else if (soft_reset) begin
        state_r <= ST_IDLE;
        feature_rd_addr_r <= 10'd0;
        conv_rd_addr_r <= 12'd0;
        conv_ch_r <= 2'd0;
        conv_idx_r <= 10'd0;
        kernel_idx_r <= 4'd0;
        kernel_valid_r <= 1'b0;
        conv_wr_addr_r <= 12'd0;
        output_idx_r <= 4'd0;
        fc_idx_r <= 12'd0;
        acc_r <= 48'sd0;
        best_score_r <= 48'sh8000_0000_0000;
        second_score_r <= 48'sh8000_0000_0000;
        best_digit_r <= 4'd0;
        best_valid_r <= 1'b0;
        second_valid_r <= 1'b0;
        bbox_valid_r <= 1'b0;
        bbox_left_r <= 5'd31;
        bbox_right_r <= 5'd0;
        bbox_top_r <= 5'd31;
        bbox_bottom_r <= 5'd0;
        feature_sum_r <= 16'd0;
        conv_w_addr_r <= 6'd0;
        conv_b_addr_r <= 8'd0;
        fc_w_addr_r <= 16'd0;
        fc_b_addr_r <= 8'd0;
        candidate_valid <= 1'b0;
        candidate_digit <= 4'd0;
        candidate_unknown <= 1'b1;
        candidate_distance <= 16'd0;
    end else begin
        candidate_valid <= 1'b0;

        if (collect_write_w) begin
            if (feature_index == 10'd0) begin
                feature_sum_r <= feature_value_u16_w;
                if (feature_active_w) begin
                    bbox_valid_r <= 1'b1;
                    bbox_left_r <= feature_x_w;
                    bbox_right_r <= feature_x_w;
                    bbox_top_r <= feature_y_w;
                    bbox_bottom_r <= feature_y_w;
                end else begin
                    bbox_valid_r <= 1'b0;
                    bbox_left_r <= 5'd31;
                    bbox_right_r <= 5'd0;
                    bbox_top_r <= 5'd31;
                    bbox_bottom_r <= 5'd0;
                end
            end else begin
                feature_sum_r <= feature_sum_plus_w;
                if (feature_active_w) begin
                    if (!bbox_valid_r) begin
                        bbox_valid_r <= 1'b1;
                        bbox_left_r <= feature_x_w;
                        bbox_right_r <= feature_x_w;
                        bbox_top_r <= feature_y_w;
                        bbox_bottom_r <= feature_y_w;
                    end else begin
                        if (bbox_left_r > feature_x_w)
                            bbox_left_r <= feature_x_w;
                        if (bbox_right_r < feature_x_w)
                            bbox_right_r <= feature_x_w;
                        if (bbox_top_r > feature_y_w)
                            bbox_top_r <= feature_y_w;
                        if (bbox_bottom_r < feature_y_w)
                            bbox_bottom_r <= feature_y_w;
                    end
                end
            end
        end

        if (frame_clr && (state_r == ST_IDLE)) begin
            state_r <= ST_IDLE;
            bbox_valid_r <= 1'b0;
            bbox_left_r <= 5'd31;
            bbox_right_r <= 5'd0;
            bbox_top_r <= 5'd31;
            bbox_bottom_r <= 5'd0;
            feature_sum_r <= 16'd0;
        end else begin
            case (state_r)
                ST_IDLE: begin
                    if (feature_valid && feature_frame_done)
                        state_r <= ST_PREPARE;
                end

                ST_PREPARE: begin
                    if (norm_input_invalid_w) begin
                        candidate_valid <= 1'b1;
                        candidate_digit <= 4'd0;
                        candidate_unknown <= 1'b1;
                        candidate_distance <= 16'd0;
                        state_r <= ST_IDLE;
                    end else begin
                        conv_ch_r <= 2'd0;
                        conv_idx_r <= 10'd0;
                        kernel_idx_r <= 4'd0;
                        conv_b_addr_r <= 8'd0;
                        state_r <= ST_CONV_BIAS;
                    end
                end

                ST_CONV_BIAS: begin
                    conv_b_addr_r <= {6'd0, conv_ch_r};
                    state_r <= ST_CONV_BIAS_WAIT;
                end

                ST_CONV_BIAS_WAIT: begin
                    state_r <= ST_CONV_BIAS_LOAD;
                end

                ST_CONV_BIAS_LOAD: begin
                    acc_r <= conv_b_ext_w;
                    kernel_idx_r <= 4'd0;
                    state_r <= ST_CONV_ISSUE;
                end

                ST_CONV_ISSUE: begin
                    conv_w_addr_r <= ({4'd0, conv_ch_r} * 6'd9) + {2'd0, kernel_idx_r};
                    kernel_valid_r <= !kernel_outside_w;
                    feature_rd_addr_r <= kernel_outside_w ? 10'd0 : norm_feature_rd_addr_w;
                    state_r <= ST_CONV_WAIT;
                end

                ST_CONV_WAIT: begin
                    state_r <= ST_CONV_MAC;
                end

                ST_CONV_MAC: begin
                    if (kernel_valid_r)
                        acc_r <= acc_r + conv_product_ext_w;
                    if (kernel_idx_r == 4'd8) begin
                        conv_wr_addr_r <= {conv_ch_r, conv_idx_r};
                        state_r <= ST_CONV_SAVE;
                    end else begin
                        kernel_idx_r <= kernel_idx_r + 4'd1;
                        state_r <= ST_CONV_ISSUE;
                    end
                end

                ST_CONV_SAVE: begin
                    conv_mem[conv_wr_addr_r] <= (acc_r > 48'sd0) ? $signed(acc_r[23:0]) : 24'sd0;
                    if ((conv_ch_r == CONV_CH_LAST) && (conv_idx_r == INPUT_LAST)) begin
                        output_idx_r <= 4'd0;
                        fc_b_addr_r <= 8'd0;
                        best_score_r <= 48'sh8000_0000_0000;
                        second_score_r <= 48'sh8000_0000_0000;
                        best_digit_r <= 4'd0;
                        best_valid_r <= 1'b0;
                        second_valid_r <= 1'b0;
                        state_r <= ST_FC_BIAS;
                    end else begin
                        if (conv_idx_r == INPUT_LAST) begin
                            conv_idx_r <= 10'd0;
                            conv_ch_r <= conv_ch_r + 2'd1;
                        end else begin
                            conv_idx_r <= conv_idx_r + 10'd1;
                        end
                        state_r <= ST_CONV_BIAS;
                    end
                end

                ST_FC_BIAS: begin
                    fc_b_addr_r <= {4'd0, output_idx_r};
                    state_r <= ST_FC_BIAS_WAIT;
                end

                ST_FC_BIAS_WAIT: begin
                    state_r <= ST_FC_BIAS_LOAD;
                end

                ST_FC_BIAS_LOAD: begin
                    acc_r <= fc_b_ext_w;
                    fc_idx_r <= 12'd0;
                    state_r <= ST_FC_ISSUE;
                end

                ST_FC_ISSUE: begin
                    fc_w_addr_r <= {output_idx_r, 12'd0} + {4'd0, fc_idx_r};
                    conv_rd_addr_r <= fc_idx_r;
                    state_r <= ST_FC_WAIT;
                end

                ST_FC_WAIT: begin
                    state_r <= ST_FC_MAC;
                end

                ST_FC_MAC: begin
                    acc_r <= acc_r + fc_product_ext_w;
                    if (fc_idx_r == CONV_FLAT_LAST) begin
                        state_r <= ST_FC_SCORE;
                    end else begin
                        fc_idx_r <= fc_idx_r + 12'd1;
                        state_r <= ST_FC_ISSUE;
                    end
                end

                ST_FC_SCORE: begin
                    best_score_r <= next_best_score_w;
                    best_digit_r <= next_best_digit_w;
                    best_valid_r <= next_best_valid_w;
                    second_score_r <= next_second_score_w;
                    second_valid_r <= next_second_valid_w;

                    if (output_idx_r == OUTPUT_LAST) begin
                        candidate_valid <= 1'b1;
                        candidate_digit <= next_best_digit_w;
                        candidate_distance <= next_margin_u16_w;
                        candidate_unknown <= (next_margin_w < CONFIDENCE_THRESHOLD);
                        state_r <= ST_IDLE;
                    end else begin
                        output_idx_r <= output_idx_r + 4'd1;
                        state_r <= ST_FC_BIAS;
                    end
                end

                default: begin
                    state_r <= ST_IDLE;
                end
            endcase
        end
    end
end

endmodule
