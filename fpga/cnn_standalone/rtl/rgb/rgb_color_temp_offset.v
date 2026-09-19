module rgb_color_temp_offset
#(
    parameter signed [8:0] COOL_R_OFFSET = -9'sd10,
    parameter signed [8:0] COOL_G_OFFSET =  9'sd2,
    parameter signed [8:0] COOL_B_OFFSET =  9'sd13,
    parameter signed [8:0] WARM_R_OFFSET =  9'sd12,
    parameter signed [8:0] WARM_G_OFFSET = -9'sd3,
    parameter signed [8:0] WARM_B_OFFSET = -9'sd10,
    parameter        [7:0] DARK_BYPASS_Y_TH = 8'd28
)
(
    input   wire            clk,
    input   wire            rst_n,
    input   wire            in_de,
    input   wire    [23:0]  in_rgb,
    input   wire    [1:0]   cfg_runtime_color_temp_sel,

    output  reg             out_de,
    output  reg     [23:0]  out_rgb
);

localparam [1:0] COLOR_TEMP_NEUTRAL = 2'd0;
localparam [1:0] COLOR_TEMP_COOL    = 2'd1;
localparam [1:0] COLOR_TEMP_WARM    = 2'd2;

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

wire signed [8:0] runtime_r_offset_w =
    (cfg_runtime_color_temp_sel == COLOR_TEMP_COOL) ? COOL_R_OFFSET :
    ((cfg_runtime_color_temp_sel == COLOR_TEMP_WARM) ? WARM_R_OFFSET : 9'sd0);
wire signed [8:0] runtime_g_offset_w =
    (cfg_runtime_color_temp_sel == COLOR_TEMP_COOL) ? COOL_G_OFFSET :
    ((cfg_runtime_color_temp_sel == COLOR_TEMP_WARM) ? WARM_G_OFFSET : 9'sd0);
wire signed [8:0] runtime_b_offset_w =
    (cfg_runtime_color_temp_sel == COLOR_TEMP_COOL) ? COOL_B_OFFSET :
    ((cfg_runtime_color_temp_sel == COLOR_TEMP_WARM) ? WARM_B_OFFSET : 9'sd0);

reg               temp_de_s0_r;
reg       [23:0]  temp_rgb_s0_r;
reg               temp_de_s1_r;
reg       [23:0]  temp_rgb_s1_r;
reg signed [8:0]  temp_r_offset_s1_r;
reg signed [8:0]  temp_g_offset_s1_r;
reg signed [8:0]  temp_b_offset_s1_r;

wire [7:0] in_r_w = temp_rgb_s0_r[23:16];
wire [7:0] in_g_w = temp_rgb_s0_r[15:8];
wire [7:0] in_b_w = temp_rgb_s0_r[7:0];

wire [15:0] in_r_y_w = in_r_w * 8'd77;
wire [15:0] in_g_y_w = in_g_w * 8'd150;
wire [15:0] in_b_y_w = in_b_w * 8'd29;
wire [15:0] y_acc_w = in_r_y_w + in_g_y_w + in_b_y_w;
wire [7:0] in_y_w = y_acc_w[15:8];
wire color_temp_apply_w = (in_y_w >= DARK_BYPASS_Y_TH);

wire [7:0] in_r_s1_w = temp_rgb_s1_r[23:16];
wire [7:0] in_g_s1_w = temp_rgb_s1_r[15:8];
wire [7:0] in_b_s1_w = temp_rgb_s1_r[7:0];

wire [7:0] out_r_s1_w = sat_add_signed8(in_r_s1_w, temp_r_offset_s1_r);
wire [7:0] out_g_s1_w = sat_add_signed8(in_g_s1_w, temp_g_offset_s1_r);
wire [7:0] out_b_s1_w = sat_add_signed8(in_b_s1_w, temp_b_offset_s1_r);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        temp_de_s0_r <= 1'b0;
        temp_rgb_s0_r <= 24'd0;
        temp_de_s1_r <= 1'b0;
        temp_rgb_s1_r <= 24'd0;
        temp_r_offset_s1_r <= 9'sd0;
        temp_g_offset_s1_r <= 9'sd0;
        temp_b_offset_s1_r <= 9'sd0;
        out_de  <= 1'b0;
        out_rgb <= 24'd0;
    end else begin
        temp_de_s0_r <= in_de;
        temp_rgb_s0_r <= in_de ? in_rgb : 24'd0;
        temp_de_s1_r <= temp_de_s0_r;
        temp_rgb_s1_r <= temp_de_s0_r ? temp_rgb_s0_r : 24'd0;
        temp_r_offset_s1_r <= color_temp_apply_w ? runtime_r_offset_w : 9'sd0;
        temp_g_offset_s1_r <= color_temp_apply_w ? runtime_g_offset_w : 9'sd0;
        temp_b_offset_s1_r <= color_temp_apply_w ? runtime_b_offset_w : 9'sd0;

        out_de <= temp_de_s1_r;
        if (temp_de_s1_r)
            out_rgb <= {out_r_s1_w, out_g_s1_w, out_b_s1_w};
        else
            out_rgb <= 24'd0;
    end
end

endmodule
