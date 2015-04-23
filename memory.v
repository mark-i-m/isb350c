`timescale 1ps/1ps

// A memory system that integrates the given memory module. It keeps
// a FIFO queue of data requests and instruction requests. Data requests
// have a higher priority.
//
// Following the protocol below submits a request. When the request is done,
// the memory system will broadcast the memory address and data and set
// memReady = 1. Then, whoever cares can listen in and take whatever values
// they want.
//
// For instruction requests, use the first port.
// For data requests, use the second port, which has higher priority.
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
`define I0 3 // Instr request
`define I1 4
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
    reg [3:0]istate = `W0;
    reg [3:0]dstate = `W0;

    // memory
    mem mem0(clk, imem_re, imem_raddr, imem_ready, imem_rdata,
                  dmem_re, dmem_raddr, dmem_ready, dmem_rdata);

    reg imem_re = 0;
    reg [15:0]imem_raddr = 16'hxxxx;

    wire imem_ready;
    wire [15:0]imem_rdata;

    reg dmem_re = 0;
    reg [15:0]dmem_raddr = 16'hxxxx;

    wire dmem_ready;
    wire [15:0]dmem_rdata;

    // queues -- each 8 long, which should be more than enough
    fifo #(5) dq(clk, dpush, ddata_in, dq_full,
                      dpop, ddata_out, dq_empty);

    reg dpush = 0, dpop = 0;
    reg [15:0]ddata_in = 16'hxxxx;

    wire dq_full, dq_empty;
    wire [15:0]ddata_out;

    fifo #(3) iq(clk, ipush, idata_in, iq_full,
                      ipop, idata_out, iq_empty);

    reg ipush = 0, ipop = 0;
    reg [15:0]idata_in = 16'hxxxx;

    wire iq_full, iq_empty;
    wire [15:0]idata_out;

    // logic
    always @(posedge clk) begin
        // instruction requests
        if (re0) begin
            // enqueue the request
            ipush <= 1;
            idata_in <= raddr0;

            if (iq_full) begin // should never happen
                $display("i queue full");
                $finish;
            end
        end else begin
            ipush <= 0;
        end

        // data requests
        if (re1) begin
            // enqueue the request
            dpush <= 1;
            ddata_in <= raddr1;

            if (dq_full) begin // should never happen
                $display("d queue full");
                $finish;
            end
        end else begin
            dpush <= 0;
        end

        // state update
        case(istate)
            `W0 : begin
                // check for new memory requests
                if (!iq_empty) begin
                    ipop <= 1;
                    istate <= `I0;
                end
            end
            `I0 : begin
                // stop popping iq
                ipop <= 0;
                istate <= `I1;
            end
            `I1 : begin
                // get value from dq and submit to mem
                imem_re <= 1;
                imem_raddr <= idata_out;

                istate <= `M0;
            end
            `M0 : begin
                // stop asking for memory
                imem_re <= 0;

                // when the request is ready
                if (imem_ready) begin
                    // check for the next one
                    if (!iq_empty) begin
                        ipop <= 1;
                        istate <= `I0;
                    end else begin
                        istate <= `W0;
                    end
                end
            end

            default : begin
                $display("unknown memory system state %d", istate);
                $finish;
            end
        endcase
        case(dstate)
            `W0 : begin
                // check for new memory requests
                if (!dq_empty) begin
                    dpop <= 1;
                    dstate <= `D0;
                end
            end
            `D0 : begin
                // stop popping dq
                dpop <= 0;
                dstate <= `D1;
            end
            `D1 : begin
                // get value from dq and submit to mem
                dmem_re <= 1;
                dmem_raddr <= ddata_out;

                dstate <= `M0;
            end
            `M0 : begin
                // stop asking for memory
                dmem_re <= 0;

                // when the request is ready
                if (dmem_ready) begin
                    // check for the next one
                    if (!dq_empty) begin
                        dpop <= 1;
                        dstate <= `D0;
                    end else begin
                        dstate <= `W0;
                    end
                end
            end

            default : begin
                $display("unknown memory system state %d", dstate);
                $finish;
            end
        endcase
    end

    // output
    assign iready = imem_ready;
    assign idata = imem_rdata;
    assign iraddr_out = imem_raddr;

    assign dready = dmem_ready;
    assign ddata = dmem_rdata;
    assign draddr_out = dmem_raddr;

endmodule
