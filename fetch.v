`timescale 1ps/1ps

// Implementation of a Fetch Unit that places instructions in a buffer
//
// If the buffer is full, fetch stops
//
// Assumes the magic 1 cycle fetch port, but should work correctly regardless

module fetch(input clk,
    // instruction buffer
    output ib_push, output [31:0]ib_push_data, input ib_full,
    // memory access
    output [15:0]mem_raddr, output mem_re,
    input [15:0]mem_addr_out, input [15:0]mem_data_out, input mem_ready,
    // jump feedback
    input branch_taken, input [15:0]branch_target
    );

    reg first = 1;

    reg [15:0]pc = 16'h0000;
    reg v = 1;

    wire [15:0]next_pc = first ? 0 :
                         branch_taken ? branch_target :
                         !ib_full ? pc + 1 :
                         pc; // keep trying until it works

    always @(posedge clk) begin
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
