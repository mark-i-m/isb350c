`timescale 1ps/1ps

// Implementation of a Fetch Unit that places instructions in a buffer
//
// If the buffer is full, fetch stops
//
// Assumes the magic 1 cycle fetch port, but should work correctly regardless

module fetch(input clk,
    // instruction buffer
    output ib_push, output [15:0]ib_push_data, input ib_full,
    // memory access
    output [15:0]mem_raddr, output mem_re,
    input [15:0]mem_addr_out, input [15:0]mem_data_out, input mem_ready,
    // jump feedback
    input branch_taken, input [15:0]branch_target
    );

    reg [15:0]pc_0 = 16'hFFFF, pc_1, pc_2;
    reg first = 1;

    reg v_0 = 0, v_1 = 0, v_2 = 0;

    reg mem_ready_2 = 0;
    reg [15:0]mem_data_2 = 16'hxxxx;

    //reg branch_taken_saved = 0;
    //reg branch_target_saved = 16'hxxxx;

    wire isStalling = (!mem_ready || ib_full) && !first;

    wire [15:0]next_pc =
                        //branch_taken ? branch_target :
                        pc_0 + 1
                    ;

    always @(posedge clk) begin
        if (!isStalling) begin
            // If the IB has space and memory is not already
            // processing a result, then we can send the next
            // memory request
            pc_0 <= next_pc;
        end else
        // Otherwise, if a branch was taken while we were waiting
        if (branch_taken) begin
            pc_0 <= branch_target - 1; // set the new target so that next_pc is correct
            v_0 <= 0; // All instructions in the pipeline are invalid
            v_1 <= 0;
            v_2 <= 0;
        end

        // When a request is ready move all its state down the pipeline
        // Keep in mind that the beginning might be waiting for something
        if (mem_ready) begin
            v_0 <= !isStalling;
            v_1 <= v_0;
            v_2 <= v_1;
            //v_1 <= (wasStalling ? branch_taken_saved : branch_taken) ? 0 : v_0;
            //v_1_saved <= (wasStalling ? branch_taken_saved : branch_taken) ? 0 : v_1;

            pc_1 <= pc_0;
            pc_2 <= pc_1;

            mem_ready_2 <= mem_ready;
            mem_data_2 <= mem_data_out;

            // branch_taken_saved <= branch_taken;
            // branch_target_saved <= branch_target;
        end
        /*if (!branch_taken_saved) begin
            branch_taken_saved <= branch_taken;
            branch_target_saved <= branch_target;
        end*/

       // If the result was consumed and a new one is not ready yet,
       // invalidate the consumed result
        if (!ib_full && !mem_ready) begin
            mem_ready_2 <= 0;
        end

        // Initial state
        if (first) begin
            v_0 <= 1;
            pc_0 <= 0;
        end

        first <= 0;
    end

    // output
    assign ib_push = mem_ready_2 && v_1;//!branch_taken && !ib_full && ((wasStalling && v_1_saved && mem_ready_saved) || (v_0 && mem_ready));
    assign ib_push_data = mem_data_2; //(wasStalling && v_1_saved && mem_ready_saved) ? mem_data_saved : mem_data_out;

    assign mem_re = !isStalling;
    assign mem_raddr = next_pc;

endmodule
