`timescale 1ns/1ns

module cnn_system
(
    input  wire        clk_75m,
    input  wire        clk_25m,
    input  wire        reset_root_n,
    input  wire [1:0]  active_mode,
    input  wire        frame_prefetch_start,
    input  wire        frame_epoch,
    input  wire        in_de,
    input  wire [7:0]  in_raw8,
    input  wire [10:0] in_x,
    input  wire [10:0] in_y,

    output wire        cnn_digit_valid,
    output wire [3:0]  cnn_digit,
    output wire        accepted_frame_pulse,
    output wire        dropped_frame_pulse,
    output wire [10:0] accepted_token_count,
    output wire        feature_overflow_error,
    output wire        protocol_fault_error_75m,
    output wire        protocol_error_25m,
    output wire        feature_write_pulse_25m,
    output wire        bbox_write_pulse_25m,
    output wire [3:0]  session_debug,
    output wire        session_ready_debug,
    output wire        inference_inflight_debug,
    output wire [2:0]  wrapper_state_debug,
    output wire [3:0]  classifier_state_debug
);

wire [22:0] forward_wr_data_w;
wire forward_wrreq_w;
wire forward_wrfull_w;
wire forward_wrempty_w;
wire forward_rdempty_w;
wire [22:0] forward_q_w;
wire forward_rdreq_w;
wire forward_pop_valid_w;
wire [22:0] forward_pop_data_w;

wire [25:0] return_wr_data_w;
wire return_wrreq_w;
wire return_wrfull_w;
wire return_wrempty_w;
wire return_rdempty_w;
wire [25:0] return_q_w;
wire return_rdreq_w;
wire return_pop_valid_w;
wire [25:0] return_pop_data_w;
wire classifier_idle_w;
wire [3:0] classifier_session_w;

// The two asynchronous FIFO pointers and both protocol endpoints form one
// reset island.  Its asynchronous assertion comes only from the common
// top-level reset root; combining already synchronized per-domain reset
// releases here would create a real 75<->25 MHz asynchronous-clear path.
// Release is synchronized independently in each local clock domain.
wire cnn_arst_n_w = reset_root_n;
(* preserve, syn_preserve = 1 *) reg [1:0] cnn_rst_sync_75m_r;
(* preserve, syn_preserve = 1 *) reg [1:0] cnn_rst_sync_25m_r;
wire cnn_rst_n_75m_w = cnn_rst_sync_75m_r[1];
wire cnn_rst_n_25m_w = cnn_rst_sync_25m_r[1];

always @(posedge clk_75m or negedge cnn_arst_n_w) begin
    if (!cnn_arst_n_w)
        cnn_rst_sync_75m_r <= 2'b00;
    else
        cnn_rst_sync_75m_r <= {cnn_rst_sync_75m_r[0], 1'b1};
end

always @(posedge clk_25m or negedge cnn_arst_n_w) begin
    if (!cnn_arst_n_w)
        cnn_rst_sync_25m_r <= 2'b00;
    else
        cnn_rst_sync_25m_r <= {cnn_rst_sync_25m_r[0], 1'b1};
end

cnn_frontend_75m u_cnn_frontend_75m
(
    .clk                      (clk_75m),
    .rst_n                    (cnn_rst_n_75m_w),
    .active_mode              (active_mode),
    .frame_prefetch_start     (frame_prefetch_start),
    .frame_epoch              (frame_epoch),
    .in_de                    (in_de),
    .in_raw8                  (in_raw8),
    .in_x                     (in_x),
    .in_y                     (in_y),
    .forward_ready            (!forward_wrfull_w),
    .forward_empty            (forward_wrempty_w),
    .forward_valid            (forward_wrreq_w),
    .forward_data             (forward_wr_data_w),
    .return_valid             (return_pop_valid_w),
    .return_data              (return_pop_data_w),
    .cnn_digit_valid          (cnn_digit_valid),
    .cnn_digit                (cnn_digit),
    .accepted_frame_pulse     (accepted_frame_pulse),
    .dropped_frame_pulse      (dropped_frame_pulse),
    .accepted_token_count     (accepted_token_count),
    .feature_overflow_error   (feature_overflow_error),
    .protocol_fault_error     (protocol_fault_error_75m),
    .session_debug            (session_debug),
    .session_ready_debug      (session_ready_debug),
    .inference_inflight_debug (inference_inflight_debug)
);

fifo_data
#(
    .DATA_W (23),
    .ADDR_W (5),
    .DEPTH  (32)
)
u_cnn_forward_fifo_data
(
    .wrclk   (clk_75m),
    .wrreq   (forward_wrreq_w),
    .data    (forward_wr_data_w),
    .wrusedw (),
    .wrfull  (forward_wrfull_w),
    .wrempty (forward_wrempty_w),
    .rdclk   (clk_25m),
    .rdreq   (forward_rdreq_w),
    .q       (forward_q_w),
    .rdusedw (),
    .rdempty (forward_rdempty_w),
    .aclr    (~cnn_arst_n_w),
    .wr_aclr (1'b0),
    .rd_aclr (1'b0)
);

cnn_fifo_pop #(.DATA_W(23)) u_cnn_forward_fifo_pop
(
    .clk        (clk_25m),
    .rst_n      (cnn_rst_n_25m_w),
    .fifo_empty (forward_rdempty_w),
    .fifo_q     (forward_q_w),
    .fifo_rdreq (forward_rdreq_w),
    .pop_valid  (forward_pop_valid_w),
    .pop_data   (forward_pop_data_w)
);

cnn_classifier_session_25m u_cnn_classifier_session_25m
(
    .clk                    (clk_25m),
    .rst_n                  (cnn_rst_n_25m_w),
    .cmd_valid              (forward_pop_valid_w),
    .cmd_data               (forward_pop_data_w),
    .return_ready           (!return_wrfull_w),
    .return_empty           (return_wrempty_w),
    .return_valid           (return_wrreq_w),
    .return_data            (return_wr_data_w),
    .classifier_idle        (classifier_idle_w),
    .protocol_error         (protocol_error_25m),
    .feature_write_pulse    (feature_write_pulse_25m),
    .bbox_write_pulse       (bbox_write_pulse_25m),
    .wrapper_state_debug    (wrapper_state_debug),
    .classifier_state_debug (classifier_state_debug),
    .active_session_debug   (classifier_session_w)
);

fifo_data
#(
    .DATA_W (26),
    .ADDR_W (2),
    .DEPTH  (4)
)
u_cnn_return_fifo_data
(
    .wrclk   (clk_25m),
    .wrreq   (return_wrreq_w),
    .data    (return_wr_data_w),
    .wrusedw (),
    .wrfull  (return_wrfull_w),
    .wrempty (return_wrempty_w),
    .rdclk   (clk_75m),
    .rdreq   (return_rdreq_w),
    .q       (return_q_w),
    .rdusedw (),
    .rdempty (return_rdempty_w),
    .aclr    (~cnn_arst_n_w),
    .wr_aclr (1'b0),
    .rd_aclr (1'b0)
);

cnn_fifo_pop #(.DATA_W(26)) u_cnn_return_fifo_pop
(
    .clk        (clk_75m),
    .rst_n      (cnn_rst_n_75m_w),
    .fifo_empty (return_rdempty_w),
    .fifo_q     (return_q_w),
    .fifo_rdreq (return_rdreq_w),
    .pop_valid  (return_pop_valid_w),
    .pop_data   (return_pop_data_w)
);

endmodule
