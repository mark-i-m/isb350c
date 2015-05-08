`timescale 1ps/1ps

// A toy implementation of the ISB (Jain and Lin, MICRO14).

// Specs
// -----
// Max steam length: 16 addrs
// PS-AMC size: 32 entries mapping 1 addr each
// SP-AMC size: 2 entries mapping 16 addrs each
// Training unit: 4 entries
// Steam predictor: 1 stream buffer with a queue of 4 entries, degree 1

module isb(input clk,
    input v_in, input [15:0]pc, input [15:0]addr,
    output prefetch_v, output [15:0]prefetch_addr
);

// PS-AMC
// bits | field
// 1    | valid
// 16   | tag (just use the whole adr)
// 32   | structural addr
// 2    | confidence counter
// -----|--------------------
// 51   | total
//
// 32 entries
reg [50:0]psamc[31:0];


// SP-AMC
// bits | field
// 1    | valid
// 32   | tag (just use whole addr)
// 256  | 16 physical addresses
// -----|----------------------
// 289  | total
//
// 2 entries
reg [288:0]spamc[1:0];


// training unit
// bits | field
// 1    | valid
// 16   | pc
// 16   | last addr
// -----|-----------
// 33   | total
//
// 4 entries
reg [32:0]tu[3:0];


// stream predictor
// fifo queue of 4 entries
fifo #(2) sb0(/*TODO: ports*/);


endmodule
