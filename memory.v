`timescale 1ps/1ps

// The is a simple memory controller/bridge that queues up requests
// for memory addresses and broadcasts the results from memory onto
// the memory bus.
//
// Fetch requests are passed directly to memory, since there is no
// latency (the magic 1 cycle fetch port).
//
// Data requests are queued up and submitted when memory is ready.
//
// Protocol:
//  set readEnable = 1
//      raddr = read address
//
//  A few cycles later:
//      ready = 1
//      rdata = data

// States:
`define W0 0 // Idle
`define D0 1 // Data request
`define D1 2
`define M0 5 // waiting for memory

module memcontr(input clk,
    // instruction read ports
    input re0, input [15:0]raddr0,
    // data read port
    input re1, input [15:0]raddr1,
    // output
    output iready, output [15:0]iraddr_out, output [15:0]idata,
    output dready, output [15:0]draddr_out, output [15:0]ddata);

    // state
    reg [3:0]dstate = `W0;

    // memory
    mem mem0(clk, re0, raddr0, iready, idata,
                  dmem_re, dmem_raddr, dmem_ready, dmem_rdata);

    // Fetch
    assign iraddr_out = raddr0;

    // Data
    reg dmem_re = 0;
    reg [15:0]dmem_raddr = 16'hxxxx;

    wire dmem_ready;
    wire [15:0]dmem_rdata;

    // data request queues
    fifo #(5, 16, 0) dq(clk, re1, raddr1, dq_full,
                      dpop, ddata_out, dq_empty, 0);

    reg dpop = 0;

    wire dq_full, dq_empty;
    wire [15:0]ddata_out;

    // logic
    always @(posedge clk) begin
        if (re1 && dq_full) begin // should never happen
            $display("d queue full");
            $finish;
        end

        // state update
        case(dstate)
            `W0 : begin
                // check for new memory requests
                if (!dq_empty) begin
                    dstate <= `M0;

                    dpop <= 1;

                    dmem_re <= 1;
                    dmem_raddr <= ddata_out;
                end
            end
            `M0 : begin
                // stop asking for memory
                dmem_re <= 0;
                dpop <= 0;

                // when the request is ready
                if (dmem_ready) begin
                    // check for the next one
                    dstate <= `W0;
                end
            end

            default : begin
                $display("unknown memory system state %d", dstate);
                $finish;
            end
        endcase
    end

    // output
    assign dready = dmem_ready;
    assign ddata = dmem_rdata;
    assign draddr_out = dmem_raddr;

endmodule
