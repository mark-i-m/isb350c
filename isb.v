`timescale 1ps/1ps

// A toy implementation of the ISB (Jain and Lin, MICRO13).
// See REPORT.txt

// Specs
// -----
// Max steam length: 16 addrs //TODO
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
`define SPENTRY_PA(entry, i)  entry[63 - (16*i) -: 16]

`define TU_V(tu_num)    `TUENTRY_V(tu[tu_num])
`define TU_PC(tu_num)   `TUENTRY_PC(tu[tu_num])
`define TU_LAST(tu_num) `TUENTRY_LAST(tu[tu_num])

`define PS_LOOKUP(pa) ((`PSENTRY_V(psamc[pa[4:0]]) && `PSENTRY_TAG(psamc[pa[4:0]]) == pa) ? psamc[pa[4:0]] : {1'h0, 50'hx})

`define TU_LOOKUP_IDX(ip) ((`TU_V(0) && `TU_PC(0) == ip) ? 0 : (`TU_V(1) && `TU_PC(1) == ip) ? 1 : (`TU_V(2) && `TU_PC(2) == ip) ? 2 : (`TU_V(3) && `TU_PC(3) == ip) ? 3 : 4)

`define TU_LOOKUP(ip) ((`TU_V(0) && `TU_PC(0) == ip) ? tu[0] : (`TU_V(1) && `TU_PC(1) == ip) ? tu[1] : (`TU_V(2) && `TU_PC(2) == ip) ? tu[2] : (`TU_V(3) && `TU_PC(3) == ip) ? tu[3] : 0)

module isb(input clk,
    input v_in, input [15:0]pc, input [15:0]addr,
    output prefetch_v, output [15:0]prefetch_addr //TODO: hook these up
);

// Debugging flag?
parameter DEBUG = 0;

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

initial begin
    tu[0] <= 0;
    tu[1] <= 0;
    tu[2] <= 0;
    tu[3] <= 0;
end

// update TU
wire [1:0]tu_used = pc_v ? `TU_LOOKUP_IDX(pc) : tu_lru;
wire [1:0]tu_lru;
lru lru0(clk, v_in, tu_used, tu_lru);

// lookup pc in the TU
wire [32:0]pc_tu_lookup = `TU_LOOKUP(pc);
wire pc_v = v_in ? `TUENTRY_V(pc_tu_lookup) : 0;
wire [15:0]pc_last = `TUENTRY_LAST(pc_tu_lookup);

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

integer psamc_init_i;
initial begin
    for (psamc_init_i = 0; psamc_init_i < 32; psamc_init_i = psamc_init_i + 1) begin
        `PSENTRY_V(psamc[psamc_init_i]) <= 0;
    end
end

wire [50:0]a = `PS_LOOKUP(pc_last);
wire [50:0]b = `PS_LOOKUP(addr);

wire [1:0]ab_comp = {pc_v ? `PSENTRY_V(a) : 0, `PSENTRY_V(b)}; // compare presence of a and b


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
                    // psamc[B].sa = psamc[A].sa + 1
                    if (next_sa < 32) begin
                        psamc[ps_update_idx(pc_last)] <= {1'h1, pc_last, next_sa, 2'h3};
                        if (DEBUG) $display("ps[%d]\tv: %d\ttag: %x\tsa: %x\tctr: %d", ps_update_idx(pc_last), 1, pc_last, next_sa, 3);

                        psamc[ps_update_idx(addr)] <= {1'h1, addr, next_sa + 32'h1, 2'h3};
                        if (DEBUG) $display("ps[%d]\tv: %d\ttag: %x\tsa: %x\tctr: %d", ps_update_idx(addr), 1, addr, next_sa + 1, 3);
                    end

                    // spamc[psamc[A].sa] = {A, B}
                    if (sp_update_idx(next_sa) == sp_update_idx(next_sa + 1) && next_sa < 32) begin
                            `SPENTRY_V(spamc[sp_update_idx(next_sa)]) <= 1'h1;
                            `SPENTRY_TAG(spamc[sp_update_idx(next_sa)]) <= next_sa;

                            `SPENTRY_PA(spamc[sp_update_idx(next_sa)], next_sa[1:0]) <= pc_last;
                            `SPENTRY_PA(spamc[sp_update_idx(next_sa + 1)], next_sa[1:0] + 1) <= addr;

                            if (DEBUG) $display("sp[%d]\tv: %d\ttag: %x\tpa: %x", sp_update_idx(next_sa), 1, next_sa, pc_last);
                            if (DEBUG) $display("sp[%d]\tv: %d\ttag: %x\tpa: %x", sp_update_idx(next_sa + 1), 1, next_sa + 1, addr);
                    end else begin
                        // Normal case
                        if (next_sa < 32) begin
                            `SPENTRY_V(spamc[sp_update_idx(next_sa)]) <= 1'h1;
                            `SPENTRY_TAG(spamc[sp_update_idx(next_sa)]) <= next_sa;
                            `SPENTRY_PA(spamc[sp_update_idx(next_sa)], next_sa[1:0]) <= pc_last;
                            if (DEBUG) $display("sp[%d]\tv: %d\ttag: %x\tpa: %x", sp_update_idx(next_sa), 1, next_sa, pc_last);

                            `SPENTRY_V(spamc[sp_update_idx(next_sa + 1)]) <= 1'h1;
                            `SPENTRY_TAG(spamc[sp_update_idx(next_sa + 1)]) <= next_sa + 1;
                            `SPENTRY_PA(spamc[sp_update_idx(next_sa + 1)], next_sa[1:0] + 1) <= addr;
                            if (DEBUG) $display("sp[%d]\tv: %d\ttag: %x\tpa: %x", sp_update_idx(next_sa + 1), 1, next_sa + 1, addr);
                        end
                    end
                end
                1 : begin
                    // only b in psamc

                    // next_sa += 16
                    next_sa <= next_sa + 16;

                    // psamc[A].sa = next_sa
                    if (next_sa < 32) begin
                        psamc[ps_update_idx(pc_last)] <= {1'h1, pc_last, next_sa, 2'h3};
                        if (DEBUG) $display("ps[%d]\tv: %d\ttag: %x\tsa: %x\tctr: %d", ps_update_idx(pc_last), 1, pc_last, next_sa, 3);
                    end

                    // spamc[psamc[A].sa] = {A} // below

                    // psamc[B].counter--
                    // if (psamc[B].counter == 0) {
                    //     psamc[B].sa = psamc[A].sa + 1
                    //     spamc[psamc[B].sa] = B
                    //     // Do not remove old sp mappings
                    // }
                    if ((`PSENTRY_CTR(b) - 1) == 0) begin
                        if (next_sa < 32) begin
                            psamc[ps_update_idx(addr)] <= {1'h1, addr, next_sa + 32'h1, 2'h3};
                            if (DEBUG) $display("ps[%d]\tv: %d\ttag: %x\tsa: %x\tctr: %d", ps_update_idx(addr), 1, addr, next_sa + 1, 3);
                        end

                        // update spamc[A,B]
                        if (sp_update_idx(next_sa) == sp_update_idx(next_sa + 1) && next_sa < 32) begin
                                `SPENTRY_V(spamc[sp_update_idx(next_sa)]) <= 1'h1;
                                `SPENTRY_TAG(spamc[sp_update_idx(next_sa)]) <= next_sa;

                                `SPENTRY_PA(spamc[sp_update_idx(next_sa)], next_sa[1:0]) <= pc_last;
                                `SPENTRY_PA(spamc[sp_update_idx(next_sa + 1)], next_sa[1:0] + 1) <= addr;

                                if (DEBUG) $display("sp[%d]\tv: %d\ttag: %x\tpa: %x", sp_update_idx(next_sa), 1, next_sa, pc_last);
                                if (DEBUG) $display("sp[%d]\tv: %d\ttag: %x\tpa: %x", sp_update_idx(next_sa + 1), 1, next_sa + 1, addr);
                        end else begin
                            // Normal case
                            if (next_sa < 32) begin
                                `SPENTRY_V(spamc[sp_update_idx(next_sa)]) <= 1'h1;
                                `SPENTRY_TAG(spamc[sp_update_idx(next_sa)]) <= next_sa;
                                `SPENTRY_PA(spamc[sp_update_idx(next_sa)], next_sa[1:0]) <= pc_last;
                                if (DEBUG) $display("sp[%d]\tv: %d\ttag: %x\tpa: %x", sp_update_idx(next_sa), 1, next_sa, pc_last);
                            end
                            if (next_sa + 1 < 32) begin
                                `SPENTRY_V(spamc[sp_update_idx(next_sa + 1)]) <= 1'h1;
                                `SPENTRY_TAG(spamc[sp_update_idx(next_sa + 1)]) <= next_sa + 1;
                                `SPENTRY_PA(spamc[sp_update_idx(next_sa + 1)], next_sa[1:0] + 1) <= addr;
                                if (DEBUG) $display("sp[%d]\tv: %d\ttag: %x\tpa: %x", sp_update_idx(next_sa + 1), 1, next_sa + 1, addr);
                            end
                        end
                    end else begin
                        psamc[ps_update_idx(addr)] <= {1'h1, addr, `PSENTRY_SA(b), `PSENTRY_CTR(b) - 2'h1};
                        if (DEBUG) $display("ps[%d]\tv: %d\ttag: %x\tsa: %x\tctr: %d", ps_update_idx(addr), 1, addr, `PSENTRY_SA(b), `PSENTRY_CTR(b) - 1);

                        // update spamc[A] only
                        if (next_sa < 32) begin
                            `SPENTRY_V(spamc[sp_update_idx(next_sa)]) <= 1'h1;
                            `SPENTRY_TAG(spamc[sp_update_idx(next_sa)]) <= next_sa;
                            `SPENTRY_PA(spamc[sp_update_idx(next_sa)], next_sa[1:0]) <= pc_last;
                            if (DEBUG) $display("sp[%d]\tv: %d\ttag: %x\tpa: %x", sp_update_idx(next_sa), 1, next_sa, pc_last);
                        end
                    end
                end
                2 : begin
                    // only a in psamc

                    // psamc[B].sa = psamc[A].sa + 1
                    if(`PSENTRY_SA(a) + 1 < 32) begin
                        psamc[ps_update_idx(addr)] <= {1'h1, addr, `PSENTRY_SA(a) + 32'h1, 2'h3};
                        if (DEBUG) $display("ps[%d]\tv: %d\ttag: %x\tsa: %x\tctr: %d", ps_update_idx(addr), 1, addr, `PSENTRY_SA(a) + 1, 3);
                    end

                    // spamc[psamc[A].sa] = {A, B}
                    if (`PSENTRY_SA(a) + 1 < 32) begin
                        `SPENTRY_V(spamc[sp_update_idx(`PSENTRY_SA(a) + 1)]) <= 1'h1;
                        `SPENTRY_TAG(spamc[sp_update_idx(`PSENTRY_SA(a) + 1)]) <= `PSENTRY_SA(a) + 1;
                        `SPENTRY_PA(spamc[sp_update_idx(`PSENTRY_SA(a) + 1)], `PSENTRY_SA(a)[1:0] + 1) <= addr;
                        if (DEBUG) $display("sp[%d]\tv: %d\ttag: %x\tpa: %x", sp_update_idx(`PSENTRY_SA(a) + 1), 1, `PSENTRY_SA(a) + 1, addr);
                    end

                end
                3 : begin
                    // both in psamc
                    if (b == a + 1) begin
                        // psamc[B].counter++
                        if(`PSENTRY_SA(b) < 32) begin
                            psamc[ps_update_idx(addr)] <= {1'h1, addr, `PSENTRY_SA(b), (`PSENTRY_CTR(b) == 3) ? 3 : `PSENTRY_CTR(b) + 1};
                            if (DEBUG) $display("ps[%d]\tv: %d\ttag: %x\tsa: %x\tctr: %d", ps_update_idx(addr), 1, addr, `PSENTRY_SA(b), (`PSENTRY_CTR(b) == 3) ? 3 : `PSENTRY_CTR(b) + 1);
                        end
                    end else begin
                        // psamc[B].counter--
                        // if (psamc[B].counter == 0) {
                        //     psamc[B].sa = psamc[A].sa + 1
                        //     spamc[psamc[B].sa] = B
                        //     // Do not remove old mappings
                        // }
                        if ((`PSENTRY_CTR(b) - 1) == 0) begin
                            if(`PSENTRY_SA(a) + 1 < 32) begin
                                psamc[ps_update_idx(addr)] <= {1'h1, addr, `PSENTRY_SA(a) + 32'h1, 2'h3};
                                if (DEBUG) $display("ps[%d]\tv: %d\ttag: %x\tsa: %x\tctr: %d", ps_update_idx(addr), 1, addr, `PSENTRY_SA(a) + 1, 3);
                            end

                            if (`PSENTRY_SA(a) + 1 < 32) begin
                                `SPENTRY_V(spamc[sp_update_idx(`PSENTRY_SA(a) + 1)]) <= 1'h1;
                                `SPENTRY_TAG(spamc[sp_update_idx(`PSENTRY_SA(a) + 1)]) <= `PSENTRY_SA(a) + 1;
                                `SPENTRY_PA(spamc[sp_update_idx(`PSENTRY_SA(a) + 1)], `PSENTRY_SA(a)[1:0] + 1) <= addr;
                                if (DEBUG) $display("sp[%d]\tv: %d\ttag: %x\tpa: %x", sp_update_idx(`PSENTRY_SA(a) + 1), 1, `PSENTRY_SA(a) + 1, addr);
                            end
                        end else begin
                            if(`PSENTRY_SA(b) < 32) begin
                                psamc[ps_update_idx(addr)] <= {1'h1, addr, `PSENTRY_SA(b), `PSENTRY_CTR(b) - 2'h1};
                                if (DEBUG) $display("ps[%d]\tv: %d\ttag: %x\tsa: %x\tctr: %d", ps_update_idx(addr), 1, addr, `PSENTRY_SA(b), `PSENTRY_CTR(b) - 1);
                            end
                        end
                    end
                end
            endcase
        end

        // update TU
        // tu[pc].last = addr
        tu[tu_insert_idx(pc)] <= {1'h1, pc, addr};
        if (DEBUG) $display("tu[%d]\tv: %d\tpc: %x\tlast: %x", tu_insert_idx(pc), 1'h1, pc, addr);

        // TODO: prediction
        //if (b.valid) begin
        //    prefetch = prefetch_trigger(b.sa);
        //    prefetch_addr = spamc(prefetch);
        //end
    end
end

/////////////////////////// usefull functions ///////////////////////////////

// returns the tu index to update for this pc
// check if it is already in the tu
function [1:0]tu_insert_idx;
    input [15:0]pc;

    reg [32:0]lookup;

    begin
        lookup = `TU_LOOKUP(pc);
        tu_insert_idx = `TUENTRY_V(lookup) ? `TU_LOOKUP_IDX(pc) : tu_lru;
    end
endfunction

// returns the psamc index to update for this pa
function [4:0]ps_update_idx;
    input [15:0]pa;

    ps_update_idx = pa[4:0];
endfunction

// returns the spamc index to update for this sa
function [2:0]sp_update_idx;
    input [32:0]sa;

    sp_update_idx = sa[4:2];
endfunction

endmodule
