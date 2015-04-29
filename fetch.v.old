`timescale 1ps/1ps

// Implementation of a Fetch Unit that places instructions in a buffer
//
// If the buffer is full, fetch stops
//
// If there is a jmp, the fetch unit follows the target
//
// If there is a jeq, the fetch unit waits and listens for the result
// on the CDB before continuing fetching.

// states:
`define I0 0 // get next pc
`define L1 1 // check icache
`define M0 2 // memory request
`define D0 3 // partial decode to determine jmps
`define J0 4 // waiting for jeq

// instructions
`define JMP 2
`define HLT 3
`define JEQ 6

// Output ports
// ib_push -- the flag for the fifo IB to push
// ib_push_data -- the value to push, an instruction
// mem_raddr -- the adr to submit to memory for a request
// mem_re -- the enable flag for memory
//
// Input ports
// ib_full -- the flag of whether the IB is full
// mem_addr_out -- the address of the value being broadcast by memory now
// mem_data_out -- the value being broadcast by memory now
// mem_ready -- whether the value begin broadcase by memory is valid
// jeqReady -- the flag that a FXU has finished a jeq
// jeqTaken -- whether the jeq was taken or not

module fetch(input clk,
    // instruction buffer
    output ib_push, output [15:0]ib_push_data, input ib_full,
    // memory access
    output [15:0]mem_raddr, output mem_re,
    input [15:0]mem_addr_out, input [15:0]mem_data_out, input mem_ready,
    // conditional jump feedback
    input jeqReady, input jeqTaken,
    // halt feedback
    input isHalted
    );

    // for simulation
    reg wasHalted = 0;
    reg notHalted = 1;
    counter ctr(wasHalted, clk, notHalted && state == `D0,);
    always @(posedge clk) begin
        wasHalted <= isHalted;
    end

    // state
    reg [3:0]state = `I0;

    // current fetch pc
    reg [15:0]pc = 0;

    // icache
    dmcache #(10) l1i(clk,
        pc, state == `I0, data_out0, valid0,
        ,,,,
        insert_adr, data_in, valid_in,
        ,,);

    reg [15:0]insert_adr = 16'hxxxx;
    reg [15:0]data_in = 16'hxxxx;
    reg valid_in = 0;

    wire [15:0]data_out0;
    wire valid0;

    // partial decode
    reg [15:0]instr = 16'hxxxx;

    // logic
    always @(posedge clk) begin
        case(state)
            `I0 : begin
                ib_push_reg <= 0;

                if (!ib_full) begin // wait if IB is full
                    state <= `L1;
                end
            end
            `L1 : begin
                if (valid0) begin // cache hit
                    instr = data_out0; // blocking assignment
                    state <= `D0;
                end else begin // cache miss
                    // submit memory request
                    mem_raddr_reg <= pc;
                    mem_re_reg <= 1;
                    state <= `M0;
                end
            end
            `M0 : begin
                mem_re_reg <= 0;

                if (mem_ready && mem_addr_out == pc) begin
                    instr = mem_data_out; // blocking assignment

                    // insert into i cache
                    insert_adr <= pc;
                    data_in = mem_data_out; // blocking assignment
                    valid_in <= 1;

                    state <= `D0;
                end
            end
            `D0 : begin
                valid_in <= 0;

                if (instr[15:12] == `JMP) begin
                    // fetch at new address
                    pc <= instr[11:0]; //jjj
                    state <= `I0;
                end else if (instr[15:12] == `JEQ) begin
                    // wait for taken signal
                    state <= `J0;

                    // put address in IB
                    ib_push_reg <= 1;
                    ib_push_data_reg <= instr;
                end else begin
                    if (instr[15:12] == `HLT) begin
                        notHalted <= 0;
                    end
                    // fetch sequentially
                    pc <= pc + 1;
                    state <= `I0;

                    // put address in IB
                    ib_push_reg <= 1;
                    ib_push_data_reg <= instr;
                end
            end
            `J0 : begin
                ib_push_reg <= 0;

                if (jeqReady) begin
                    pc <= jeqTaken ? pc + instr[3:0] : pc + 1;
                    state <= `I0;
                end
            end

            default : begin
                $display("unknown fetch state %d", state);
                $finish;
            end
        endcase
    end

    // output
    reg [15:0]mem_raddr_reg = 16'hxxxx;
    reg mem_re_reg = 0;

    reg ib_push_reg = 0;
    reg [15:0]ib_push_data_reg = 16'hxxxx;

    assign mem_raddr = mem_raddr_reg;
    assign mem_re = mem_re_reg;

    assign ib_push = ib_push_reg;
    assign ib_push_data = ib_push_data_reg;

endmodule
