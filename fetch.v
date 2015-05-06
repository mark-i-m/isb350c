`timescale 1ps/1ps

// A simple pipelined Fetch Unit
//
// It fetches at the current PC and pushes to the tail of the IB
// It does not flush or pop the buffer if there is a branch.
// 
// It should work for any memory latency, but is optimized for the magic
// 1 cycle fetch port. If anything happens, it discards the result and
// tries again.

module fetch(input clk,
    // instruction buffer
    output ib_push, output [31:0]ib_push_data, input ib_full,
    // memory access
    output [15:0]mem_raddr, output mem_re,
    input [15:0]mem_addr_out, input [15:0]mem_data_out, input mem_ready,
    // jump feedback
    input branch_taken, input [15:0]branch_target
    );

    // is this the first instr?
    // if so, we do not want to wait for mem_ready
    reg first = 1;

    // current fetch PC (the address mem is working on)
    reg [15:0]pc = 16'h0000;
    // is this pc valid?
    reg v = 1;

    // what is the next PC? 
    wire [15:0]next_pc = first ? 0 :
                         branch_taken ? branch_target :
                         !ib_full ? pc + 1 :
                         pc; // keep trying until it works

    // update every cycle
    always @(posedge clk) begin
        // if mem is ready, send next request
        if (mem_ready) begin
            pc <= next_pc;
            v <= 1;
        end

        first <= 0;
    end

    // output
    assign ib_push = v && !branch_taken && mem_ready;
    assign ib_push_data[31:16] = pc;
    assign ib_push_data[15:0]  = mem_data_out;

    assign mem_raddr = next_pc;
    assign mem_re = first || mem_ready;

endmodule
