`timescale 1ps/1ps

// Simple Tomasulo processor
//
// 2 FUs:
//  * FXU
//  * LD unit
//
// Each one has 4 RSs and its own lane in the CDB


// Lots of MACROS to make Verilog more likeable. Imagine macros making
// a language better!

// Opcodes
`define MOV 0
`define ADD 1
`define JMP 2
`define HLT 3
`define LD  4
`define LDR 5
`define JEQ 6

// Bit fields
`define REG_BUSY(i) regs[i][22]
`define REG_SRC(i)  regs[i][21:16]
`define REG_VAL(i)  regs[i][15:0]

`define RS_PC(rs_num) rs[rs_num][67:52]
`define RS_ISSUED(rs_num) rs[rs_num][51]
`define RS_BUSY(rs_num) rs[rs_num][50]
`define RS_OP(rs_num) rs[rs_num][49:46]
`define RS_READY(rs_num, which) (!which ? rs[rs_num][45] : rs[rs_num][44])
`define RS_SRC(rs_num, which) (!which ? rs[rs_num][43:38] : rs[rs_num][37:32])
`define RS_VAL(rs_num, which) (!which ? rs[rs_num][31:16] : rs[rs_num][15:0])

`define CDB_VALID(cdb_num)  cdb[cdb_num][26]
`define CDB_RS(cdb_num)     cdb[cdb_num][25:20]
`define CDB_OP(cdb_num)     cdb[cdb_num][19:16]
`define CDB_DATA(cdb_num)   cdb[cdb_num][15:0]

`define CDB_SAT(reg_num)    ((`CDB_VALID(0) && `CDB_RS(0) == `REG_SRC(reg_num)) || (`CDB_VALID(1) && `CDB_RS(1) == `REG_SRC(reg_num)))
`define CDB_SAT_NUM(reg_num)    ((`CDB_VALID(0) && `CDB_RS(0) == `REG_SRC(reg_num)) ? 0 : (`CDB_VALID(1) && `CDB_RS(1) == `REG_SRC(reg_num)) ? 1 : 1'hx)
`define CDB_VAL(reg_num)    ((`CDB_VALID(0) && `CDB_RS(0) == `REG_SRC(reg_num)) ? `CDB_DATA(0) : (`CDB_VALID(1) && `CDB_RS(1) == `REG_SRC(reg_num)) ? `CDB_DATA(1) : 16'hxxxx)

// Parameters
`define NUM_REGS (1<<`REGS_WIDTH)
`define REGS_WIDTH 4

`define NUM_RS (1<<`RS_WIDTH)
`define RS_WIDTH 3 // 2 ** RS_WIDTH = NUM_RS

`define NUM_CDBS (1<<`CDBS_WIDTH)
`define CDBS_WIDTH 1

module main();

    // debugging
    initial begin
        $dumpfile("cpu.vcd");
        $dumpvars(4,main);
    end

    // clock
    wire clk;
    clock c0(clk);

    // counter
    counter ctr(stop_ctr, clk, ib_pop,);
    reg stop_ctr = 0;

    // wait until all regs are written back before halting
    reg regs_done = 0;
    integer regs_halted_counter;
    always @(posedge clk) begin
        regs_done = 1;
        for (regs_halted_counter = 0; regs_halted_counter < `NUM_REGS; regs_halted_counter = regs_halted_counter + 1) begin
            regs_done = regs_done && !`REG_BUSY(regs_halted_counter);
        end
    end

    // simulation: print regs before halting
    always @(posedge clk) begin
        if (is_halted && regs_done && !stop_ctr) begin
            $display("#0:%x",`REG_VAL(0));
            $display("#1:%x",`REG_VAL(1));
            $display("#2:%x",`REG_VAL(2));
            $display("#3:%x",`REG_VAL(3));
            $display("#4:%x",`REG_VAL(4));
            $display("#5:%x",`REG_VAL(5));
            $display("#6:%x",`REG_VAL(6));
            $display("#7:%x",`REG_VAL(7));
            $display("#8:%x",`REG_VAL(8));
            $display("#9:%x",`REG_VAL(9));
            $display("#10:%x",`REG_VAL(10));
            $display("#11:%x",`REG_VAL(11));
            $display("#12:%x",`REG_VAL(12));
            $display("#13:%x",`REG_VAL(13));
            $display("#14:%x",`REG_VAL(14));
            $display("#15:%x",`REG_VAL(15));
            stop_ctr = 1;
        end
    end

    // registers
    // bits field in order
    // busy 1
    // src  6
    // val  16
    reg [22:0]regs[`NUM_REGS-1:0];

    // Init all registers to not busy
    integer reg_init_counter;
    initial begin
        for (reg_init_counter = 0; reg_init_counter < `NUM_REGS; reg_init_counter = reg_init_counter + 1) begin
            `REG_BUSY(reg_init_counter) <= 0;
        end
    end

    // Update every cycle
    integer regs_update_counter;
    always @(posedge clk) begin
        for (regs_update_counter = 0; regs_update_counter < `NUM_REGS; regs_update_counter = regs_update_counter + 1) begin
            // if this reg is satisfied by the CDB, write the result back
            if (`CDB_SAT(regs_update_counter) && !(rt_v && rt == regs_update_counter)) begin
                regs[regs_update_counter][22] <= 0;
                regs[regs_update_counter][21:16] <= 6'hxx;
                regs[regs_update_counter][15:0] <= `CDB_VAL(regs_update_counter);
            end
            // if we dispatched an instruction, write the src and mark busy
            if (rt_v && rt == regs_update_counter) begin
                regs[regs_update_counter][22:16] <= rt_val;
            end
        end
    end

    // memory

    // these wires form a sort of memory bus
    wire [15:0]imem_raddr_out;
    wire [15:0]imem_data_out;
    wire imem_ready;

    wire [15:0]dmem_raddr_out;
    wire [15:0]dmem_data_out;
    wire dmem_ready;

    wire imem_re;
    wire [15:0]imem_raddr;

    wire dmem_re;
    wire [15:0]dmem_raddr;

    memcontr i0(clk,
       imem_re, imem_raddr,
       dmem_re, dmem_raddr,
       imem_ready,
       imem_raddr_out,
       imem_data_out,
       dmem_ready,
       dmem_raddr_out,
       dmem_data_out);

    // fetch

    // was a branch taken? to where?
    wire branch_taken = !ib_empty && ((opcode == `JMP) || (opcode == `JEQ && jeqReady && `CDB_DATA(0) == 1));
    wire [15:0]branch_target = opcode == `JMP ? jjj : pc + d;

    fetch f0(clk,
        ib_push, ib_push_data, ib_full,
        imem_raddr, imem_re,
        imem_raddr_out, imem_data_out, imem_ready,
        branch_taken, branch_target
        );

    // instruction buffer
    wire ib_full, ib_empty;
    wire ib_flush = branch_taken;

    wire ib_push;
    wire [31:0]ib_push_data;

    wire ib_pop = !ib_empty && ((opcode == `MOV || opcode == `ADD || opcode == `LD || opcode == `LDR) ? !fus_full :
                                opcode == `JEQ ? (jeqReady && `CDB_DATA(0) == 0) : 0);
    wire [31:0]ib_data_out;

    fifo #(5,32,0) ib0(clk,
        ib_push, ib_push_data, ib_full,
        ib_pop, ib_data_out, ib_empty,
        ib_flush);

    // Dispatch
    // This is the dispatcher logic. It is mostly a big block
    // of combinational logic that was best in its own file...
    // but Verilog :(

    // Decode the instructions
    wire [15:0]pc = ib_data_out[31:16];
    wire [15:0]inst = ib_data_out[15:0];
    wire [3:0]opcode = inst[15:12];
    wire [3:0]ra = inst[11:8];
    wire [3:0]rb = inst[7:4];
    wire [3:0]rt = inst[3:0];
    wire [15:0]jjj = inst[11:0]; // zero-extended
    wire [15:0]ii = inst[11:4]; // zero-extended
    wire [3:0]d = inst[3:0];

    // various dispatcher flags

    // Is a pending JEQ ready?
    wire jeqReady = `CDB_OP(0) == `JEQ && `CDB_VALID(0);

    // Is the dispatcher waiting for JEQ to be resolved
    reg waiting_jeq = 0;
    always @(posedge clk) begin
        if (!ib_empty && opcode == `JEQ) begin
            if (!waiting_jeq) begin
                waiting_jeq <= !fus_full;
            end else begin
                waiting_jeq <= !jeqReady;
            end
        end
    end

    // Is the processor halted?
    reg is_halted = 0;
    always @(posedge clk) begin
        if (!is_halted) begin
            is_halted <= !ib_empty && opcode == `HLT;
        end
    end

    // dispatcher interations with RSs and regs

    // should we write to rt?
    wire rt_v = !ib_empty && !fus_full && opcode != `JMP && opcode != `JEQ && opcode != `HLT;
    // value to write
    wire [22:16]rt_val = {1'h1, rs_num};

    // should we write to RS?
    wire rs_v = !ib_empty && !fus_full && opcode != `JMP && !(opcode == `JEQ && waiting_jeq) && opcode != `HLT;
    // value to write into the rs
    wire rs_r0 = opcode == `LD || opcode == `MOV ? 1 : !`REG_BUSY(ra) || `CDB_SAT(ra);
    wire rs_r1 = opcode == `LD || opcode == `MOV ? 1 : !`REG_BUSY(rb) || `CDB_SAT(rb);
    wire [15:0]rs_val0 = opcode == `LD || opcode == `MOV ? ii :
                                          !`REG_BUSY(ra) ? `REG_VAL(ra) :
                                            `CDB_SAT(ra) ? `CDB_VAL(ra) :
                                                           16'hxxxx;
    wire [15:0]rs_val1 = opcode == `LD || opcode == `MOV ? 0  :
                                          !`REG_BUSY(rb) ? `REG_VAL(rb) :
                                            `CDB_SAT(rb) ? `CDB_VAL(rb) :
                                                           16'hxxxx;
    wire [67:0]rs_val;
    assign rs_val[67:52] = pc;
    assign rs_val[51] = 0;
    assign rs_val[50] = 1;
    assign rs_val[49:46] = opcode;
    assign rs_val[45] = rs_r0; // R0
    assign rs_val[44] = rs_r1; // R1
    assign rs_val[43:38] = `REG_SRC(ra); // SRC0
    assign rs_val[37:32] = `REG_SRC(rb); // SRC1
    assign rs_val[31:16] = rs_val0; // VAL0
    assign rs_val[15:0]  = rs_val1; // VAL1

    // RSs
    // bits field in order
    // 16   pc
    // 1    issued
    // 1    busy
    // 4    op
    // 2    ready
    // 12   src
    // 32   val
    // -----------
    // 68   total
    //
    // 4 reservation stations for fxu: 0, 1, 2, 3
    // 4 reservation stations for ld: 4, 5, 6, 7

    reg [67:0]rs[0:`NUM_RS-1];

    // Are all RSs for the FXU full?
    wire fxu0_full = `RS_BUSY(0) && `RS_BUSY(1) && `RS_BUSY(2) && `RS_BUSY(3);
    // RS# of next free RS for FXU
    wire [5:0]fxu0_next_rs = !`RS_BUSY(0) ? 0 :
                       !`RS_BUSY(1) ? 1 :
                       !`RS_BUSY(2) ? 2 : 3;

    // All RSs for LD full?
    wire ld0_full = `RS_BUSY(4) && `RS_BUSY(5) && `RS_BUSY(6) && `RS_BUSY(7);
    // Next RS# for LD unit
    wire [5:0]ld0_next_rs = !`RS_BUSY(4) ? 4 :
                      !`RS_BUSY(5) ? 5 :
                      !`RS_BUSY(6) ? 6 : 7;

    // all RSs for the opcode full?
    wire fus_full = (opcode == `MOV || opcode == `ADD || opcode == `JEQ) ? fxu0_full :
                    (opcode == `LD  || opcode == `LDR) ? ld0_full : 0;
    // Next RS# for the given opcode
    wire [5:0]rs_num = (opcode == `MOV || opcode == `ADD || opcode == `JEQ) ? fxu0_next_rs :
                       (opcode == `LD  || opcode == `LDR) ? ld0_next_rs : 0;

    // Init all RSs to not busy and not issued
    integer rsn;
    initial begin
        for (rsn = 0 ; rsn < `NUM_RS; rsn = rsn + 1) begin
            `RS_ISSUED(rsn) <= 0;
            `RS_BUSY(rsn) <= 0;
        end
    end

    // convenience functions for RSs

    // Does the CDB lane satisfy the RS
    function cdbSatisfiesRs;
        input [5:0]rs_num_to_sat;
        input [1:0]cdb_num_from_sat;
        input which;

        cdbSatisfiesRs = `CDB_VALID(cdb_num_from_sat) && !`RS_READY(rs_num_to_sat, which) &&
                        `CDB_RS(cdb_num_from_sat) == `RS_SRC(rs_num_to_sat, which);
    endfunction

    // Is the RS ready to issue?
    function readyToIssue;
        input [5:0]rs_num_to_issue;

        readyToIssue = `RS_BUSY(rs_num_to_issue) &&
            `RS_READY(rs_num_to_issue, 0) &&
            `RS_READY(rs_num_to_issue, 1) &&
            !`RS_ISSUED(rs_num_to_issue);
    endfunction

    // Update the RSs every cycle
    integer rs_update_counter, cdbn;
    always @(posedge clk) begin
        for (rs_update_counter = 0; rs_update_counter < `NUM_RS; rs_update_counter = rs_update_counter + 1) begin
            // if the RS is busy...
            if (`RS_BUSY(rs_update_counter)) begin
                // check the CDB
                for(cdbn = 0; cdbn < `NUM_CDBS; cdbn = cdbn + 1) begin
                    // if the RS# was broadcast, free it since the instruction
                    // is done
                    if(`CDB_VALID(cdbn) && `CDB_RS(cdbn) == rs_update_counter) begin
                        `RS_BUSY(rs_update_counter) <= 0; // not busy
                        `RS_ISSUED(rs_update_counter) <= 0; // not issued
                    end
                    // if one of the operands becomes ready
                    if(cdbSatisfiesRs(rs_update_counter, cdbn, 0)) begin
                        rs[rs_update_counter][45] <= 1;
                        rs[rs_update_counter][31:16] <= `CDB_DATA(cdbn);
                    end
                    if(cdbSatisfiesRs(rs_update_counter, cdbn, 1)) begin
                        rs[rs_update_counter][44] <= 1;
                        rs[rs_update_counter][15:0] <= `CDB_DATA(cdbn);
                    end
                end
            end else begin
                // if the RS is not busy, listen to dispatcher to see
                // if we need to add a new instruction
                if(rs_update_counter == rs_num && rs_v) begin
                    rs[rs_update_counter] <= rs_val;
                end
            end
        end

        // submit the first ready RS to the correct FXU
        if (!fxu0_busy) begin
            if (readyToIssue(0)) begin
                fxu0_rs_ready <= 1;
                fxu0_ready_rs_num <= 0;
                fxu0_pc <= `RS_PC(0);
                fxu0_op <= `RS_OP(0);
                fxu0_val0 <= `RS_VAL(0,0);
                fxu0_val1 <= `RS_VAL(0,1);
                `RS_ISSUED(0) <= 1;
            end else if (readyToIssue(1)) begin
                fxu0_rs_ready <= 1;
                fxu0_ready_rs_num <= 1;
                fxu0_pc <= `RS_PC(1);
                fxu0_op <= `RS_OP(1);
                fxu0_val0 <= `RS_VAL(1,0);
                fxu0_val1 <= `RS_VAL(1,1);
                `RS_ISSUED(1) <= 1;
            end else if (readyToIssue(2)) begin
                fxu0_rs_ready <= 1;
                fxu0_ready_rs_num <= 2;
                fxu0_pc <= `RS_PC(2);
                fxu0_op <= `RS_OP(2);
                fxu0_val0 <= `RS_VAL(2,0);
                fxu0_val1 <= `RS_VAL(2,1);
                `RS_ISSUED(2) <= 1;
            end else if (readyToIssue(3)) begin
                fxu0_rs_ready <= 1;
                fxu0_ready_rs_num <= 3;
                fxu0_pc <= `RS_PC(3);
                fxu0_op <= `RS_OP(3);
                fxu0_val0 <= `RS_VAL(3,0);
                fxu0_val1 <= `RS_VAL(3,1);
                `RS_ISSUED(3) <= 1;
            end else begin
                fxu0_rs_ready <= 0;
            end
        end else begin
            fxu0_rs_ready <= 0;
        end

        // submit the first ready RS to the correct LD unit
        if (!ld0_busy) begin
            if (readyToIssue(4)) begin
                ld0_rs_ready <= 1;
                ld0_ready_rs_num <= 4;
                ld0_pc <= `RS_PC(4);
                ld0_op <= `RS_OP(4);
                ld0_val0 <= `RS_VAL(4,0);
                ld0_val1 <= `RS_VAL(4,1);
                `RS_ISSUED(4) <= 1;
            end else if (readyToIssue(5)) begin
                ld0_rs_ready <= 1;
                ld0_ready_rs_num <= 5;
                ld0_pc <= `RS_PC(5);
                ld0_op <= `RS_OP(5);
                ld0_val0 <= `RS_VAL(5,0);
                ld0_val1 <= `RS_VAL(5,1);
                `RS_ISSUED(5) <= 1;
            end else if (readyToIssue(6)) begin
                ld0_rs_ready <= 1;
                ld0_ready_rs_num <= 6;
                ld0_pc <= `RS_PC(6);
                ld0_op <= `RS_OP(6);
                ld0_val0 <= `RS_VAL(6,0);
                ld0_val1 <= `RS_VAL(6,1);
                `RS_ISSUED(6) <= 1;
            end else if (readyToIssue(7)) begin
                ld0_rs_ready <= 1;
                ld0_ready_rs_num <= 7;
                ld0_pc <= `RS_PC(7);
                ld0_op <= `RS_OP(7);
                ld0_val0 <= `RS_VAL(7,0);
                ld0_val1 <= `RS_VAL(7,1);
                `RS_ISSUED(7) <= 1;
            end else begin
                ld0_rs_ready <= 0;
            end
        end else begin
            ld0_rs_ready <= 0;
        end
    end

    // CDB
    // bits field in order
    // 1    valid
    // 6    rs#
    // 4    op
    // 16   data
    //
    // This is a big bus that can be listened in on. It is written by the FUs.
    // Convenience macros at top of file.
    wire [26:0]cdb[1:0];

    // FUs
    // There are 2 FUs
    // 1) FXU
    // 2) LD unit
    //
    // Each has 4 RSs and a lane in the CDB

    // FXU
    reg       fxu0_rs_ready = 0;
    reg  [5:0]fxu0_ready_rs_num;
    reg [15:0]fxu0_pc;
    reg  [3:0]fxu0_op;
    reg [15:0]fxu0_val0, fxu0_val1;

    wire      fxu0_busy;

    fxu fxu0(clk,
        fxu0_rs_ready, fxu0_ready_rs_num, fxu0_op, fxu0_pc,
        fxu0_val0, fxu0_val1,

        `CDB_VALID(0), `CDB_RS(0), `CDB_OP(0), `CDB_DATA(0),

        fxu0_busy
    );

    // LD unit
    reg       ld0_rs_ready = 0;
    reg  [5:0]ld0_ready_rs_num;
    reg [15:0]ld0_pc;
    reg  [3:0]ld0_op;
    reg [15:0]ld0_val0, ld0_val1;

    wire      ld0_busy;

    ld ld0(clk,
        ld0_rs_ready, ld0_ready_rs_num, ld0_op, ld0_pc,
        ld0_val0, ld0_val1,

        `CDB_VALID(1), `CDB_RS(1), `CDB_OP(1), `CDB_DATA(1),

        dmem_raddr, dmem_re,
        dmem_raddr_out, dmem_data_out, dmem_ready,

        ld0_busy
    );

endmodule
