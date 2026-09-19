module rgb_vivid_tune
#(
    parameter ENABLE = 1,
    parameter [3:0] SAT_POS_SHIFT = 4'd2,
    parameter [3:0] SAT_NEG_SHIFT = 4'd3,
    parameter [3:0] LIFT_SHIFT    = 4'd4,
    parameter signed [8:0] R_OFFSET = 9'sd12,
    parameter signed [8:0] G_OFFSET = 9'sd6,
    parameter signed [8:0] B_OFFSET = -9'sd10
)
(
    input   wire            clk,
    input   wire            rst_n,
    input   wire            in_de,
    input   wire    [23:0]  in_rgb,

    output  reg             out_de,
    output  reg     [23:0]  out_rgb
);

    function [7:0] sat_add8;
        input [7:0] a;
        input [7:0] b;
        reg [8:0] sum;
        begin
            sum = {1'b0, a} + {1'b0, b};
            sat_add8 = sum[8] ? 8'hff : sum[7:0];
        end
    endfunction

    function [7:0] sat_sub8;
        input [7:0] a;
        input [7:0] b;
        begin
            sat_sub8 = (a > b) ? (a - b) : 8'd0;
        end
    endfunction

    function [7:0] shift_frac_u8;
        input [7:0] value;
        input [3:0] shift;
        begin
            if ((shift == 4'd0) || (shift > 4'd7))
                shift_frac_u8 = 8'd0;
            else
                shift_frac_u8 = value >> shift;
        end
    endfunction

    function [7:0] sat_add_signed8;
        input [7:0] a;
        input signed [8:0] delta;
        reg signed [9:0] sum;
        begin
            sum = $signed({1'b0, a}) + delta;
            if (sum < 10'sd0)
                sat_add_signed8 = 8'd0;
            else if (sum > 10'sd255)
                sat_add_signed8 = 8'hff;
            else
                sat_add_signed8 = sum[7:0];
        end
    endfunction

    wire [7:0] in_r_w;
    wire [7:0] in_g_w;
    wire [7:0] in_b_w;
    wire [9:0] y_sum_w;
    wire [7:0] y_w;
    wire [7:0] r_sat_w;
    wire [7:0] g_sat_w;
    wire [7:0] b_sat_w;
    wire [7:0] r_lift_w;
    wire [7:0] g_lift_w;
    wire [7:0] b_lift_w;
    wire [7:0] r_tuned_w;
    wire [7:0] g_tuned_w;
    wire [7:0] b_tuned_w;

    assign in_r_w    = in_rgb[23:16];
    assign in_g_w    = in_rgb[15:8];
    assign in_b_w    = in_rgb[7:0];
    assign y_sum_w   = {2'b00, in_r_w} + {1'b0, in_g_w, 1'b0} + {2'b00, in_b_w};
    assign y_w       = y_sum_w[9:2];
    assign r_sat_w   = (in_r_w >= y_w) ? sat_add8(in_r_w, shift_frac_u8(in_r_w - y_w, SAT_POS_SHIFT)) :
                                       sat_sub8(in_r_w, shift_frac_u8(y_w - in_r_w, SAT_NEG_SHIFT));
    assign g_sat_w   = (in_g_w >= y_w) ? sat_add8(in_g_w, shift_frac_u8(in_g_w - y_w, SAT_POS_SHIFT)) :
                                       sat_sub8(in_g_w, shift_frac_u8(y_w - in_g_w, SAT_NEG_SHIFT));
    assign b_sat_w   = (in_b_w >= y_w) ? sat_add8(in_b_w, shift_frac_u8(in_b_w - y_w, SAT_POS_SHIFT)) :
                                       sat_sub8(in_b_w, shift_frac_u8(y_w - in_b_w, SAT_NEG_SHIFT));
    assign r_lift_w  = sat_add8(r_sat_w, shift_frac_u8(8'hff - r_sat_w, LIFT_SHIFT));
    assign g_lift_w  = sat_add8(g_sat_w, shift_frac_u8(8'hff - g_sat_w, LIFT_SHIFT));
    assign b_lift_w  = sat_add8(b_sat_w, shift_frac_u8(8'hff - b_sat_w, LIFT_SHIFT));
    assign r_tuned_w = sat_add_signed8(r_lift_w, R_OFFSET);
    assign g_tuned_w = sat_add_signed8(g_lift_w, G_OFFSET);
    assign b_tuned_w = sat_add_signed8(b_lift_w, B_OFFSET);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_de  <= 1'b0;
            out_rgb <= 24'd0;
        end else begin
            out_de <= in_de;
            if (in_de) begin
                if (ENABLE != 0)
                    out_rgb <= {r_tuned_w, g_tuned_w, b_tuned_w};
                else
                    out_rgb <= in_rgb;
            end else begin
                out_rgb <= 24'd0;
            end
        end
    end

endmodule
