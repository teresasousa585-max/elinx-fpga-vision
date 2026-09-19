`timescale 1ns/1ns

// Adapts the project-local fifo_data one-cycle read contract to a valid/data
// stream.  rdempty is generated in the read domain, so no extra CDC is added.
module cnn_fifo_pop
#(
    parameter DATA_W = 23
)
(
    input  wire              clk,
    input  wire              rst_n,
    input  wire              fifo_empty,
    input  wire [DATA_W-1:0] fifo_q,
    output wire              fifo_rdreq,
    output reg               pop_valid,
    output reg  [DATA_W-1:0] pop_data
);

reg rdreq_d_r;

assign fifo_rdreq = rst_n && !fifo_empty;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rdreq_d_r <= 1'b0;
        pop_valid <= 1'b0;
        pop_data  <= {DATA_W{1'b0}};
    end else begin
        rdreq_d_r <= fifo_rdreq;
        pop_valid <= rdreq_d_r;
        if (rdreq_d_r)
            pop_data <= fifo_q;
    end
end

endmodule
