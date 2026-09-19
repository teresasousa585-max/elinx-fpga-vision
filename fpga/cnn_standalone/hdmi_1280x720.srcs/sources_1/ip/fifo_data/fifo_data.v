// Project-local replacement for the generated dcfifo wrapper.
//
// The vendor dcfifo reported internal Gray-pointer CDC hold violations that
// eLinx constraints did not remove from final timing. This module keeps the
// same port contract, depth, width, showahead=OFF style, and one-cycle read
// data latency, while making the CDC synchronizers and timing buffers explicit.
module fifo_data (
    aclr,
    wr_aclr,
    rd_aclr,
    rdclk,
    wrclk,
    data,
    rdreq,
    wrreq,
    rdusedw,
    wrusedw,
    wrfull,
    rdempty,
    wrempty,
    q
);

    parameter DATA_W = 16;
    parameter ADDR_W = 10;
    parameter DEPTH  = 1024;
    parameter PTR_W  = ADDR_W + 1;
    parameter DELAY_WR_TO_RD = 0;
    parameter DELAY_RD_TO_WR = 0;

    input                   aclr;
    input                   wr_aclr;
    input                   rd_aclr;
    input                   rdclk;
    input                   wrclk;
    input      [DATA_W-1:0] data;
    input                   rdreq;
    input                   wrreq;
    output     [DATA_W-1:0] q;
    output     [ADDR_W-1:0] rdusedw;
    output     [ADDR_W-1:0] wrusedw;
    output                  wrfull;
    output                  rdempty;
    output                  wrempty;

    (* preserve, syn_preserve = 1 *) reg [PTR_W-1:0] wr_ptr_bin_r;
    (* preserve, syn_preserve = 1 *) reg [PTR_W-1:0] wr_ptr_gray_r;
    (* preserve, syn_preserve = 1 *) reg [PTR_W-1:0] rd_ptr_bin_r;
    (* preserve, syn_preserve = 1 *) reg [PTR_W-1:0] rd_ptr_gray_r;

    (* preserve, syn_preserve = 1 *) reg [PTR_W-1:0] wr_ptr_gray_rd_sync1_r;
    (* preserve, syn_preserve = 1 *) reg [PTR_W-1:0] wr_ptr_gray_rd_sync2_r;
    (* preserve, syn_preserve = 1 *) reg [PTR_W-1:0] wr_ptr_gray_rd_sync3_r;
    (* preserve, syn_preserve = 1 *) reg [PTR_W-1:0] rd_ptr_gray_wr_sync1_r;
    (* preserve, syn_preserve = 1 *) reg [PTR_W-1:0] rd_ptr_gray_wr_sync2_r;
    (* preserve, syn_preserve = 1 *) reg [PTR_W-1:0] rd_ptr_gray_wr_sync3_r;

    reg              wr_full_r;
    reg              rd_empty_r;
    reg [PTR_W-1:0]  rd_ptr_bin_wr_sync_r;
    reg [PTR_W-1:0]  wr_ptr_bin_rd_sync_r;
    reg [PTR_W-1:0]  wr_used_r;
    reg [PTR_W-1:0]  rd_used_r;
    reg [PTR_W-1:0]  wr_full_cmp_gray_r;
    reg [PTR_W-1:0]  rd_empty_cmp_gray_r;
    // Active-low local reset release chains.  aclr asserts both chains
    // asynchronously; a domain resumes only after two local clock edges.
    (* preserve, syn_preserve = 1 *) reg [1:0] wr_rst_sync_r = 2'b00;
    (* preserve, syn_preserve = 1 *) reg [1:0] rd_rst_sync_r = 2'b00;

    wire [PTR_W-1:0] wr_ptr_gray_delay1_w;
    wire [PTR_W-1:0] wr_ptr_gray_delay2_w;
    wire [PTR_W-1:0] rd_ptr_gray_delay1_w;
    wire [PTR_W-1:0] rd_ptr_gray_delay2_w;

    wire [PTR_W-1:0] wr_ptr_bin_plus1_w;
    wire [PTR_W-1:0] rd_ptr_bin_plus1_w;
    wire [PTR_W-1:0] wr_ptr_bin_next_w;
    wire [PTR_W-1:0] rd_ptr_bin_next_w;
    wire [PTR_W-1:0] wr_ptr_gray_next_w;
    wire [PTR_W-1:0] rd_ptr_gray_next_w;
    wire [PTR_W-1:0] wr_ptr_gray_plus1_w;
    wire [PTR_W-1:0] rd_ptr_gray_plus1_w;
    wire              wr_full_now_w;
    wire              wr_full_after_write_w;
    wire              rd_empty_now_w;
    wire              rd_empty_after_read_w;
    wire              wr_full_next_w;
    wire              rd_empty_next_w;
    wire              wr_fire_w;
    wire              rd_fire_w;
    wire              wr_aclr_w;
    wire              rd_aclr_w;
    wire              wr_rst_active_w;
    wire              rd_rst_active_w;
    wire [DATA_W-1:0] ram_q_w;

    genvar gi;

    function [PTR_W-1:0] bin_to_gray;
        input [PTR_W-1:0] bin;
        begin
            bin_to_gray = (bin >> 1) ^ bin;
        end
    endfunction

    function [PTR_W-1:0] gray_to_bin;
        input [PTR_W-1:0] gray;
        integer idx;
        begin
            gray_to_bin[PTR_W-1] = gray[PTR_W-1];
            for (idx = PTR_W-2; idx >= 0; idx = idx - 1)
                gray_to_bin[idx] = gray_to_bin[idx+1] ^ gray[idx];
        end
    endfunction

    generate
        if (DELAY_WR_TO_RD != 0) begin : g_wr_to_rd_delay
            for (gi = 0; gi < PTR_W; gi = gi + 1) begin : g_bit
                lcell u_delay0 (
                    .in  (wr_ptr_gray_r[gi]),
                    .out (wr_ptr_gray_delay1_w[gi])
                );
                lcell u_delay1 (
                    .in  (wr_ptr_gray_delay1_w[gi]),
                    .out (wr_ptr_gray_delay2_w[gi])
                );
            end
        end else begin : g_wr_to_rd_direct
            assign wr_ptr_gray_delay1_w = wr_ptr_gray_r;
            assign wr_ptr_gray_delay2_w = wr_ptr_gray_r;
        end

        if (DELAY_RD_TO_WR != 0) begin : g_rd_to_wr_delay
            for (gi = 0; gi < PTR_W; gi = gi + 1) begin : g_bit
                lcell u_delay0 (
                    .in  (rd_ptr_gray_r[gi]),
                    .out (rd_ptr_gray_delay1_w[gi])
                );
                lcell u_delay1 (
                    .in  (rd_ptr_gray_delay1_w[gi]),
                    .out (rd_ptr_gray_delay2_w[gi])
                );
            end
        end else begin : g_rd_to_wr_direct
            assign rd_ptr_gray_delay1_w = rd_ptr_gray_r;
            assign rd_ptr_gray_delay2_w = rd_ptr_gray_r;
        end
    endgenerate

    assign wr_ptr_bin_plus1_w = wr_ptr_bin_r + {{(PTR_W-1){1'b0}}, 1'b1};
    assign rd_ptr_bin_plus1_w = rd_ptr_bin_r + {{(PTR_W-1){1'b0}}, 1'b1};
    assign wr_fire_w = wrreq & ~wr_full_r & ~wr_rst_active_w;
    assign rd_fire_w = rdreq & ~rd_empty_r & ~rd_rst_active_w;
    assign wr_ptr_bin_next_w = wr_fire_w ? wr_ptr_bin_plus1_w : wr_ptr_bin_r;
    assign rd_ptr_bin_next_w = rd_fire_w ? rd_ptr_bin_plus1_w : rd_ptr_bin_r;
    assign wr_ptr_gray_next_w = bin_to_gray(wr_ptr_bin_next_w);
    assign rd_ptr_gray_next_w = bin_to_gray(rd_ptr_bin_next_w);
    assign wr_ptr_gray_plus1_w = bin_to_gray(wr_ptr_bin_plus1_w);
    assign rd_ptr_gray_plus1_w = bin_to_gray(rd_ptr_bin_plus1_w);

    assign wr_full_now_w = (wr_ptr_gray_r == wr_full_cmp_gray_r);
    assign wr_full_after_write_w = (wr_ptr_gray_plus1_w == wr_full_cmp_gray_r);
    assign rd_empty_now_w = (rd_ptr_gray_r == rd_empty_cmp_gray_r);
    assign rd_empty_after_read_w = (rd_ptr_gray_plus1_w == rd_empty_cmp_gray_r);
    assign wr_full_next_w = wr_fire_w ? wr_full_after_write_w : wr_full_now_w;
    assign rd_empty_next_w = rd_fire_w ? rd_empty_after_read_w : rd_empty_now_w;

    // Keep the public contract quiescent for the complete asynchronous-assert /
    // synchronous-release interval.  The RAM contents are intentionally not
    // cleared; zeroed pointers and the empty flag make all pre-reset payloads
    // unreachable before either endpoint is allowed to resume.
    assign wrusedw = (wr_rst_active_w == 1'b1) ? {ADDR_W{1'b0}}
                   : wr_used_r[PTR_W-1] ? {ADDR_W{1'b1}} : wr_used_r[ADDR_W-1:0];
    assign rdusedw = (rd_rst_active_w == 1'b1) ? {ADDR_W{1'b0}}
                   : rd_used_r[PTR_W-1] ? {ADDR_W{1'b1}} : rd_used_r[ADDR_W-1:0];
    assign wrfull = (wr_rst_active_w == 1'b1) ? 1'b0 : wr_full_r;
    assign rdempty = (rd_rst_active_w == 1'b1) ? 1'b1 : rd_empty_r;
    assign wrempty = (wr_rst_active_w == 1'b1) ? 1'b1
                   : (wr_ptr_gray_r == rd_ptr_gray_wr_sync3_r);
    assign q = (rd_rst_active_w == 1'b1) ? {DATA_W{1'b0}} : ram_q_w;
    assign wr_aclr_w = aclr | wr_aclr;
    assign rd_aclr_w = aclr | rd_aclr;
    assign wr_rst_active_w = ~wr_rst_sync_r[1];
    assign rd_rst_active_w = ~rd_rst_sync_r[1];

    fifo_data_m4k_dc_sdp_ram #(
        .DATA_W (DATA_W),
        .ADDR_W (ADDR_W),
        .DEPTH  (DEPTH)
    ) u_ram (
        .wr_clk  (wrclk),
        .wr_en   (wr_fire_w),
        .wr_addr (wr_ptr_bin_r[ADDR_W-1:0]),
        .wr_data (data),
        .rd_clk  (rdclk),
        .rd_addr (rd_ptr_bin_r[ADDR_W-1:0]),
        .rd_data (ram_q_w)
    );

    always @(posedge wrclk or posedge wr_aclr_w) begin
        if (wr_aclr_w)
            wr_rst_sync_r <= 2'b00;
        else
            wr_rst_sync_r <= {wr_rst_sync_r[0], 1'b1};
    end

    always @(posedge rdclk or posedge rd_aclr_w) begin
        if (rd_aclr_w)
            rd_rst_sync_r <= 2'b00;
        else
            rd_rst_sync_r <= {rd_rst_sync_r[0], 1'b1};
    end

    always @(posedge wrclk or posedge wr_aclr_w) begin
        if (wr_aclr_w) begin
            wr_ptr_bin_r <= {PTR_W{1'b0}};
            wr_ptr_gray_r <= {PTR_W{1'b0}};
            wr_full_r <= 1'b0;
            rd_ptr_bin_wr_sync_r <= {PTR_W{1'b0}};
            wr_used_r <= {PTR_W{1'b0}};
            wr_full_cmp_gray_r <= {PTR_W{1'b0}};
        end else if (wr_rst_active_w == 1'b1) begin
            wr_ptr_bin_r <= {PTR_W{1'b0}};
            wr_ptr_gray_r <= {PTR_W{1'b0}};
            wr_full_r <= 1'b0;
            rd_ptr_bin_wr_sync_r <= {PTR_W{1'b0}};
            wr_used_r <= {PTR_W{1'b0}};
            wr_full_cmp_gray_r <= {PTR_W{1'b0}};
        end else begin
            wr_ptr_bin_r <= wr_ptr_bin_next_w;
            wr_ptr_gray_r <= wr_ptr_gray_next_w;
            wr_full_r <= wr_full_next_w;

            rd_ptr_bin_wr_sync_r <= gray_to_bin(rd_ptr_gray_wr_sync3_r);
            wr_used_r <= wr_ptr_bin_r - rd_ptr_bin_wr_sync_r;
            wr_full_cmp_gray_r <= {~rd_ptr_gray_wr_sync3_r[PTR_W-1:PTR_W-2],
                                   rd_ptr_gray_wr_sync3_r[PTR_W-3:0]};
        end
    end

    always @(posedge rdclk or posedge rd_aclr_w) begin
        if (rd_aclr_w) begin
            rd_ptr_bin_r <= {PTR_W{1'b0}};
            rd_ptr_gray_r <= {PTR_W{1'b0}};
            rd_empty_r <= 1'b1;
            wr_ptr_bin_rd_sync_r <= {PTR_W{1'b0}};
            rd_used_r <= {PTR_W{1'b0}};
            rd_empty_cmp_gray_r <= {PTR_W{1'b0}};
        end else if (rd_rst_active_w == 1'b1) begin
            rd_ptr_bin_r <= {PTR_W{1'b0}};
            rd_ptr_gray_r <= {PTR_W{1'b0}};
            rd_empty_r <= 1'b1;
            wr_ptr_bin_rd_sync_r <= {PTR_W{1'b0}};
            rd_used_r <= {PTR_W{1'b0}};
            rd_empty_cmp_gray_r <= {PTR_W{1'b0}};
        end else begin
            rd_ptr_bin_r <= rd_ptr_bin_next_w;
            rd_ptr_gray_r <= rd_ptr_gray_next_w;
            rd_empty_r <= rd_empty_next_w;

            wr_ptr_bin_rd_sync_r <= gray_to_bin(wr_ptr_gray_rd_sync3_r);
            rd_used_r <= wr_ptr_bin_rd_sync_r - rd_ptr_bin_r;
            rd_empty_cmp_gray_r <= wr_ptr_gray_rd_sync3_r;
        end
    end

    always @(posedge rdclk or posedge rd_aclr_w) begin
        if (rd_aclr_w) begin
            wr_ptr_gray_rd_sync1_r <= {PTR_W{1'b0}};
            wr_ptr_gray_rd_sync2_r <= {PTR_W{1'b0}};
            wr_ptr_gray_rd_sync3_r <= {PTR_W{1'b0}};
        end else if (rd_rst_active_w == 1'b1) begin
            wr_ptr_gray_rd_sync1_r <= {PTR_W{1'b0}};
            wr_ptr_gray_rd_sync2_r <= {PTR_W{1'b0}};
            wr_ptr_gray_rd_sync3_r <= {PTR_W{1'b0}};
        end else begin
            wr_ptr_gray_rd_sync1_r <= wr_ptr_gray_delay2_w;
            wr_ptr_gray_rd_sync2_r <= wr_ptr_gray_rd_sync1_r;
            wr_ptr_gray_rd_sync3_r <= wr_ptr_gray_rd_sync2_r;
        end
    end

    always @(posedge wrclk or posedge wr_aclr_w) begin
        if (wr_aclr_w) begin
            rd_ptr_gray_wr_sync1_r <= {PTR_W{1'b0}};
            rd_ptr_gray_wr_sync2_r <= {PTR_W{1'b0}};
            rd_ptr_gray_wr_sync3_r <= {PTR_W{1'b0}};
        end else if (wr_rst_active_w == 1'b1) begin
            rd_ptr_gray_wr_sync1_r <= {PTR_W{1'b0}};
            rd_ptr_gray_wr_sync2_r <= {PTR_W{1'b0}};
            rd_ptr_gray_wr_sync3_r <= {PTR_W{1'b0}};
        end else begin
            rd_ptr_gray_wr_sync1_r <= rd_ptr_gray_delay2_w;
            rd_ptr_gray_wr_sync2_r <= rd_ptr_gray_wr_sync1_r;
            rd_ptr_gray_wr_sync3_r <= rd_ptr_gray_wr_sync2_r;
        end
    end

endmodule

module fifo_data_m4k_dc_sdp_ram #(
    parameter DATA_W = 16,
    parameter ADDR_W = 10,
    parameter DEPTH  = 1024
) (
    input                   wr_clk,
    input                   wr_en,
    input      [ADDR_W-1:0] wr_addr,
    input      [DATA_W-1:0] wr_data,
    input                   rd_clk,
    input      [ADDR_W-1:0] rd_addr,
    output     [DATA_W-1:0] rd_data
);

    wire [DATA_W-1:0] rd_data_w;

    assign rd_data = rd_data_w;

    altsyncram altsyncram_component (
        .wren_a         (wr_en),
        .wren_b         (1'b0),
        .clock0         (wr_clk),
        .clock1         (rd_clk),
        .address_a      (wr_addr),
        .address_b      (rd_addr),
        .data_a         (wr_data),
        .data_b         ({DATA_W{1'b0}}),
        .q_b            (rd_data_w),
        .q_a            (),
        .aclr0          (1'b0),
        .aclr1          (1'b0),
        .addressstall_a (1'b0),
        .addressstall_b (1'b0),
        .byteena_a      (1'b1),
        .byteena_b      (1'b1),
        .clocken0       (1'b1),
        .clocken1       (1'b1),
        .clocken2       (1'b1),
        .clocken3       (1'b1),
        .eccstatus      (),
        .rden_a         (1'b1),
        .rden_b         (1'b1)
    );

    defparam
        altsyncram_component.address_aclr_a                     = "NONE",
        altsyncram_component.address_aclr_b                     = "NONE",
        altsyncram_component.address_reg_b                      = "CLOCK1",
        altsyncram_component.indata_aclr_a                      = "NONE",
        altsyncram_component.intended_device_family             = "Stratix",
        altsyncram_component.lpm_type                           = "altsyncram",
        altsyncram_component.numwords_a                         = DEPTH,
        altsyncram_component.numwords_b                         = DEPTH,
        altsyncram_component.operation_mode                     = "DUAL_PORT",
        altsyncram_component.outdata_aclr_b                     = "NONE",
        altsyncram_component.outdata_reg_b                      = "UNREGISTERED",
        altsyncram_component.power_up_uninitialized             = "FALSE",
        altsyncram_component.ram_block_type                     = "M4K",
        altsyncram_component.read_during_write_mode_mixed_ports = "OLD_DATA",
        altsyncram_component.widthad_a                          = ADDR_W,
        altsyncram_component.widthad_b                          = ADDR_W,
        altsyncram_component.width_a                            = DATA_W,
        altsyncram_component.width_b                            = DATA_W,
        altsyncram_component.width_byteena_a                    = 1,
        altsyncram_component.init_file                          = "UNUSED",
        altsyncram_component.wrcontrol_aclr_a                   = "NONE";

endmodule
