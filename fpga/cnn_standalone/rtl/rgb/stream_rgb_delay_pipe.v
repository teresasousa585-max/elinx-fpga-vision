module stream_rgb_delay_pipe
#(
    parameter integer LATENCY = 1
)
(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        frame_clr,
    input  wire        in_de,
    input  wire [23:0] in_rgb,
    output wire        out_de,
    output wire [23:0] out_rgb
);

generate
if (LATENCY == 0) begin : gen_passthrough
    assign out_de  = rst_n && !frame_clr && in_de;
    assign out_rgb = (rst_n && !frame_clr && in_de) ? in_rgb : 24'd0;
end else if (LATENCY == 1) begin : gen_delay1
    reg        de_r;
    reg [23:0] rgb_r;

    // Only visibility state needs asynchronous reset. Pixel data is always
    // qualified by de_r, so removing its ACLR cannot expose stale pixels.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            de_r <= 1'b0;
        else
            de_r <= frame_clr ? 1'b0 : in_de;
    end

    always @(posedge clk)
        rgb_r <= in_de ? in_rgb : 24'd0;

    assign out_de  = de_r;
    assign out_rgb = de_r ? rgb_r : 24'd0;
end else begin : gen_delayn
    reg [LATENCY-1:0]    de_pipe_r;
    reg [LATENCY*24-1:0] rgb_pipe_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            de_pipe_r <= {LATENCY{1'b0}};
        else
            de_pipe_r <= frame_clr
                       ? {LATENCY{1'b0}}
                       : {de_pipe_r[LATENCY-2:0], in_de};
    end

    // This is pure payload storage. The de pipeline above is the visibility
    // contract and is cleared on reset/frame boundaries.
    always @(posedge clk)
        rgb_pipe_r <= {rgb_pipe_r[(LATENCY-1)*24-1:0],
                       (in_de ? in_rgb : 24'd0)};

    assign out_de  = de_pipe_r[LATENCY-1];
    assign out_rgb = de_pipe_r[LATENCY-1]
                   ? rgb_pipe_r[LATENCY*24-1:(LATENCY-1)*24]
                   : 24'd0;
end
endgenerate

endmodule


// One shared delay bank for the frame-latched RGB stage preview. The input
// mux chooses the active stage before this module; delay_cycles selects one of
// the reviewed fixed taps, so synthesis builds a 13-way fixed mux instead of
// a 176-way variable-index mux. Pixel storage has no ACLR and is hidden by the
// asynchronously cleared DE pipeline.
module stream_rgb_selected_delay_pipe
#(
    parameter integer MAX_LATENCY = 176
)
(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        frame_clr,
    input  wire [7:0]  delay_cycles,
    input  wire        in_de,
    input  wire [23:0] in_rgb,
    output reg         out_de,
    output reg  [23:0] out_rgb
);

reg [MAX_LATENCY-1:0]    de_pipe_r;
reg [MAX_LATENCY*24-1:0] rgb_pipe_r;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        de_pipe_r <= {MAX_LATENCY{1'b0}};
    else
        de_pipe_r <= frame_clr
                   ? {MAX_LATENCY{1'b0}}
                   : {de_pipe_r[MAX_LATENCY-2:0], in_de};
end

always @(posedge clk)
    rgb_pipe_r <= {rgb_pipe_r[(MAX_LATENCY-1)*24-1:0],
                   (in_de ? in_rgb : 24'd0)};

always @(*) begin
    out_de  = 1'b0;
    out_rgb = 24'd0;
    if (rst_n && !frame_clr) begin
        case (delay_cycles)
            8'd0: begin
                out_de  = in_de;
                out_rgb = in_de ? in_rgb : 24'd0;
            end
            8'd11: begin
                out_de  = de_pipe_r[10];
                out_rgb = de_pipe_r[10] ? rgb_pipe_r[11*24-1:10*24] : 24'd0;
            end
            8'd87: begin
                out_de  = de_pipe_r[86];
                out_rgb = de_pipe_r[86] ? rgb_pipe_r[87*24-1:86*24] : 24'd0;
            end
            8'd88: begin
                out_de  = de_pipe_r[87];
                out_rgb = de_pipe_r[87] ? rgb_pipe_r[88*24-1:87*24] : 24'd0;
            end
            8'd90: begin
                out_de  = de_pipe_r[89];
                out_rgb = de_pipe_r[89] ? rgb_pipe_r[90*24-1:89*24] : 24'd0;
            end
            8'd137: begin
                out_de  = de_pipe_r[136];
                out_rgb = de_pipe_r[136] ? rgb_pipe_r[137*24-1:136*24] : 24'd0;
            end
            8'd144: begin
                out_de  = de_pipe_r[143];
                out_rgb = de_pipe_r[143] ? rgb_pipe_r[144*24-1:143*24] : 24'd0;
            end
            8'd149: begin
                out_de  = de_pipe_r[148];
                out_rgb = de_pipe_r[148] ? rgb_pipe_r[149*24-1:148*24] : 24'd0;
            end
            8'd152: begin
                out_de  = de_pipe_r[151];
                out_rgb = de_pipe_r[151] ? rgb_pipe_r[152*24-1:151*24] : 24'd0;
            end
            8'd154: begin
                out_de  = de_pipe_r[153];
                out_rgb = de_pipe_r[153] ? rgb_pipe_r[154*24-1:153*24] : 24'd0;
            end
            8'd155: begin
                out_de  = de_pipe_r[154];
                out_rgb = de_pipe_r[154] ? rgb_pipe_r[155*24-1:154*24] : 24'd0;
            end
            8'd165: begin
                out_de  = de_pipe_r[164];
                out_rgb = de_pipe_r[164] ? rgb_pipe_r[165*24-1:164*24] : 24'd0;
            end
            8'd176: begin
                out_de  = de_pipe_r[175];
                out_rgb = de_pipe_r[175] ? rgb_pipe_r[176*24-1:175*24] : 24'd0;
            end
            default: begin
                out_de  = 1'b0;
                out_rgb = 24'd0;
            end
        endcase
    end
end

endmodule
