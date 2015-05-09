`timescale 1ps/1ps

// A toy implementation of the ISB (Jain and Lin, MICRO14).

// Specs
// -----
// Max steam length: 16 addrs
// PS-AMC size: 32 entries mapping 1 addr each
// SP-AMC size: 8 entries mapping 4 addrs each
// Training unit: 4 entries
// Steam predictor: 1 stream buffer with a queue of 4 entries, degree 1

// Lots of macros:

`define TUENTRY_V(entry)    entry[32]
`define TUENTRY_PC(entry)   entry[31:16]
`define TUENTRY_LAST(entry) entry[15:0]

`define PSENTRY_V(entry)    entry[50]
`define PSENTRY_TAG(entry)  entry[49:34]
`define PSENTRY_SA(entry)   entry[33:2]
`define PSENTRY_CTR(entry)  entry[1:0]

`define SPENTRY_V(entry)    entry[96]
`define SPENTRY_TAG(entry)  entry[95:64]
`define SPENTRY_PA(entry, i)  entry[63 - (16*i):48 - (16*i)]

`define TU_V(tu_num)    `TUENTRY_V(tu[tu_num])
`define TU_PC(tu_num)   `TUENTRY_PC(tu[tu_num])
`define TU_LAST(tu_num) `TUENTRY_LAST(tu[tu_num])

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
reg tu_insert_v = 0;
reg tu_insert_pc;
reg tu_insert_last;

always @(posedge clk) begin
    if(tu_insert_v) begin
        tu[tu_insert_idx(tu_insert_pc)] <= {tu_insert_v, tu_insert_pc, tu_insert_last};
    end
end

// lookup pc in the TU
reg pc_v;
reg [15:0]pc_last;

always @(pc) begin
    pc_v <= tu_lookup_v(pc);
    pc_last <= tu_lookup_last(pc);
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

wire [50:0]a = psamc_lookup(pc_last);
wire [50:0]b = psamc_lookup(addr);
wire [1:0]ab_comp = {`PSENTRY_V(a), `PSENTRY_V(b)}; // compare presence of a and b

// update psamc
// - to simplify my design due to time constraints, only support 32 structural
// addresses. Normally, TLB syncing would mitigate this problem
reg ps_update_v0 = 0;
reg [15:0]ps_update_tag0;
reg [31:0]ps_update_sa0;
reg [1:0]ps_update_counter0;

reg ps_update_v1 = 0;
reg [15:0]ps_update_tag1;
reg [31:0]ps_update_sa1;
reg [1:0]ps_update_counter1;

always @(posedge clk) begin
    if(ps_update_v0 && ps_update_sa0 < 32) begin
        psamc[ps_update_idx(ps_update_tag0)] <=
            {1'h1, ps_update_tag0, ps_update_sa0, ps_update_counter0};
    end
    if(ps_update_v1 && ps_update_sa1 < 32) begin
        psamc[ps_update_idx(ps_update_tag1)] <=
            {1'h1, ps_update_tag1, ps_update_sa1, ps_update_counter1};
    end
end

//////////////////////////////// SP-AMC ////////////////////////////////////////
// bits | field
// 1    | valid
// 32   | tag (just use whole addr)
// 64   | 4 physical addresses
// -----|----------------------
// 97   | total
//
// 8 entries
reg [96:0]spamc[1:0];

// udpate spamc
// - to simplify my design due to time constraints, only support 32 structural
// addresses. Normally, TLB syncing would mitigate this problem
reg sp_update_v0 = 0;
reg [31:0]sp_update_tag0;
reg [15:0]sp_update_addr0;

reg sp_update_v1 = 0;
reg [31:0]sp_update_tag1;
reg [15:0]sp_update_addr1;

always @(posedge clk) begin
    // TODO: MUST BE ABLE TO EDIT 2 ENTRIES AT ONCE!
    // OR TWO MAPPINGS IN THE SAME ENTRY!
    // OR ONE MAPPING WITHOUT MESSING UP OTHERS WITH THE SAME TAG
end

////////////////////////////// stream predictor //////////////////////////////
//TODO: put stuff here...
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
                    // neither A nor B in psamc

                    // next_sa += 16
                    next_sa <= next_sa + 16;

                    // psamc[A].sa = next_sa
                    ps_update_v0 <= 1;
                    ps_update_tag0 <= pc_last;
                    ps_update_sa0 <= next_sa;
                    ps_update_counter0 <= 3;

                    // psamc[B].sa = psamc[A].sa + 1
                    ps_update_v0 <= 1;
                    ps_update_tag0 <= addr;
                    ps_update_sa0 <= next_sa + 1;
                    ps_update_counter0 <= 3;

                    // spamc[psamc[A].sa] = {A, B}
                    sp_update_v0 <= 1;
                    sp_update_tag0 <= next_sa;
                    sp_update_addr0 <= pc_last;

                    sp_update_v1 <= 1;
                    sp_update_tag1 <= next_sa + 1;
                    sp_update_addr1 <= addr;
                end
                1 : begin
                    // only b in psamc

                    // next_sa += 16
                    next_sa <= next_sa + 16;

                    // psamc[A].sa = next_sa
                    ps_update_v0 <= 1;
                    ps_update_tag0 <= pc_last;
                    ps_update_sa0 <= next_sa;
                    ps_update_counter0 <= 3;

                    // spamc[psamc[A].sa] = {A} // only A here
                    sp_update_v0 <= 1;
                    sp_update_tag0 <= next_sa;
                    sp_update_addr0 <= pc_last;

                    // psamc[B].counter--
                    // if (psamc[B].counter == 0) {
                    //     psamc[B].sa = psamc[A].sa + 1
                    //     spamc[psamc[B].sa] = B
                    //     // Do not remove old sp mappings
                    // }
                    if ((`PSENTRY_CTR(b) - 1) == 0) begin
                        ps_update_v1 <= 1;
                        ps_update_tag1 <= addr;
                        ps_update_sa1 <= `PSENTRY_SA(a) + 1;
                        ps_update_counter1 <= 3;

                        sp_update_v1 <= 1;
                        sp_update_tag1 <= `PSENTRY_SA(a) + 1;
                        sp_update_addr1 <= addr;
                    end else begin
                        ps_update_v1 <= 1;
                        ps_update_tag1 <= addr;
                        ps_update_sa1 <= `PSENTRY_SA(b);
                        ps_update_counter1 <= `PSENTRY_CTR(b) - 1;
                    end
                end
                2 : begin
                    // only a in psamc

                    // psamc[B].sa = psamc[A].sa + 1
                    ps_update_v1 <= 1;
                    ps_update_tag1 <= addr;
                    ps_update_sa1 <= `PSENTRY_SA(a) + 1;
                    ps_update_counter1 <= 3;

                    // spamc[psamc[A].sa] = {A, B}
                    sp_update_v1 <= 1;
                    sp_update_tag1 <= `PSENTRY_SA(a);
                    sp_update_addr1 <= addr;
                end
                3 : begin
                    // both in psamc
                    if (b == a + 1) begin
                        // psamc[B].counter++
                        ps_update_v1 <= 1;
                        ps_update_tag1 <= addr;
                        ps_update_sa1 <= `PSENTRY_SA(b);
                        ps_update_counter1 <= (`PSENTRY_CTR(b) == 3) ? 3 : `PSENTRY_CTR(b) + 1;
                    end else begin
                        // psamc[B].counter--
                        // if (psamc[B].counter == 0) {
                        //     psamc[B].sa = psamc[A].sa + 1
                        //     spamc[psamc[B].sa] = B
                        //     // Do not remove old mappings
                        // }
                        if ((`PSENTRY_CTR(b) - 1) == 0) begin
                            ps_update_v1 <= 1;
                            ps_update_tag1 <= addr;
                            ps_update_sa1 <= `PSENTRY_SA(a) + 1;
                            ps_update_counter1 <= 3;

                            sp_update_v1 <= 1;
                            sp_update_tag1 <= `PSENTRY_SA(a) + 1;
                            sp_update_addr1 <= addr;
                        end else begin
                            ps_update_v1 <= 1;
                            ps_update_tag1 <= addr;
                            ps_update_sa1 <= `PSENTRY_SA(b);
                            ps_update_counter1 <= `PSENTRY_CTR(b) - 1;
                        end
                    end
                end
            endcase
        end else if (!pc_v) begin
            // turn off appropriate insert/update flags
            ps_update_v0 <= 0;
            ps_update_v1 <= 0;

            sp_update_v0 <= 0;
            sp_update_v1 <= 0;
        end

        // update TU
        // tu[pc].last = addr
        tu_insert_v <= 1;
        tu_insert_pc <= pc;
        tu_insert_last <= addr;


        // TODO: prediction
        //if (b.valid) begin
        //    prefetch = prefetch_trigger(b.sa);
        //    prefetch_addr = spamc(prefetch);
        //end
    end else begin
        // turn insert/update all flags off
        ps_update_v0 <= 0;
        ps_update_v1 <= 0;

        sp_update_v0 <= 0;
        sp_update_v1 <= 0;

        tu_insert_v <= 0;
    end
end

/////////////////////////// usefull functions ///////////////////////////////
// lookup pc in tu
function [32:0]tu_lookup;
    input [15:0]pc;

    tu_lookup = (`TU_PC(0) == pc && `TU_V(0)) ? tu[0] :
        (`TU_PC(1) == pc && `TU_V(1)) ? tu[1] :
        (`TU_PC(2) == pc && `TU_V(2)) ? tu[2] :
        (`TU_PC(3) == pc && `TU_V(3)) ? tu[3] :
        {1'h0, 31'hx};
endfunction

// because verilog:
function tu_lookup_v;
    input [15:0]pc;

    reg [32:0]lookup;

    begin
        lookup = tu_lookup(pc);
        tu_lookup_v = `TUENTRY_V(lookup);
    end
endfunction

function [15:0]tu_lookup_last;
    input [15:0]pc;

    reg [32:0]lookup;

    begin
        lookup = tu_lookup(pc);
        tu_lookup_last = `TUENTRY_LAST(lookup);
    end
endfunction


// lookup pa in psamc
function [50:0]psamc_lookup;
    input [15:0]pa;

    reg [50:0]lookup;

    begin
        lookup = psamc[pa[4:0]];
        psamc_lookup = (`PSENTRY_V(lookup) && `PSENTRY_TAG(lookup) == pa) ? lookup : {1'h0, 50'hx};
    end
endfunction


// lookup sa in spamc
function [48:0]spamc_lookup; // returns only the pa for the given sa
    input [31:0]sa;

    spamc_lookup = 0;// TODO
endfunction


// returns the tu index to update for this pc
function [1:0]tu_insert_idx;
    input [15:0]pc;
    // LRU??
    // check if it is already in the cache
    tu_insert_idx = 0; // TODO
endfunction


// returns the psamc index to update for this pa
function [4:0]ps_update_idx;
    input [15:0]pa;

    ps_update_idx = pa[4:0];
endfunction


// returns the spamc index to update for this sa
function [2:0]sp_update_idx;
    input [32:0]sa;

    sp_update_idx = sa[2:0];
endfunction

endmodule
