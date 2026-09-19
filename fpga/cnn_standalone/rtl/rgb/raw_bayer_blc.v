module raw_bayer_blc
#(
    parameter BAYER_MODE = 0,
    parameter ENABLE     = 1,
    parameter OFFSET_R   = 8'd8,
    parameter OFFSET_GR  = 8'd8,
    parameter OFFSET_GB  = 8'd8,
    parameter OFFSET_B   = 8'd8
)
(
    input   wire            row_even,
    input   wire            col_even,
    input   wire    [7:0]   din,

    output  wire    [7:0]   dout
);

    function [7:0] sub_clip_u8;
        input [7:0] value;
        input [7:0] offset;
        begin
            sub_clip_u8 = (value > offset) ? (value - offset) : 8'd0;
        end
    endfunction

    reg [7:0] offset_sel_r;

    always @(*) begin
        case (BAYER_MODE)
            0: begin
                if (row_even && col_even)
                    offset_sel_r = OFFSET_B;
                else if (row_even && !col_even)
                    offset_sel_r = OFFSET_GB;
                else if (!row_even && col_even)
                    offset_sel_r = OFFSET_GR;
                else
                    offset_sel_r = OFFSET_R;
            end
            1: begin
                if (row_even && col_even)
                    offset_sel_r = OFFSET_R;
                else if (row_even && !col_even)
                    offset_sel_r = OFFSET_GR;
                else if (!row_even && col_even)
                    offset_sel_r = OFFSET_GB;
                else
                    offset_sel_r = OFFSET_B;
            end
            2: begin
                if (row_even && col_even)
                    offset_sel_r = OFFSET_GR;
                else if (row_even && !col_even)
                    offset_sel_r = OFFSET_R;
                else if (!row_even && col_even)
                    offset_sel_r = OFFSET_B;
                else
                    offset_sel_r = OFFSET_GB;
            end
            default: begin
                if (row_even && col_even)
                    offset_sel_r = OFFSET_GB;
                else if (row_even && !col_even)
                    offset_sel_r = OFFSET_B;
                else if (!row_even && col_even)
                    offset_sel_r = OFFSET_R;
                else
                    offset_sel_r = OFFSET_GR;
            end
        endcase
    end

    assign dout = (ENABLE != 0) ? sub_clip_u8(din, offset_sel_r) : din;

endmodule
