module rgb_awb_gain
#(
    parameter R_GAIN = 9'd256,
    parameter G_GAIN = 9'd256,
    parameter B_GAIN = 9'd256
)
(
    input   wire            clk,
    input   wire            rst_n,
    input   wire            in_de,
    input   wire    [23:0]  in_rgb,

    output  reg             out_de,
    output  reg     [23:0]  out_rgb
);

    function [7:0] clip_gain_u8;
        input [17:0] value;
        begin
            if (value[17:8] != 10'd0)
                clip_gain_u8 = 8'hff;
            else
                clip_gain_u8 = value[7:0];
        end
    endfunction

    wire [17:0] r_gain_w;
    wire [17:0] g_gain_w;
    wire [17:0] b_gain_w;

    assign r_gain_w = ({10'd0, in_rgb[23:16]} * R_GAIN + 18'd128) >> 8;
    assign g_gain_w = ({10'd0, in_rgb[15:8]}  * G_GAIN + 18'd128) >> 8;
    assign b_gain_w = ({10'd0, in_rgb[7:0]}   * B_GAIN + 18'd128) >> 8;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_de  <= 1'b0;
            out_rgb <= 24'd0;
        end else begin
            out_de <= in_de;

            if (in_de)
                out_rgb <= {clip_gain_u8(r_gain_w), clip_gain_u8(g_gain_w), clip_gain_u8(b_gain_w)};
            else
                out_rgb <= 24'd0;
        end
    end

endmodule
