`timescale 1ps/1ps

// A toy implementation of the ISB (Jain and Lin, MICRO13).
// See REPORT.txt

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

//TODO remove debug code
wire tu0m =  (`TU_V(0) && `TU_PC(0) == pc);
wire tu1m =  (`TU_V(1) && `TU_PC(1) == pc);
wire tu2m =  (`TU_V(2) && `TU_PC(2) == pc);
wire tu3m =  (`TU_V(3) && `TU_PC(3) == pc);

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

// update psamc
// - to simplify my design due to time constraints, only support 32 structural
// addresses. Normally, TLB syncing would mitigate this problem
//reg ps_update_v0 = 0;
//reg [15:0]ps_update_tag0;
//reg [31:0]ps_update_sa0;
//reg [1:0]ps_update_counter0;
//
//reg ps_update_v1 = 0;
//reg [15:0]ps_update_tag1;
//reg [31:0]ps_update_sa1;
//reg [1:0]ps_update_counter1;
//
//// TODO remove this always block, no longer needed
//always @(posedge clk) begin
//    if(ps_update_v0 && ps_update_sa0 < 32) begin
//        psamc[ps_update_idx(ps_update_tag0)] <= {1'h1, ps_update_tag0, ps_update_sa0, ps_update_counter0};
//        if (DEBUG) $display("ps[%d]\tv: %d\ttag: %x\tsa: %x\tctr: %d", ps_update_idx(ps_update_tag0), ps_update_v0, ps_update_tag0, ps_update_sa0, ps_update_counter0);
//    end
//    if(ps_update_v1 && ps_update_sa1 < 32) begin
//        psamc[ps_update_idx(ps_update_tag1)] <= {1'h1, ps_update_tag1, ps_update_sa1, ps_update_counter1};
//        if (DEBUG) $display("ps[%d]\tv: %d\ttag: %x\tsa: %x\tctr: %d", ps_update_idx(ps_update_tag1), ps_update_v1, ps_update_tag1, ps_update_sa1, ps_update_counter1);
//    end
//end

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
//reg sp_update_v0 = 0;
//reg [31:0]sp_update_tag0;
//reg [15:0]sp_update_addr0;
//
//reg sp_update_v1 = 0;
//reg [31:0]sp_update_tag1;
//reg [15:0]sp_update_addr1;
//
//// TODO remove this always block, no longer needed
//always @(posedge clk) begin
//    if (sp_update_v0 && sp_update_v1 && sp_update_idx(sp_update_tag0) == sp_update_idx(sp_update_tag1) && sp_update_tag0 < 32 && sp_update_tag1 < 32) begin
//            `SPENTRY_V(spamc[sp_update_idx(sp_update_tag0)]) <= 1'h1;
//            `SPENTRY_TAG(spamc[sp_update_idx(sp_update_tag0)]) <= sp_update_tag0;
//
//            `SPENTRY_PA(spamc[sp_update_idx(sp_update_tag0)], sp_update_tag0[1:0]) <= sp_update_addr0;
//            `SPENTRY_PA(spamc[sp_update_idx(sp_update_tag1)], sp_update_tag1[1:0]) <= sp_update_addr1;
//
//            if (DEBUG) $display("sp[%d]\tv: %d\ttag: %x\tpa: %x", sp_update_idx(sp_update_tag0), sp_update_v0, sp_update_tag0, sp_update_addr0);
//            if (DEBUG) $display("sp[%d]\tv: %d\ttag: %x\tpa: %x", sp_update_idx(sp_update_tag1), sp_update_v1, sp_update_tag1, sp_update_addr1);
//    end else begin
//        // Normal case
//        if (sp_update_v0 && sp_update_tag0 < 32) begin
//            `SPENTRY_V(spamc[sp_update_idx(sp_update_tag0)]) <= 1'h1;
//            `SPENTRY_TAG(spamc[sp_update_idx(sp_update_tag0)]) <= sp_update_tag0;
//            `SPENTRY_PA(spamc[sp_update_idx(sp_update_tag0)], sp_update_tag0[1:0]) <= sp_update_addr0;
//            if (DEBUG) $display("sp[%d]\tv: %d\ttag: %x\tpa: %x", sp_update_idx(sp_update_tag0), sp_update_v0, sp_update_tag0, sp_update_addr0);
//        end
//        if (sp_update_v1 && sp_update_tag1 < 32) begin
//            `SPENTRY_V(spamc[sp_update_idx(sp_update_tag1)]) <= 1'h1;
//            `SPENTRY_TAG(spamc[sp_update_idx(sp_update_tag1)]) <= sp_update_tag1;
//            `SPENTRY_PA(spamc[sp_update_idx(sp_update_tag1)], sp_update_tag1[1:0]) <= sp_update_addr1;
//            if (DEBUG) $display("sp[%d]\tv: %d\ttag: %x\tpa: %x", sp_update_idx(sp_update_tag1), sp_update_v1, sp_update_tag1, sp_update_addr1);
//        end
//    end
//end

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
                // TODO: make sure no updates to SA > 31
                0 : begin
                    // neither A nor B in psamc

                    // next_sa += 16
                    next_sa <= next_sa + 16;

                    // psamc[A].sa = next_sa
                    //ps_update_v0 <= 1; //TODO:remove debugging code
                    //ps_update_tag0 <= pc_last;
                    //ps_update_sa0 <= next_sa;
                    //ps_update_counter0 <= 3;

                    psamc[ps_update_idx(pc_last)] <= {1'h1, pc_last, next_sa, 2'h3};
                    if (DEBUG) $display("ps[%d]\tv: %d\ttag: %x\tsa: %x\tctr: %d", ps_update_idx(pc_last), 1, pc_last, next_sa, 3);

                    // psamc[B].sa = psamc[A].sa + 1
                    //ps_update_v1 <= 1; //TODO: remove debugging code
                    //ps_update_tag1 <= addr;
                    //ps_update_sa1 <= next_sa + 1;
                    //ps_update_counter1 <= 3;

                    psamc[ps_update_idx(addr)] <= {1'h1, addr, next_sa + 32'h1, 2'h3};
                    if (DEBUG) $display("ps[%d]\tv: %d\ttag: %x\tsa: %x\tctr: %d", ps_update_idx(addr), 1, addr, next_sa + 1, 3);

                    // spamc[psamc[A].sa] = {A, B}
                    //sp_update_v0 <= 1; //TODO remove debugging code
                    //sp_update_tag0 <= next_sa;
                    //sp_update_addr0 <= pc_last;
                    //sp_update_v1 <= 1;
                    //sp_update_tag1 <= next_sa + 1;
                    //sp_update_addr1 <= addr;

                    if (sp_update_idx(next_sa) == sp_update_idx(next_sa + 1) && next_sa < 32 && next_sa < 32) begin
                            `SPENTRY_V(spamc[sp_update_idx(next_sa)]) <= 1'h1;
                            `SPENTRY_TAG(spamc[sp_update_idx(next_sa)]) <= next_sa;

                            `SPENTRY_PA(spamc[sp_update_idx(next_sa)], next_sa[1:0]) <= pc_last;
                            `SPENTRY_PA(spamc[sp_update_idx(next_sa + 1)], next_sa[1:0] + 1) <= addr;

                            if (DEBUG) $display("sp[%d]\tv: %d\ttag: %x\tpa: %x", sp_update_idx(next_sa), 1, next_sa, pc_last);
                            if (DEBUG) $display("sp[%d]\tv: %d\ttag: %x\tpa: %x", sp_update_idx(next_sa + 1), 1, next_sa + 1, addr);
                    end else begin
                        // Normal case
                        if (1 && next_sa < 32) begin
                            `SPENTRY_V(spamc[sp_update_idx(next_sa)]) <= 1'h1;
                            `SPENTRY_TAG(spamc[sp_update_idx(next_sa)]) <= next_sa;
                            `SPENTRY_PA(spamc[sp_update_idx(next_sa)], next_sa[1:0]) <= pc_last;
                            if (DEBUG) $display("sp[%d]\tv: %d\ttag: %x\tpa: %x", sp_update_idx(next_sa), 1, next_sa, pc_last);
                        end
                        if (1 && next_sa + 1 < 32) begin
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
                    //ps_update_v0 <= 1; //TODO: remove debugging code
                    //ps_update_tag0 <= pc_last;
                    //ps_update_sa0 <= next_sa;
                    //ps_update_counter0 <= 3;

                    psamc[ps_update_idx(pc_last)] <= {1'h1, pc_last, next_sa, 2'h3};
                    if (DEBUG) $display("ps[%d]\tv: %d\ttag: %x\tsa: %x\tctr: %d", ps_update_idx(pc_last), 1, pc_last, next_sa, 3);

                    // spamc[psamc[A].sa] = {A} // only A here
                    //sp_update_v0 <= 1; //TODO: remove debugging code
                    //sp_update_tag0 <= next_sa;
                    //sp_update_addr0 <= pc_last;

                    // psamc[B].counter--
                    // if (psamc[B].counter == 0) {
                    //     psamc[B].sa = psamc[A].sa + 1
                    //     spamc[psamc[B].sa] = B
                    //     // Do not remove old sp mappings
                    // }
                    if ((`PSENTRY_CTR(b) - 1) == 0) begin
                        //ps_update_v1 <= 1;//TODO remove debugging code
                        //ps_update_tag1 <= addr;
                        //ps_update_sa1 <= next_sa + 1;
                        //ps_update_counter1 <= 3;

                        psamc[ps_update_idx(addr)] <= {1'h1, addr, next_sa + 32'h1, 2'h3};
                        if (DEBUG) $display("ps[%d]\tv: %d\ttag: %x\tsa: %x\tctr: %d", ps_update_idx(addr), 1, addr, next_sa + 1, 3);

                        //sp_update_v1 <= 1; // TODO: remove debugging code
                        //sp_update_tag1 <= next_sa + 1;
                        //sp_update_addr1 <= addr;

                        // update spamc[A,B]
                        if (sp_update_idx(next_sa) == sp_update_idx(next_sa + 1) && next_sa < 32 && next_sa + 1 < 32) begin
                                `SPENTRY_V(spamc[sp_update_idx(next_sa)]) <= 1'h1;
                                `SPENTRY_TAG(spamc[sp_update_idx(next_sa)]) <= next_sa;

                                `SPENTRY_PA(spamc[sp_update_idx(next_sa)], next_sa[1:0]) <= pc_last;
                                `SPENTRY_PA(spamc[sp_update_idx(next_sa + 1)], next_sa[1:0] + 1) <= addr;

                                if (DEBUG) $display("sp[%d]\tv: %d\ttag: %x\tpa: %x", sp_update_idx(next_sa), 1, next_sa, pc_last);
                                if (DEBUG) $display("sp[%d]\tv: %d\ttag: %x\tpa: %x", sp_update_idx(next_sa + 1), 1, next_sa + 1, addr);
                        end else begin
                            // Normal case
                            if (1 && next_sa < 32) begin
                                `SPENTRY_V(spamc[sp_update_idx(next_sa)]) <= 1'h1;
                                `SPENTRY_TAG(spamc[sp_update_idx(next_sa)]) <= next_sa;
                                `SPENTRY_PA(spamc[sp_update_idx(next_sa)], next_sa[1:0]) <= pc_last;
                                if (DEBUG) $display("sp[%d]\tv: %d\ttag: %x\tpa: %x", sp_update_idx(next_sa), 1, next_sa, pc_last);
                            end
                            if (1 && next_sa + 1 < 32) begin
                                `SPENTRY_V(spamc[sp_update_idx(next_sa + 1)]) <= 1'h1;
                                `SPENTRY_TAG(spamc[sp_update_idx(next_sa + 1)]) <= next_sa + 1;
                                `SPENTRY_PA(spamc[sp_update_idx(next_sa + 1)], next_sa[1:0] + 1) <= addr;
                                if (DEBUG) $display("sp[%d]\tv: %d\ttag: %x\tpa: %x", sp_update_idx(next_sa + 1), 1, next_sa + 1, addr);
                            end
                        end
                    end else begin
                        //ps_update_v1 <= 1;//TODO remove debugging code
                        //ps_update_tag1 <= addr;
                        //ps_update_sa1 <= `PSENTRY_SA(b);
                        //ps_update_counter1 <= `PSENTRY_CTR(b) - 1;

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
                    //ps_update_v1 <= 1; //TODO: remove debugging code
                    //ps_update_tag1 <= addr;
                    //ps_update_sa1 <= `PSENTRY_SA(a) + 1;
                    //ps_update_counter1 <= 3;

                    if(`PSENTRY_SA(a) + 1 < 32) begin
                        psamc[ps_update_idx(addr)] <= {1'h1, addr, `PSENTRY_SA(a) + 32'h1, 2'h3};
                        if (DEBUG) $display("ps[%d]\tv: %d\ttag: %x\tsa: %x\tctr: %d", ps_update_idx(addr), 1, addr, `PSENTRY_SA(a) + 1, 3);
                    end

                    // spamc[psamc[A].sa] = {A, B}
                    //sp_update_v1 <= 1; //TODO: remove debugging code
                    //sp_update_tag1 <= `PSENTRY_SA(a) + 1;
                    //sp_update_addr1 <= addr;

                    if (1 && `PSENTRY_SA(a) + 1 < 32) begin
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
                        //ps_update_v1 <= 1; //TODO remove debugging code
                        //ps_update_tag1 <= addr;
                        //ps_update_sa1 <= `PSENTRY_SA(b);
                        //ps_update_counter1 <= (`PSENTRY_CTR(b) == 3) ? 3 : `PSENTRY_CTR(b) + 1;

                        if(1 && `PSENTRY_SA(b) < 32) begin
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
                            //ps_update_v1 <= 1; //TODO: remove debugging code
                            //ps_update_tag1 <= addr;
                            //ps_update_sa1 <= `PSENTRY_SA(a) + 1;
                            //ps_update_counter1 <= 3;

                            if(1 && `PSENTRY_SA(a) + 1 < 32) begin
                                psamc[ps_update_idx(addr)] <= {1'h1, addr, `PSENTRY_SA(a) + 32'h1, 2'h3};
                                if (DEBUG) $display("ps[%d]\tv: %d\ttag: %x\tsa: %x\tctr: %d", ps_update_idx(addr), 1, addr, `PSENTRY_SA(a) + 1, 3);
                            end

                            //sp_update_v1 <= 1;//TODO remove debugging code
                            //sp_update_tag1 <= `PSENTRY_SA(a) + 1;
                            //sp_update_addr1 <= addr;

                            if (1 && `PSENTRY_SA(a) + 1 < 32) begin
                                `SPENTRY_V(spamc[sp_update_idx(`PSENTRY_SA(a) + 1)]) <= 1'h1;
                                `SPENTRY_TAG(spamc[sp_update_idx(`PSENTRY_SA(a) + 1)]) <= `PSENTRY_SA(a) + 1;
                                `SPENTRY_PA(spamc[sp_update_idx(`PSENTRY_SA(a) + 1)], `PSENTRY_SA(a)[1:0] + 1) <= addr;
                                if (DEBUG) $display("sp[%d]\tv: %d\ttag: %x\tpa: %x", sp_update_idx(`PSENTRY_SA(a) + 1), 1, `PSENTRY_SA(a) + 1, addr);
                            end
                        end else begin
                            //ps_update_v1 <= 1;//TODO: remove debug code
                            //ps_update_tag1 <= addr;
                            //ps_update_sa1 <= `PSENTRY_SA(b);
                            //ps_update_counter1 <= `PSENTRY_CTR(b) - 1;

                            if(1 && `PSENTRY_SA(b) < 32) begin
                                psamc[ps_update_idx(addr)] <= {1'h1, addr, `PSENTRY_SA(b), `PSENTRY_CTR(b) - 2'h1};
                                if (DEBUG) $display("ps[%d]\tv: %d\ttag: %x\tsa: %x\tctr: %d", ps_update_idx(addr), 1, addr, `PSENTRY_SA(b), `PSENTRY_CTR(b) - 1);
                            end
                        end
                    end
                end
            endcase
        end else if (!pc_v) begin
            // turn off appropriate insert/update flags
            //ps_update_v0 <= 0;
            //ps_update_v1 <= 0;

            //sp_update_v0 <= 0;
            //sp_update_v1 <= 0;
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
    end else begin
        // turn insert/update all flags off
        //ps_update_v0 <= 0;
        //ps_update_v1 <= 0;

        //sp_update_v0 <= 0;
        //sp_update_v1 <= 0;
    end
end

/////////////////////////// usefull functions ///////////////////////////////
// lookup pc in tu
function [2:0]tu_lookup_idx;
    input [15:0]pc;

    tu_lookup_idx = (`TU_PC(0) == pc && `TU_V(0)) ? 0 :
        (`TU_PC(1) == pc && `TU_V(1)) ? 1 :
        (`TU_PC(2) == pc && `TU_V(2)) ? 2 :
        (`TU_PC(3) == pc && `TU_V(3)) ? 3 :
        4;
endfunction

// TODO remove debugging code
wire tuv0 = `TU_V(3);
wire [15:0]tupc0 = `TU_PC(3);
wire [15:0]tulast0 = `TU_LAST(3);

wire psv10 = `PSENTRY_V(psamc[16]);
wire [15:0]pstag10 = `PSENTRY_TAG(psamc[16]);
wire [31:0]pssa10 = `PSENTRY_SA(psamc[16]);
wire [1:0]psctr10 = `PSENTRY_CTR(psamc[16]);

function [32:0]tu_lookup;
    input [15:0]pc;

    case(tu_lookup_idx(pc))
        0,1,2,3 : tu_lookup = tu[tu_lookup_idx(pc)];
        4 : tu_lookup = {1'h0, 31'hx};
    endcase
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


// lookup sa in spamc
function [48:0]spamc_lookup;
    input [31:0]sa;

    reg [96:0]lookup;

    begin
        lookup = spamc[sa[4:2]];
        spamc_lookup = `SPENTRY_PA(lookup, sa && 2'h3);
    end
endfunction


// returns the tu index to update for this pc
// check if it is already in the tu
function [1:0]tu_insert_idx;
    input [15:0]pc;

    reg lookup;

    begin
        lookup = tu_lookup_v(pc);
        tu_insert_idx = lookup ? tu_lookup_idx(pc) : tu_lru;
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
