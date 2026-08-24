//#M4K
module line_buffer (
    clock,
    data,
    rdaddress,
    wraddress,
    wren,
    q);

    input	  clock;
    input	[15:0]  data;
    input	[9:0]  rdaddress;
    input	[9:0]  wraddress;
    input	  wren;
    output	[15:0]  q;

    wire [15:0] sub_wire0;
    wire [15:0] q = sub_wire0[15:0];

    altsyncram	altsyncram_component (
                .wren_a (wren),
                .wren_b (1'b0),
                .clock0 (clock),
                .clock1 (1'b1),
                .address_a (wraddress),
                .address_b (rdaddress),
                .data_a (data),
                .data_b ({16{1'b1}}),
                .q_b (sub_wire0),
                .q_a (),
                .aclr0 (1'b0),
                .aclr1 (1'b0),
                .addressstall_a (1'b0),
                .addressstall_b (1'b0),
                .byteena_a (1'b1),
                .byteena_b (1'b1),
                .clocken0 (1'b1),
                .clocken1 (1'b1),
                .clocken2 (1'b1),
                .clocken3 (1'b1),
                .eccstatus (),
                .rden_a (1'b1),
                .rden_b (1'b1)
);

    defparam
        altsyncram_component.address_aclr_a = "NONE",
        altsyncram_component.address_aclr_b = "NONE",
        altsyncram_component.address_reg_b = "CLOCK0",
        altsyncram_component.indata_aclr_a = "NONE",
        altsyncram_component.intended_device_family = "Stratix",
        altsyncram_component.lpm_type = "altsyncram",
        altsyncram_component.numwords_a = 1024,
        altsyncram_component.numwords_b = 1024,
        altsyncram_component.operation_mode = "DUAL_PORT",
        altsyncram_component.outdata_aclr_b = "NONE",
        altsyncram_component.outdata_reg_b = "CLOCK0",
        altsyncram_component.power_up_uninitialized = "FALSE",
        altsyncram_component.ram_block_type = "M4K",
        altsyncram_component.widthad_a = 10,
        altsyncram_component.widthad_b = 10,
        altsyncram_component.width_a = 16,
        altsyncram_component.width_b = 16,
        altsyncram_component.width_byteena_a = 1,
        altsyncram_component.init_file = "UNUSED",
        altsyncram_component.wrcontrol_aclr_a = "NONE";


endmodule
