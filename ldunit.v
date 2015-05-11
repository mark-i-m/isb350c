`timescale 1ps/1ps

// A LD unit
//
// It can do the following operations:
//
//  LD, LDR
//
// It is implemented as a state machine for simplicity.
//
// Should work for any memory latency, but is optimized for the long
// 100 cycle latency data port.
//
// It has 3 levels of caches. Each is 4 words and fully associative.
// Evictions from one level go to the next level. Each extra level has
// an extra cycle of latency.
//
// Also there is a prefetcher. It trains on the L3 access stream and inserts
// into the L3 cache. See REPORT.txt for details.

// Memory access states:
`define W0 0 //idle
`define L1 1 //checking l1
`define L2 2 //checking l2
`define L3 3 //checking l3
`define M0 4 //read from mem

// opcodes
`define LD 4
`define LDR 5

module ld(input clk,
    // instructions from RSs
    input valid, input [5:0]rs_num, input [3:0]op, input [15:0]pc,
    input [15:0]val0, input [15:0]val1,
    // output result
    output valid_out, output [5:0]rs_num_out, output [3:0]op_out, output [15:0]res_out,
    // connected to memory
    output [15:0]mem_raddr, output mem_re,
    input [15:0]mem_addr_out, input [15:0]mem_data_out, input mem_ready,
    // busy?
    output busy
    );

    /////////////////// cache and memory access ///////////////////////

    // state
    reg [2:0]state = `W0;

    reg re_in = 0;
    reg [15:0]raddr_in;

    // L1D
    wire l1d_hit;
    wire [15:0]l1d_data;

    wire [15:0]l1d_evicted_adr;
    wire [15:0]l1d_evicted_data;
    wire l1d_evicted_valid;
    facache l1d(clk, (op == `LD ? val0 : val0 + val1), valid && state == `W0,
        raddr_in, mem_data_out, mem_ready && mem_addr_out == raddr_in,
        l1d_data, l1d_hit,
        l1d_evicted_adr, l1d_evicted_data, l1d_evicted_valid);

    // L2D
    wire l2d_hit;
    wire [15:0]l2d_data;

    wire [15:0]l2d_evicted_adr;
    wire [15:0]l2d_evicted_data;
    wire l2d_evicted_valid;
    facache l2d(clk, raddr_in, state == `L1,
        l1d_evicted_adr, l1d_evicted_data, l1d_evicted_valid,
        l2d_data, l2d_hit,
        l2d_evicted_adr, l2d_evicted_data, l2d_evicted_valid);

    // L3D
    wire l3d_hit;
    wire [15:0]l3d_data;

    wire [15:0]l3d_evicted_adr;
    wire [15:0]l3d_evicted_data;
    wire l3d_evicted_valid;
    facache l3d(clk, raddr_in, state == `L2,
        l2d_evicted_adr, l2d_evicted_data, l2d_evicted_valid, // TODO: insert prefetches here
        l3d_data, l3d_hit,
        l3d_evicted_adr, l3d_evicted_data, l3d_evicted_valid);

    // ISB prefetcher
    // It trains on the L3 access stream and prefetches into the L3 cache
    wire prefetch_re, prefetched_v;
    wire [15:0]prefetch_addr, prefetched_addr, prefetched_data;//TODO hook these up

    isb #(1) isb0(clk,
        state == `L2, pc, raddr_in,
        prefetch_re, prefetch_addr, !mem_re_reg,
        mem_addr_out, mem_data_out, mem_ready,
        prefetched_v, prefetched_addr, prefetched_data
    );

    // update state
    always @(posedge clk) begin
        case(state)
            `W0 : begin // idle?
                // waiting for next access
                valid_out_reg <= 0;
                res_out_reg <= 16'hxxxx;

                re_in <= valid;
                raddr_in <= op == `LD ? val0 : val0 + val1;
                op_out_reg <= op;
                rs_num_out_reg <= rs_num;

                // if there is an access, check L1
                if(valid) begin
                    state <= `L1;
                end
            end
            `L1 : begin
                if (l1d_hit) begin // if hit, return value
                    valid_out_reg <= 1;
                    res_out_reg <= l1d_data;
                    state <= `W0;
                end else begin // else, check next level
                    state <= `L2;
                end
            end
            `L2 : begin // same as above
                if (l2d_hit) begin
                    valid_out_reg <= 1;
                    res_out_reg <= l2d_data;
                    state <= `W0;
                end else begin
                    state <= `L3;
                end
            end
            `L3 : begin
                if(l3d_hit) begin // if hit, same as above
                    valid_out_reg <= 1;
                    res_out_reg <= l3d_data;
                    state <= `W0;
                end else begin // otherwise, submit mem request
                    mem_re_reg <= 1;
                    mem_raddr_reg <= raddr_in;
                    state <= `M0;
                end
            end
            `M0 : begin
                // stop submitting request, as per protocol
                mem_re_reg <= 0;
                mem_raddr_reg <= 16'hxxxx;

                // when the value is broadcast on memory bus, return it
                if(mem_ready && mem_addr_out == raddr_in) begin
                    valid_out_reg <= 1;
                    res_out_reg <= mem_data_out;
                    state <= `W0;
                end
            end

            default : begin
                $display("Unknown state!");
                $finish;
            end
        endcase
    end

    // output
    reg valid_out_reg = 0;
    assign valid_out = valid_out_reg;

    reg [5:0]rs_num_out_reg;
    assign rs_num_out = rs_num_out_reg;

    reg [3:0]op_out_reg;
    assign op_out = op_out_reg;

    reg [15:0]res_out_reg = 16'hxxxx;
    assign res_out = res_out_reg;

    reg [15:0]mem_raddr_reg = 16'hxxxx;
    assign mem_raddr = mem_re_reg ? mem_raddr_reg : prefetch_addr;

    reg mem_re_reg = 0;
    assign mem_re = mem_re_reg || prefetch_re;

    assign busy = valid || re_in;

endmodule
