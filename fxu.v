`timescale 1ps/1ps

// Implementation of an FXU for the Tomasulo algo
//
// It can do the following operations:
//
//  MOV, ADD, JEQ
//
// When a jeq completed, res_out = 1 if taken

`define MOV 0
`define ADD 1
`define JEQ 6

module fxu(input clk,
    // instructions from RSs
    input valid, input [5:0]rs_num, input [3:0]op,
    input [15:0]val0, input [15:0]val1,
    // output result
    output valid_out, output [5:0]rs_num_out, output [3:0]op_out, output [15:0]res_out, //TODO: undefined wire: op_out
    // busy?
    output busy
    );

    // output
    assign valid_out = valid;

    assign rs_num_out = rs_num;

    assign op_out = op;

    assign res_out = op == `MOV ? val0 :
                     op == `ADD ? val0 + val1 :
                     op == `JEQ ? val0 == val1 :
                     16'hxxxx;

    assign busy = 0;

endmodule
