module raw_bayer_plane_gain
#(
    parameter BAYER_MODE = 0,
    parameter ENABLE = 1,
    parameter [8:0] R_GAIN  = 9'd256,
    parameter [8:0] GR_GAIN = 9'd256,
    parameter [8:0] GB_GAIN = 9'd256,
    parameter [8:0] B_GAIN  = 9'd256
)
(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       frame_clr,
    input  wire       in_de,
    input  wire       in_row_even,
    input  wire       in_col_even,
    input  wire [7:0] din,

    output wire       out_de,
    output wire       out_row_even,
    output wire       out_col_even,
    output wire [7:0] dout
);

    function [7:0] clip_gain_u8;
        input [8:0] value;
        begin
            if (value[8] != 1'b0)
                clip_gain_u8 = 8'hff;
            else
                clip_gain_u8 = value[7:0];
        end
    endfunction

    function [8:0] plane_gain_sel;
        input row_even_i;
        input col_even_i;
        begin
            if (ENABLE == 0) begin
                plane_gain_sel = 9'd256;
            end else begin
                case (BAYER_MODE)
                    0: begin
                        if (row_even_i && col_even_i)
                            plane_gain_sel = B_GAIN;
                        else if (row_even_i && !col_even_i)
                            plane_gain_sel = GB_GAIN;
                        else if (!row_even_i && col_even_i)
                            plane_gain_sel = GR_GAIN;
                        else
                            plane_gain_sel = R_GAIN;
                    end
                    1: begin
                        if (row_even_i && col_even_i)
                            plane_gain_sel = R_GAIN;
                        else if (row_even_i && !col_even_i)
                            plane_gain_sel = GR_GAIN;
                        else if (!row_even_i && col_even_i)
                            plane_gain_sel = GB_GAIN;
                        else
                            plane_gain_sel = B_GAIN;
                    end
                    2: begin
                        if (row_even_i && col_even_i)
                            plane_gain_sel = GR_GAIN;
                        else if (row_even_i && !col_even_i)
                            plane_gain_sel = R_GAIN;
                        else if (!row_even_i && col_even_i)
                            plane_gain_sel = B_GAIN;
                        else
                            plane_gain_sel = GB_GAIN;
                    end
                    default: begin
                        if (row_even_i && col_even_i)
                            plane_gain_sel = GB_GAIN;
                        else if (row_even_i && !col_even_i)
                            plane_gain_sel = B_GAIN;
                        else if (!row_even_i && col_even_i)
                            plane_gain_sel = R_GAIN;
                        else
                            plane_gain_sel = GR_GAIN;
                    end
                endcase
            end
        end
    endfunction

    reg        s0_de_r;
    reg        s0_row_even_r;
    reg        s0_col_even_r;
    reg [7:0]  s0_din_r;
    reg [8:0]  s0_gain_r;

    reg        s1_de_r;
    reg        s1_row_even_r;
    reg        s1_col_even_r;
    reg [16:0] s1_mul_r;

    reg        s2_de_r;
    reg        s2_row_even_r;
    reg        s2_col_even_r;
    reg [7:0]  s2_dout_r;

    reg        d0_de_r;
    reg        d0_row_even_r;
    reg        d0_col_even_r;
    reg [7:0]  d0_dout_r;
    reg        d1_de_r;
    reg        d1_row_even_r;
    reg        d1_col_even_r;
    reg [7:0]  d1_dout_r;
    reg        d2_de_r;
    reg        d2_row_even_r;
    reg        d2_col_even_r;
    reg [7:0]  d2_dout_r;
    reg        d3_de_r;
    reg        d3_row_even_r;
    reg        d3_col_even_r;
    reg [7:0]  d3_dout_r;
    reg        d4_de_r;
    reg        d4_row_even_r;
    reg        d4_col_even_r;
    reg [7:0]  d4_dout_r;
    reg        d5_de_r;
    reg        d5_row_even_r;
    reg        d5_col_even_r;
    reg [7:0]  d5_dout_r;
    reg        d6_de_r;
    reg        d6_row_even_r;
    reg        d6_col_even_r;
    reg [7:0]  d6_dout_r;
    reg        d7_de_r;
    reg        d7_row_even_r;
    reg        d7_col_even_r;
    reg [7:0]  d7_dout_r;

    wire [8:0] s1_round_w = (s1_mul_r + 17'd128) >> 8;
    wire [7:0] s1_clip_w = clip_gain_u8(s1_round_w);

    assign out_de = d7_de_r;
    assign out_row_even = d7_row_even_r;
    assign out_col_even = d7_col_even_r;
    assign dout = d7_dout_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s0_de_r <= 1'b0;
            s0_row_even_r <= 1'b0;
            s0_col_even_r <= 1'b0;
            s0_din_r <= 8'd0;
            s0_gain_r <= 9'd256;
            s1_de_r <= 1'b0;
            s1_row_even_r <= 1'b0;
            s1_col_even_r <= 1'b0;
            s1_mul_r <= 17'd0;
            s2_de_r <= 1'b0;
            s2_row_even_r <= 1'b0;
            s2_col_even_r <= 1'b0;
            s2_dout_r <= 8'd0;
            d0_de_r <= 1'b0;
            d0_row_even_r <= 1'b0;
            d0_col_even_r <= 1'b0;
            d0_dout_r <= 8'd0;
            d1_de_r <= 1'b0;
            d1_row_even_r <= 1'b0;
            d1_col_even_r <= 1'b0;
            d1_dout_r <= 8'd0;
            d2_de_r <= 1'b0;
            d2_row_even_r <= 1'b0;
            d2_col_even_r <= 1'b0;
            d2_dout_r <= 8'd0;
            d3_de_r <= 1'b0;
            d3_row_even_r <= 1'b0;
            d3_col_even_r <= 1'b0;
            d3_dout_r <= 8'd0;
            d4_de_r <= 1'b0;
            d4_row_even_r <= 1'b0;
            d4_col_even_r <= 1'b0;
            d4_dout_r <= 8'd0;
            d5_de_r <= 1'b0;
            d5_row_even_r <= 1'b0;
            d5_col_even_r <= 1'b0;
            d5_dout_r <= 8'd0;
            d6_de_r <= 1'b0;
            d6_row_even_r <= 1'b0;
            d6_col_even_r <= 1'b0;
            d6_dout_r <= 8'd0;
            d7_de_r <= 1'b0;
            d7_row_even_r <= 1'b0;
            d7_col_even_r <= 1'b0;
            d7_dout_r <= 8'd0;
        end else if (frame_clr) begin
            s0_de_r <= 1'b0;
            s0_row_even_r <= 1'b0;
            s0_col_even_r <= 1'b0;
            s0_din_r <= 8'd0;
            s0_gain_r <= 9'd256;
            s1_de_r <= 1'b0;
            s1_row_even_r <= 1'b0;
            s1_col_even_r <= 1'b0;
            s1_mul_r <= 17'd0;
            s2_de_r <= 1'b0;
            s2_row_even_r <= 1'b0;
            s2_col_even_r <= 1'b0;
            s2_dout_r <= 8'd0;
            d0_de_r <= 1'b0;
            d0_row_even_r <= 1'b0;
            d0_col_even_r <= 1'b0;
            d0_dout_r <= 8'd0;
            d1_de_r <= 1'b0;
            d1_row_even_r <= 1'b0;
            d1_col_even_r <= 1'b0;
            d1_dout_r <= 8'd0;
            d2_de_r <= 1'b0;
            d2_row_even_r <= 1'b0;
            d2_col_even_r <= 1'b0;
            d2_dout_r <= 8'd0;
            d3_de_r <= 1'b0;
            d3_row_even_r <= 1'b0;
            d3_col_even_r <= 1'b0;
            d3_dout_r <= 8'd0;
            d4_de_r <= 1'b0;
            d4_row_even_r <= 1'b0;
            d4_col_even_r <= 1'b0;
            d4_dout_r <= 8'd0;
            d5_de_r <= 1'b0;
            d5_row_even_r <= 1'b0;
            d5_col_even_r <= 1'b0;
            d5_dout_r <= 8'd0;
            d6_de_r <= 1'b0;
            d6_row_even_r <= 1'b0;
            d6_col_even_r <= 1'b0;
            d6_dout_r <= 8'd0;
            d7_de_r <= 1'b0;
            d7_row_even_r <= 1'b0;
            d7_col_even_r <= 1'b0;
            d7_dout_r <= 8'd0;
        end else begin
            s0_de_r <= in_de;
            s0_row_even_r <= in_row_even;
            s0_col_even_r <= in_col_even;
            s0_din_r <= in_de ? din : 8'd0;
            s0_gain_r <= plane_gain_sel(in_row_even, in_col_even);

            s1_de_r <= s0_de_r;
            s1_row_even_r <= s0_row_even_r;
            s1_col_even_r <= s0_col_even_r;
            s1_mul_r <= {9'd0, s0_din_r} * s0_gain_r;

            s2_de_r <= s1_de_r;
            s2_row_even_r <= s1_row_even_r;
            s2_col_even_r <= s1_col_even_r;
            s2_dout_r <= s1_de_r ? s1_clip_w : 8'd0;

            d0_de_r <= s2_de_r;
            d0_row_even_r <= s2_row_even_r;
            d0_col_even_r <= s2_col_even_r;
            d0_dout_r <= s2_dout_r;
            d1_de_r <= d0_de_r;
            d1_row_even_r <= d0_row_even_r;
            d1_col_even_r <= d0_col_even_r;
            d1_dout_r <= d0_dout_r;
            d2_de_r <= d1_de_r;
            d2_row_even_r <= d1_row_even_r;
            d2_col_even_r <= d1_col_even_r;
            d2_dout_r <= d1_dout_r;
            d3_de_r <= d2_de_r;
            d3_row_even_r <= d2_row_even_r;
            d3_col_even_r <= d2_col_even_r;
            d3_dout_r <= d2_dout_r;
            d4_de_r <= d3_de_r;
            d4_row_even_r <= d3_row_even_r;
            d4_col_even_r <= d3_col_even_r;
            d4_dout_r <= d3_dout_r;
            d5_de_r <= d4_de_r;
            d5_row_even_r <= d4_row_even_r;
            d5_col_even_r <= d4_col_even_r;
            d5_dout_r <= d4_dout_r;
            d6_de_r <= d5_de_r;
            d6_row_even_r <= d5_row_even_r;
            d6_col_even_r <= d5_col_even_r;
            d6_dout_r <= d5_dout_r;
            d7_de_r <= d6_de_r;
            d7_row_even_r <= d6_row_even_r;
            d7_col_even_r <= d6_col_even_r;
            d7_dout_r <= d6_dout_r;
        end
    end

endmodule
