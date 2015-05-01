`timescale 1ps/1ps

// Simple Tomasulo processor

`define REG_BUSY(i) regs[i][31]
`define REG_SRC(i)  regs[i][30:16]
`define REG_VAL(i)  regs[i][15:0]

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
    reg regs[31:0];

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

    // This is the dispatcher logic. It is mostly a big block
    // of combinational logic that was best in its own file...
    // but Verilog =[
    //
    // Inputs:
    // CDB
    // IB
    //
    // Outputs:
    // ib_flush?
    // branch_taken?/branch_target
    // REGS
    //  - which regs to update
    //  - how to update them
    // RSs
    //  - which RSs to update
    //  - what are the values

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
    wire opcode_v = !ib_empty && !waiting_jeq && !fus_full;

    reg waiting_jeq = 0;
    always @(posedge clk) begin
        waiting_jeq <= opcode_v && opcode == `JEQ && !jeqReady;
    end

    wire jeqReady = cdb0_op == `JEQ && cdb0_v; // TODO: undefined wires: cdb0

    // Dispatcher and regs
    wire [31:0]va = regs[ra];
    wire [31:0]vb = regs[rb];

    // this is a flag: should we write to rt?
    wire rt_v = opcode_v && (opcode == `MOV || opcode == `ADD || opcode == `LD || opcode == `LDR); // TODO: hook this up
    // this is the val to write to rt
    wire [31:0]rt_val = {1'h1, rs_num}; // TODO: rs_num

    // another flag: should we write to RS?
    wire rs_v = rt_v && opcode_v && opcode == `JEQ;
    // another value: what to write into the rs
    wire [/* Put stuff here */]rs_val = 0 ;// TODO: insert stuff here

    // RSs

    // CDB

    // FUs


endmodule
