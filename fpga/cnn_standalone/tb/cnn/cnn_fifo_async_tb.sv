`timescale 1ns/1ps

/*
 * Contract test for the project-local fifo_data plus cnn_fifo_pop adapter.
 * The test deliberately uses asynchronous 75 MHz / 25 MHz domains and does
 * not model q as show-ahead data: every observed pop must be ordered and
 * exactly match one accepted write.
 */
module cnn_fifo_async_tb;

reg wrclk = 1'b0;
reg rdclk = 1'b0;
/* The enables deliberately park a domain low.  They model a PLL/clock-stop
 * event without manufacturing a final half-cycle, so reset can be asserted
 * and released entirely while that domain is not sampling it. */
reg wrclk_enable = 1'b1;
reg rdclk_enable = 1'b1;
always #6.666 begin
    if (wrclk_enable)
        wrclk = ~wrclk;
end // 75 MHz
always #20.000 begin
    if (rdclk_enable)
        rdclk = ~rdclk;
end // 25 MHz

reg wr_reset_req;
reg rd_reset_req;
/* CNN integration contract: either domain's reset request fan-outs to both
 * sides of both async FIFOs.  No unilateral pointer reset is permitted. */
wire shared_rst_n = !(wr_reset_req || rd_reset_req);
reg [7:0] wr_data;
reg wrreq;
wire wrfull;
wire wrempty;
wire rdempty;
wire [2:0] wrusedw;
wire [2:0] rdusedw;
wire [7:0] fifo_q;
wire fifo_rdreq;
wire pop_valid;
wire [7:0] pop_data;

reg [7:0] expected [0:31];
integer wr_count;
integer rd_count;
integer checks;

fifo_data #(
    .DATA_W(8), .ADDR_W(3), .DEPTH(8)
) dut_fifo (
    .aclr(1'b0), .wr_aclr(~shared_rst_n), .rd_aclr(~shared_rst_n),
    .wrclk(wrclk), .wrreq(wrreq), .data(wr_data), .wrusedw(wrusedw),
    .wrfull(wrfull), .wrempty(wrempty),
    .rdclk(rdclk), .rdreq(fifo_rdreq), .q(fifo_q), .rdusedw(rdusedw),
    .rdempty(rdempty)
);

cnn_fifo_pop #(.DATA_W(8)) dut_pop (
    .clk(rdclk), .rst_n(shared_rst_n), .fifo_empty(rdempty), .fifo_q(fifo_q),
    .fifo_rdreq(fifo_rdreq), .pop_valid(pop_valid), .pop_data(pop_data)
);

task check_ok;
    input condition;
    input [8*100-1:0] message;
    begin
        checks = checks + 1;
        if (!condition)
            $fatal(1, "%0s", message);
    end
endtask

task write_word;
    input [7:0] value;
    begin
        @(negedge wrclk);
        $display("cnn_fifo_async_tb write attempt value=%02h wr_count=%0d rd_count=%0d wrfull=%0b time=%0t", value, wr_count, rd_count, wrfull, $time);
        check_ok(!wrfull, "test attempted a write while FIFO reported full");
        wr_data = value;
        wrreq = 1'b1;
        @(posedge wrclk);
        #1;
        check_ok(!wrfull || (wr_count == 7), "FIFO rejected a planned accepted write");
        expected[wr_count] = value;
        wr_count = wr_count + 1;
        @(negedge wrclk);
        wrreq = 1'b0;
    end
endtask

task burst_eight;
    input [7:0] first_value;
    integer n;
    begin
        for (n = 0; n < 8; n = n + 1) begin
            @(negedge wrclk);
            check_ok(!wrfull, "FIFO became full before accepting DEPTH planned words");
            wr_data = first_value + n[7:0];
            wrreq = 1'b1;
            @(posedge wrclk);
            #1;
            expected[wr_count] = first_value + n[7:0];
            wr_count = wr_count + 1;
        end
        @(negedge wrclk);
        wrreq = 1'b0;
    end
endtask

task wait_for_reads;
    input integer target;
    integer watchdog;
    begin
        watchdog = 0;
        while ((rd_count < target) && (watchdog < 400)) begin
            @(posedge rdclk);
            watchdog = watchdog + 1;
        end
        check_ok(rd_count == target, "timeout waiting for ordered FIFO pops");
    end
endtask

/* Sample after NBA updates: fifo_data and cnn_fifo_pop are both sequential. */
always begin
    @(posedge rdclk);
    #1;
    if (shared_rst_n && pop_valid) begin
        check_ok(rd_count < wr_count, "cnn_fifo_pop emitted a duplicated/spurious word");
        check_ok(pop_data === expected[rd_count], "cnn_fifo_pop data was dropped, duplicated, or reordered");
        rd_count = rd_count + 1;
    end
end

initial begin
    checks = 0;
    wr_count = 0;
    rd_count = 0;
    wr_reset_req = 1'b1;
    rd_reset_req = 1'b1;
    wrreq = 1'b0;
    wr_data = 8'd0;

    repeat (4) @(posedge wrclk);
    wr_reset_req = 1'b0;
    rd_reset_req = 1'b0;
    repeat (4) @(posedge wrclk);
    /* Burst eight 75 MHz writes before the 25 MHz side can observe the
     * synchronized pointer; this covers the real full boundary without
     * violating the merged-reset contract. */
    burst_eight(8'h10);
    repeat (2) @(posedge wrclk);
    check_ok(wrfull, "FIFO did not assert full at DEPTH under 75/25 MHz asynchronous burst");
    wait_for_reads(8);
    repeat (5) @(posedge rdclk);
    check_ok(rdempty && !pop_valid, "FIFO did not return to a stable empty state");

    /* A read-side request must reset both FIFO domains and discard prior
     * contents.  Verify recovery produces no ghost and a fresh ordered run. */
    rd_reset_req = 1'b1;
    repeat (4) @(posedge rdclk);
    check_ok(!shared_rst_n && !pop_valid && !fifo_rdreq && !wrfull && rdempty, "read reset request did not jointly clear FIFO domains");
    rd_reset_req = 1'b0;
    repeat (5) @(posedge rdclk);
    wr_count = 0;
    rd_count = 0;
    check_ok(rdempty && !pop_valid, "merged read-request reset recovery created a ghost word");
    write_word(8'h40); write_word(8'h41); write_word(8'h42); write_word(8'h43);
    wait_for_reads(4);

    /* The corresponding write-side request has the identical merged reset
     * behavior and must not leave a permanent full indication. */
    repeat (5) @(posedge rdclk);
    check_ok(rdempty, "precondition failed: FIFO was not empty before writer reset");
    wr_reset_req = 1'b1;
    repeat (4) @(posedge wrclk);
    check_ok(!shared_rst_n && !pop_valid && !fifo_rdreq && !wrfull && rdempty, "write reset request did not jointly clear FIFO domains");
    wr_reset_req = 1'b0;
    repeat (5) @(posedge wrclk);
    wr_count = 0;
    rd_count = 0;
    check_ok(!wrfull, "write-domain reset recovery left FIFO falsely full");
    write_word(8'ha0); write_word(8'ha1); write_word(8'ha2);
    wait_for_reads(3);
    repeat (5) @(posedge rdclk);
    check_ok(rdempty && !pop_valid, "final empty boundary failed");
    check_ok(dut_fifo.wr_ptr_bin_r != 0 && dut_fifo.rd_ptr_bin_r != 0,
             "writer-stop reset precondition did not leave nonzero local pointers");

    /* A complete reset pulse can occur while the 75 MHz side is stopped.
     * Asynchronous assertion must still clear the write-domain state, while
     * release waits for two local rising edges after that clock resumes. */
    @(negedge wrclk);
    wrclk_enable = 1'b0;
    wr_reset_req = 1'b1;
    #1;
    check_ok(!shared_rst_n && dut_fifo.wr_rst_sync_r == 2'b00,
             "stopped write domain did not asynchronously observe reset assertion");
    check_ok(dut_fifo.wr_ptr_bin_r == 0 && dut_fifo.wr_ptr_gray_r == 0
             && dut_fifo.rd_ptr_bin_r == 0 && dut_fifo.rd_ptr_gray_r == 0,
             "stopped write-domain reset did not asynchronously clear FIFO pointers");
    check_ok(!wrfull && rdempty && wrempty && wrusedw == 0 && rdusedw == 0
             && fifo_q == 0 && !pop_valid && !fifo_rdreq,
             "stopped write-domain reset assertion left a ghost/full/empty error");
    repeat (3) @(posedge rdclk);
    wr_reset_req = 1'b0;
    /* The pulse has fully completed while wrclk is stopped: its synchronizer
     * must not release merely because the other domain keeps running. */
    repeat (3) @(posedge rdclk);
    check_ok(shared_rst_n && dut_fifo.wr_rst_sync_r == 2'b00,
             "stopped write domain released reset without local clock edges");
    check_ok(!wrfull && rdempty && !pop_valid && !fifo_rdreq,
             "stopped write-domain reset recovery created a ghost/full/empty error");

    wrclk_enable = 1'b1;
    @(posedge wrclk);
    #1;
    check_ok(dut_fifo.wr_rst_sync_r == 2'b01,
             "write reset synchronizer did not hold reset after its first release edge");
    /* Reassert between synchronizer stages.  This is the vulnerable window
     * for a reset tree that only looks correct when clocks never stop. */
    @(negedge wrclk);
    rd_reset_req = 1'b1;
    #1;
    check_ok(!shared_rst_n && dut_fifo.wr_rst_sync_r == 2'b00,
             "inter-stage write reset reassertion did not restart synchronization");
    check_ok(!wrfull && rdempty && !pop_valid && !fifo_rdreq,
             "inter-stage write reset reassertion left a ghost/full/empty error");
    repeat (3) @(posedge rdclk);
    rd_reset_req = 1'b0;
    repeat (3) @(posedge wrclk);
    repeat (4) @(posedge rdclk);
    check_ok(dut_fifo.wr_rst_sync_r == 2'b11 && dut_fifo.rd_rst_sync_r == 2'b11,
             "FIFO domains did not complete two-edge local reset release after reassertion");
    check_ok(!wrfull && rdempty && !pop_valid && !fifo_rdreq,
             "write-clock restart after inter-stage reset created a ghost/full/empty error");
    wr_count = 0;
    rd_count = 0;
    write_word(8'hc0); write_word(8'hc1);
    wait_for_reads(2);
    repeat (4) @(posedge rdclk);
    check_ok(rdempty && !pop_valid,
             "write-clock stopped-reset recovery did not return to stable empty");

    /* Repeat the full-pulse test with the 25 MHz consumer stopped and unread
     * payload in the RAM.  Reset must make all old addresses unreachable and
     * expose no ghost when the read clock eventually restarts. */
    @(negedge rdclk);
    rdclk_enable = 1'b0;
    wr_count = 0;
    rd_count = 0;
    write_word(8'hd0); write_word(8'hd1); write_word(8'hd2);
    repeat (3) @(posedge wrclk);
    check_ok(!wrempty && dut_fifo.wr_ptr_bin_r != dut_fifo.rd_ptr_bin_r,
             "read-stop reset precondition did not retain unread payload");
    rd_reset_req = 1'b1;
    #1;
    check_ok(!shared_rst_n && dut_fifo.rd_rst_sync_r == 2'b00,
             "stopped read domain did not asynchronously observe reset assertion");
    check_ok(dut_fifo.wr_ptr_bin_r == 0 && dut_fifo.wr_ptr_gray_r == 0
             && dut_fifo.rd_ptr_bin_r == 0 && dut_fifo.rd_ptr_gray_r == 0,
             "stopped read-domain reset did not asynchronously discard unread pointers");
    check_ok(!wrfull && rdempty && wrempty && wrusedw == 0 && rdusedw == 0
             && fifo_q == 0 && !pop_valid && !fifo_rdreq,
             "stopped read-domain reset assertion left a ghost/full/empty error");
    repeat (3) @(posedge wrclk);
    rd_reset_req = 1'b0;
    repeat (3) @(posedge wrclk);
    check_ok(shared_rst_n && dut_fifo.rd_rst_sync_r == 2'b00,
             "stopped read domain released reset without local clock edges");
    check_ok(!wrfull && rdempty && !pop_valid && !fifo_rdreq,
             "stopped read-domain reset recovery created a ghost/full/empty error");
    /* fifo_data computes the full comparison from synchronized read state on
     * the first active write cycle, so allow its registered flag to settle
     * after the two-edge reset-release contract before issuing fresh writes. */
    repeat (2) @(posedge wrclk);
    check_ok(!wrfull, "read-clock stopped reset recovery left FIFO falsely full");
    wr_count = 0;
    rd_count = 0;
    write_word(8'he0); write_word(8'he1);
    rdclk_enable = 1'b1;
    @(posedge rdclk);
    #1;
    check_ok(dut_fifo.rd_rst_sync_r == 2'b01,
             "read reset synchronizer did not hold reset after its first release edge");
    check_ok(rdempty && !pop_valid && !fifo_rdreq,
             "read-clock restart emitted a ghost before the local reset release completed");
    wait_for_reads(2);
    repeat (4) @(posedge rdclk);
    check_ok(rdempty && !pop_valid,
             "read-clock stopped-reset recovery did not return to stable empty");

    $display("cnn_fifo_async_tb PASS checks=%0d writes=%0d reads=%0d", checks, wr_count, rd_count);
    $finish;
end

endmodule
