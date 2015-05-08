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
`define TU_V(tu_num)    tu[tu_num][32]
`define TU_PC(tu_num)   tu[tu_num][31:16]
`define TU_LAST(tu_num) tu[tu_num][15:0]

module isb(input clk,
    input v_in, input [15:0]pc, input [15:0]addr,
    output prefetch_v, output [15:0]prefetch_addr //TODO: hook these up
);

// next unallocated SA
// allocate 16 addrs at a time
reg [31:0]next_sa = 0;


//////////////////////////////// training unit /////////////////////////////////
// bits | field
// 1    | valid
// 16   | pc
// 16   | last addr
// -----|-----------
// 33   | total
//
// 4 entries
reg [32:0]tu[3:0];

// update TU
reg tu_insert_idx = ; //TODO: undefined, use LRU *OR* current entry index if pc is already there
reg tu_insert_v = 0;  //TODO: assign to these
reg tu_insert_pc;
reg tu_insert_last;

always @(posedge clk) begin
    if(tu_insert_v) begin
        tu[tu_insert_idx] <= {tu_insert_v, tu_insert_pc, tu_insert_last};
    end
end

// lookup pc in the TU
reg pc_v;
reg [15:0]pc_last;

always @(pc) begin
    pc_v <= `TUENTRY_V(tu_lookup(pc));
    pc_last <= `TUENTRY_LAST(tu_lookup(pc));
end


//////////////////////////////// PS-AMC ////////////////////////////////////////
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

wire a = psamc_lookup(pc_last);
wire b = psamc_lookup(addr);
wire ab_comp = {`PSENTRY_V(a), `PSENTRY_V(b)}; // compare presence of a and b


//////////////////////////////// SP-AMC ////////////////////////////////////////
// bits | field
// 1    | valid
// 32   | tag (just use whole addr)
// 256  | 16 physical addresses
// -----|----------------------
// 289  | total
//
// 2 entries
reg [288:0]spamc[1:0];


////////////////////////////// stream predictor //////////////////////////////
// fifo queue of 4 entries
fifo #(2) sb0(/*TODO: ports*/);


//////////////////////////////// on tick ////////////////////////////////////
always @(posedge clk) begin
    if (v_in) begin
        // training
        if (pc_v && pc_last != addr) begin
            // Update mappings
            case(ab_comp)
                0 : begin
                    // TODO:neither a nor b in psamc
                    // psamc[A].sa = next_sa
                    // psamc[B].sa = psamc[A].sa + 1
                    // next_sa += 16

                    // spamc[psamc[A].sa] = {A, B}
                end
                1 : begin
                    // TODO:only b in psamc
                    // psamc[A].sa = next_sa
                    // next_sa += 16

                    // spamc[psamc[A].sa] = {A} // only A here

                    // psamc[B].counter--
                    // if (psamc[B].counter == 0) {
                    //     psamc[B].sa = psamc[A].sa + 1
                    //     // do not change SPAMC?
                    // }
                end
                2 : begin
                    // TODO:only a in psamc
                    // psamc[B].sa = psamc[A].sa + 1
                    // spamc[psamc[A].sa] = {A, B}
                end
                3 : begin
                    // TODO:both in psamc
                    if (b == a + 1) begin
                        // TODO:
                        // psamc[B].counter++
                    end else begin
                        // TODO:
                        // psamc[B].counter--
                        // if (psamc[B].counter == 0) {
                        //     psamc[B].sa = psamc[A].sa + 1
                        //     spamc[psamc[B].sa] = B
                        //     // Do not remove old mappings
                        // }
                    end
                end
            endcase
        end else if (!pc_v) begin
            // TODO:insert into TU
            // LRU?
            // tu[pc].last = addr
        end




        // TODO: prediction
        //if (b.valid) begin
        //    prefetch = prefetch_trigger(b.sa);
        //    prefetch_addr = spamc(prefetch);
        //end
    end
end

/////////////////////////// usefull functions ///////////////////////////////
function [32:0]tu_lookup;
    input [15:0]pc;

    tu_lookup = (`TU_PC(0) == pc && `TU_V(0)) ? tu[0] :
        (`TU_PC(1) == pc && `TU_V(1)) ? tu[1] :
        (`TU_PC(2) == pc && `TU_V(2)) ? tu[2] :
        (`TU_PC(3) == pc && `TU_V(3)) ? tu[3] :
        {1'h0, 31'hx};
endfunction

function [50:0]psamc_lookup;
    input [15:0]pa;

    // TODO
endmodule

function [48:0]spamc_lookup; // returns only the pa for the given sa
    input [31:0]sa;

    // TODO
endfunction
