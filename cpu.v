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

    wire dmem_re; // TODO
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
    reg branch_taken = 0; //TODO:hook up
    reg [15:0]branch_target = 16'hxxxx;

    fetch f0(clk,
        ib_push, ib_push_data, ib_full,
        imem_raddr, imem_re,
        imem_raddr_out, imem_data_out, imem_ready,
        branch_taken, branch_target
        );

    // instruction buffer
    wire ib_full, ib_empty;
    reg ib_flush = 0 ;

    wire ib_push;
    wire [31:0]ib_push_data;

    reg ib_pop = 0; // TODO : hook these up
    wire [31:0]ib_data_out;

    fifo #(5,32,1) ib0(clk,
        ib_push, ib_push_data, ib_full,
        ib_pop, ib_data_out, ib_empty,
        ib_flush);

    // dispatch
    dispatch d0();//TODO: <- put stuff here
    
    // RSs
    
    // CDB

    // FUs


endmodule
