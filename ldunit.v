`timescale 1ps/1ps

// A LD unit for the Tomasulo algo
//
// It is parametrized by its reservation station numbers
//
// It can do the following operations:
//
//  LD
//
// The FU has 4 reservation stations
//
// This LD unit connects to a 3-level data cache system
// and finally, to memory.

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
    // TODO: update oupts
    // insert new instruction
    input re, input [5:0]rs_num, input [15:0]raddr,
    // output result
    output valid_out, output [5:0]rs_num_out, output [15:0]res_out,
    // connected to memory
    output [15:0]mem_raddr, output mem_re,
    input [15:0]mem_addr_out, input [15:0]mem_data_out, input mem_ready,
    // busy?
    output busy
    );

    ///////////////// cache and memory access ///////////////////////

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
    facache l1d(clk, raddr, readEnable && state == `W0,
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
        l2d_evicted_adr, l2d_evicted_data, l2d_evicted_valid,
        l3d_data, l3d_hit,
        l3d_evicted_adr, l3d_evicted_data, l3d_evicted_valid);

    // update state
    always @(posedge clk) begin
        case(state)
            `W0 : begin
                valid_out_reg <= 0;
                res_out_reg <= 16'hxxxx;

                re_in <= re;
                raddr_in <= raddr;
                rs_num_out_reg <= rs_num;

                if(re) begin
                    state <= `L1;
                end
            end
            `L1 : begin
                if (l1d_hit) begin
                    valid_out_reg <= 1;
                    res_out_reg <= l1d_data;
                    state <= `W0;
                end else begin
                    state <= `L2;
                end
            end
            `L2 : begin
                if (l2d_hit) begin
                    valid_out_reg <= 1;
                    res_out_reg <= l2d_data;
                    state <= `W0;
                end else begin
                    state <= `L3;
                end
            end
            `L3 : begin
                if(l3d_hit) begin
                    valid_out_reg <= 1;
                    res_out_reg <= l3d_data;
                    state <= `W0;
                end else begin
                    mem_re_reg <= 1;
                    mem_raddr_reg <= raddr_in;
                    state <= `M0;
                end
            end
            `M0 : begin
                mem_re_reg <= 0;
                mem_raddr_reg <= 16'hxxxx;

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

    reg [15:0]res_out_reg = 16'hxxxx;
    assign res_out = res_out_reg;

    reg [5:0]rs_num_out_reg = 4; //initialize to 4 > 3
    assign rs_num_out = rs_num_out_reg;

    reg [15:0]mem_raddr_reg = 16'hxxxx;
    assign mem_raddr = mem_raddr_reg;

    reg mem_re_reg = 0;
    assign mem_re = mem_re_reg;

    assign busy = re || re_in;

endmodule
