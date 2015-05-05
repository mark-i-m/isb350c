`timescale 1ps/1ps

// Implementation of an FXU for the Tomasulo algo
//
// It is parametrized by its reservation station numbers
//
// It can do the following operations:
//
//  ADD, JEQ
//
// When a jeq completed, jeqReady = 1 and res_out = 1 if taken

`define ADD 1
`define JEQ 6

//States
`define FXU0 0
`define FXU1 1

module fxu(input clk,
    // TODO: update oupts
    input valid, input [5:0]rs_num, input [3:0]op,
    input [15:0]val0, input [15:0]val1,
    // output result
    output valid_out, output [5:0]rs_num_out, output [15:0]res_out,
    // busy?
    output busy
    );

    reg [3:0]state = `FXU0;
    reg [5:0]rs_num_in = 6'hxx;
    reg [3:0]op_in = 4'hx;
    reg [15:0]val0_in = 16'hxxx;
    reg [15:0]val1_in = 16'hxxx;

    always @(posedge clk) begin
        case(state)
            `FXU0 : begin
                valid_out_reg <= 0;
                jeqReady_reg <= 0;
                res_out_reg <= 16'hxxxx;

                op_in <= op;
                val0_in <= val0;
                val1_in <= val1;
                rs_num_out_reg <= rs_num;

                if(valid) begin
                    state <= `FXU1;
                end
            end
            `FXU1 : begin
                valid_out_reg <= 1;
                res_out_reg <= op_in == `ADD ? val0_in + val1_in :
                                               val0_in ==val1_in;
                jeqReady_reg <= op_in == `JEQ;
                state <= `FXU0;
            end

            default : begin
                $display("fxu undefined state");
                $finish;
            end
        endcase
    end

    // output
    reg [5:0]rs_num_out_reg;
    assign rs_num_out = rs_num_out_reg;

    reg valid_out_reg = 0;
    assign valid_out = valid_out_reg;

    reg [15:0]res_out_reg;
    assign res_out = res_out_reg;

    reg jeqReady_reg = 0;
    assign jeqReady = jeqReady_reg;

    assign busy = valid || state == `FXU1;

endmodule
