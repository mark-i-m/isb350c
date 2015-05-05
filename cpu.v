`timescale 1ps/1ps

// Simple Tomasulo processor

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
    counter ctr(0, clk, 1,);

    // registers: busy(1bit), src(6bit), val(16bit)
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
            if (`CDB_SAT(regs_update_counter) && !(rt_v && rt == regs_update_counter)) begin
                regs[regs_update_counter] <= {1'h0, 6'hxx, `CDB_VAL(regs_update_counter)};
            end
            if (rt_v && rt == regs_update_counter) begin
                regs[regs_update_counter] <= rt_val;
            end
        end
    end

    // memory
    wire [15:0]imem_raddr_out;
    wire [15:0]imem_data_out;
    wire imem_ready;

    wire [15:0]dmem_raddr_out;
    wire [15:0]dmem_data_out;
    wire dmem_ready;

    wire imem_re;
    wire [15:0]imem_raddr;

    wire dmem_re; // TODO: unused wire
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
    wire branch_taken = opcode_v && ((opcode == `JMP) || (opcode == `JEQ && jeqReady && `CDB_DATA(0)));
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

    wire ib_pop = !(fus_full || ib_empty || (opcode == `JEQ && opcode_v && !jeqReady));
    wire [31:0]ib_data_out;

    fifo #(5,32,1) ib0(clk,
        ib_push, ib_push_data, ib_full,
        ib_pop, ib_data_out, ib_empty,
        ib_flush);

    // Dispatch
    // This is the dispatcher logic. It is mostly a big block
    // of combinational logic that was best in its own file...
    // but Verilog =[

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

    // Is the current instruction valid
    wire opcode_v = !ib_empty && !waiting_jeq && !fus_full;

    // Is the dispatcher waiting for JEQ to be resolved
    reg waiting_jeq = 0;
    always @(posedge clk) begin
        waiting_jeq <= opcode_v && opcode == `JEQ && !jeqReady;
    end

    // Is a pending JEQ ready?
    wire jeqReady = `CDB_OP(0) == `JEQ && `CDB_VALID(0);

    // Dispatcher and regs

    // this is a flag: should we write to rt?
    wire rt_v = opcode_v && (opcode == `MOV || opcode == `ADD || opcode == `LD || opcode == `LDR);
    // this is the val to write to rt
    wire [22:16]rt_val = {1'h1, rs_num}; // TODO: bounds for data width?

    // another flag: should we write to RS?
    wire rs_v = rt_v && opcode_v && opcode == `JEQ;
    // another value: what to write into the rs
    wire rs_r0 = opcode == `LD || opcode == `MOV ? 1 : !`REG_BUSY(ra) || `CDB_SAT(ra);
    wire rs_r1 = opcode == `LD || opcode == `MOV ? 1 : !`REG_BUSY(rb) || `CDB_SAT(rb);
    wire rs_val0 = opcode == `LD || opcode == `MOV ? ii : `CDB_SAT(ra) ? `CDB_VAL(ra) : `REG_VAL(ra);
    wire rs_val1 = opcode == `LD || opcode == `MOV ? 0  : `CDB_SAT(rb) ? `CDB_VAL(rb) : `REG_VAL(rb);
    wire [51:0]rs_val = {1'h0, 1'h1, opcode, rs_r0, `REG_SRC(ra), rs_val0, rs_r1, `REG_SRC(rb), rs_val1};

    // RSs
    // bits field in order
    // 1    issued
    // 1    busy
    // 4    op
    // 2    ready
    // 12   src
    // 32   val
    // -----------
    // 51   total

    // 4 reservation stations for fxu: 0, 1, 2, 3
    // 4 reservation stations for ld: 4, 5, 6, 7
    reg [51:0]rs[0:`NUM_RS-1];
    // TODO: present inputs to fus

    wire fus_full = ; //TODO: stuff here
    wire [5:0]rs_num = ; //TODO:stuff here

    // Init all RSs to not busy and not issued
    integer rsn;
    initial begin
        for (rsn = 0 ; rsn < `NUM_RS; rsn = rsn + 1) begin
            `RS_ISSUED(rsn) <= 0;
            `RS_BUSY(rsn) <= 0;
        end
    end

    function cdbSatisfiesRs;
        input [5:0]rs_num_to_sat;
        input [1:0]cdb_num_from_sat;
        input which;

        cdbSatisfiesRs = `CDB_VALID(cdb_num_from_sat) && !`RS_READY(rs_num_to_sat, which) &&
                        `CDB_RS(cdb_num_from_sat) == `RS_SRC(rs_num_to_sat, which);
    endfunction

    integer rs_update_counter, cdbn;
    always @(posedge clk) begin
        // TODO: update ISSUED bit
        for (rs_update_counter = 0; rs_update_counter < `NUM_RS; rs_update_counter = rs_update_counter + 1) begin
            if (`RS_BUSY(rs_update_counter)) begin
                // from CDB
                for(cdbn = 0; cdbn < `NUM_CDBS; cdbn = cdbn + 1) begin
                    if(`CDB_VALID(cdbn) && `CDB_RS(cdbn) == rs_update_counter) begin
                        `RS_BUSY(rs_update_counter) <= 0; // not busy
                        `RS_ISSUED(rs_update_counter) <= 0; // not issued
                    end
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
                // from dispatcher
                if(rs_update_counter == rs_num) begin
                    rs[rs_update_counter] <= rs_val;
                end
            end
        end
    end

    // CDB
    // bits field in order
    // 1    valid
    // 6    rs#
    // 4    op
    // 16   data
    wire [26:0]cdb[1:0];

    // FUs
    // TODO: fix everything below here

    fxu fxu0(clk,
        fxu0_rs_ready, fxu0_ready_rs_num, fxu0_op,
        fxu0_val0, fxu0_val1,

        cdb0_v, cdb0_rs_num, cdb0_data,

        fxu0_jeqReady,

        fxu0_busy
    );

    reg       fxu0_rs_ready = 0;
    reg  [5:0]fxu0_ready_rs_num;
    reg  [3:0]fxu0_op;
    reg [15:0]fxu0_val0, fxu0_val1;

    wire      fxu0_jeqReady;
    wire      fxu0_busy;

    wire fxu0_full = `RS_BUSY(4) && `RS_BUSY(5) && `RS_BUSY(6) && `RS_BUSY(7);
    wire [5:0]fxu0_next_rs = !`RS_BUSY(4) ? 4 :
                       !`RS_BUSY(5) ? 5 :
                       !`RS_BUSY(6) ? 6 : 7;


    ld ld0(clk,
        ld0_rs_ready, ld0_ready_rs_num, ld0_raddr,

        cdb3_v, cdb3_rs_num, cdb3_data,

        mem_raddr_ld, mem_re_ld,
        dmem_raddr_out, dmem_data_out, dmem_ready,

        ld0_busy
    );

    reg       ld0_rs_ready = 0;
    reg  [5:0]ld0_ready_rs_num;
    reg [15:0]ld0_raddr;

    wire ld0_busy;

    wire ld0_full = `RS_BUSY(0) && `RS_BUSY(1) && `RS_BUSY(2) && `RS_BUSY(3);
    wire [5:0]ld0_next_rs = !`RS_BUSY(0) ? 0 :
                      !`RS_BUSY(1) ? 1 :
                      !`RS_BUSY(2) ? 2 : 3;

endmodule
