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
`define REG_BUSY(i) regs[i][31]
`define REG_SRC(i)  regs[i][30:16]
`define REG_VAL(i)  regs[i][15:0]

`define RS_ISSUED(rs_num) rs[rs_num][51]
`define RS_BUSY(rs_num) rs[rs_num][50]
`define RS_OP(rs_num) rs[rs_num][49:46]
`define RS_READY(rs_num, which) (!which ? rs[rs_num][45] : rs[rs_num][44])
`define RS_SRC(rs_num, which) (!which ? rs[rs_num][43:38] : rs[rs_num][37:32])
`define RS_VAL(rs_num, which) (!which ? rs[rs_num][31:16] : rs[rs_num][15:0])

// Parameters
`define NUM_REGS (1<<`REGS_WIDTH)
`define REGS_WIDTH 4

`define NUM_RS (1<<`RS_WIDTH)
`define RS_WIDTH 3 // 2 ** RS_WIDTH = NUM_RS

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

    // registers: busy(1bit), src(15bit), val(16bit)
    // TODO: update from dispatcher
    reg [31:0]regs[`NUM_REGS-1:0];

    // Init all registers to not busy
    integer reg_init_counter;
    initial begin
        for (reg_init_counter = 0; reg_init_counter < `NUM_REGS; reg_init_counter = reg_init_counter + 1) begin
            `REG_BUSY(reg_init_counter) <= 0;
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

    wire dmem_re; // TODO: hook this up
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
    wire branch_taken = opcode_v && ((opcode == `JMP) || (opcode == `JEQ && jeqReady && cdb0_val)); //TODO: undefined wires: cdb0
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
    wire jeqReady = cdb0_op == `JEQ && cdb0_v; // TODO: undefined wires: cdb0

    // Dispatcher and regs
    wire [31:0]va = regs[ra];
    wire [31:0]vb = regs[rb];

    // this is a flag: should we write to rt?
    wire rt_v = opcode_v && (opcode == `MOV || opcode == `ADD || opcode == `LD || opcode == `LDR); // TODO: hook this up
    // this is the val to write to rt
    wire [31:0]rt_val = {1'h1, rs_num}; // TODO: undefined wire: rs_num

    // another flag: should we write to RS?
    wire rs_v = rt_v && opcode_v && opcode == `JEQ;
    // another value: what to write into the rs
    wire [51:0]rs_val = 0 ;// TODO: insert stuff here

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

    // Init all RSs to not busy and not issued
    integer rsn;
    initial begin
        for (rsn = 0 ; rsn < `NUM_RS; rsn = rsn + 1) begin
            `RS_ISSUED(rsn) <= 0;
            `RS_BUSY(rsn) <= 0;
        end
    end

    // CDB

    // FUs


endmodule
