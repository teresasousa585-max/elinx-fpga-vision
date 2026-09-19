`timescale 1ns/1ns

module cnn_digit_stabilizer
#(
    parameter CONSISTENT_FRAMES  = 3,
    parameter UNKNOWN_HOLD_FRAMES = 10
)
(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       clear,
    input  wire       candidate_valid,
    input  wire [3:0] candidate_digit,
    input  wire       candidate_unknown,
    output reg        stable_valid,
    output reg  [3:0] stable_digit,
    output reg        display_unknown
);

reg [3:0] last_digit;
reg [7:0] same_count;
reg [7:0] unknown_count;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        stable_valid    <= 1'b0;
        stable_digit    <= 4'd0;
        display_unknown <= 1'b1;
        last_digit      <= 4'd0;
        same_count      <= 8'd0;
        unknown_count   <= 8'd0;
    end else if (clear) begin
        stable_valid    <= 1'b0;
        stable_digit    <= 4'd0;
        display_unknown <= 1'b1;
        last_digit      <= 4'd0;
        same_count      <= 8'd0;
        unknown_count   <= 8'd0;
    end else if (candidate_valid) begin
        if (candidate_unknown) begin
            same_count <= 8'd0;
            if (unknown_count < 8'hff)
                unknown_count <= unknown_count + 8'd1;
            if ((unknown_count + 8'd1) >= UNKNOWN_HOLD_FRAMES[7:0])
                display_unknown <= 1'b1;
        end else begin
            display_unknown <= 1'b0;
            unknown_count   <= 8'd0;

            if (candidate_digit == last_digit) begin
                if (same_count < 8'hff)
                    same_count <= same_count + 8'd1;
                if ((same_count + 8'd1) >= CONSISTENT_FRAMES[7:0]) begin
                    stable_valid <= 1'b1;
                    stable_digit <= candidate_digit;
                end
            end else begin
                last_digit <= candidate_digit;
                same_count <= 8'd1;
            end
        end
    end
end

endmodule
