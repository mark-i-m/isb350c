`timescale 1ps/1ps

// A toy implementation of the ISB (Jain and Lin, MICRO14).

// Specs
// -----
// Max steam length: 16 addrs
// PS-AMC size: 32 entries mapping 1 addr each
// SP-AMC size: 2 entries mapping 16 addrs each
// Training unit: 4 entries
// Steam predictor: 1 stream buffer with a queue of 4 entries, degree 1

// Lots of macros:
`define TU_V(tu_num) //TODO: define these
`define TU_PC(tu_num)
`define TU_LAST(tu_num)

module isb(input clk,
    input v_in, input [15:0]pc, input [15:0]addr, //TODO: hook these up
    output prefetch_v, output [15:0]prefetch_addr
);

// next unallocated SA
// allocate 16 addrs at a time
reg [31:0]next_sa = 0;

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
// TODO: need LRU? Use round robin?

// lookup pc in the TU
wire pc_v = (`TU_PC(0) == pc && `TU_V(0)) ||
            (`TU_PC(1) == pc && `TU_V(1)) ||
            (`TU_PC(2) == pc && `TU_V(2)) ||
            (`TU_PC(3) == pc && `TU_V(3)) ;
wire pc_last = (`TU_PC(0) == pc && `TU_V(0)) ? `TU_LAST(0) :
               (`TU_PC(1) == pc && `TU_V(1)) ? `TU_LAST(1) :
               (`TU_PC(2) == pc && `TU_V(2)) ? `TU_LAST(2) :
               `TU_LAST(3);

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

wire a = psamc_lookup(pc_last) // TODO: undefined wire
wire b = psamc_lookup(addr) // TODO:undefined wire
wire ab_comp = {`PSAMC_V(a), `PSAMC(b)}; // compare presence of a and b

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


// stream predictor
// fifo queue of 4 entries
fifo #(2) sb0(/*TODO: ports*/);


// update logic
always @(posedge clk) begin
    // training
    if (pc_v && pc_last != addr) begin
        // Update mappings
        case(ab_comp)
            0 : begin
                // TODO:neither a nor b in psamc
            end
            1 : begin
                // TODO:only b in psamc
            end
            2 : begin
                // TODO:only a in psamc
            end
            3 : begin
                // TODO:both in psamc
            end
        endcase
    end else if (!pc_v) begin
        // TODO:insert into TU
    end
end

// TODO: prediction

endmodule
