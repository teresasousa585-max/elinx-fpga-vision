//#M4K
module meiyan_rom_scurve(
address,
clock,
q);

input	[7:0]  address;
input	  clock;
output	[7:0]  q;

wire	[7:0] sub_wire0;
wire	[7:0] q = sub_wire0 [7:0];

altsyncram	altsyncram_component (
                .wren_a (1'b0),
                .aclr0 (1'b0),
                .clock0 (clock),
                .byteena_a (1'b1),
                .address_a (address),
                .data_a ({8{1'b1}}),
                .q_a (sub_wire0),
                .aclr1 (1'b0),
                .address_b (1'b1),
                .addressstall_a (1'b0),
                .addressstall_b (1'b0),
                .byteena_b (1'b1),
                .clock1 (1'b1),
                .clocken0 (1'b1),
                .clocken1 (1'b1),
                .clocken2 (1'b1),
                .clocken3 (1'b1),
                .data_b (1'b1),
                .eccstatus (),
                .q_b (),
                .rden_a (1'b1),
                .rden_b (1'b1),
                .wren_b (1'b0));
defparam
        altsyncram_component.address_aclr_a = "NONE",
        altsyncram_component.intended_device_family = "Stratix",
        altsyncram_component.lpm_hint = "ENABLE_RUNTIME_MOD=NO",
        altsyncram_component.lpm_type = "altsyncram",
        altsyncram_component.numwords_a = 256,
        altsyncram_component.operation_mode = "ROM",
        altsyncram_component.outdata_aclr_a = "NONE",
        altsyncram_component.outdata_reg_a = "CLOCK0",
        altsyncram_component.ram_block_type = "M4K",
        altsyncram_component.widthad_a = 8,
        altsyncram_component.width_a =  8,
        altsyncram_component.width_byteena_a = 1,
        altsyncram_component.init_file = "../../../../scurve_whitening.mif";

endmodule
