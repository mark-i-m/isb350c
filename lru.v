`timescale 1ps/1ps

// A module to keep track of the LRU of 4 items

module lru(input clk, input lru_we, input [1:0]used, output [1:0]lru_idx);

    parameter DEBUG = 0;

    reg [1:0]lru[3:0];
    // 0 -> MRU, 3 -> LRU

    initial begin
        lru[0] = 0;
        lru[1] = 1;
        lru[2] = 2;
        lru[3] = 3;
    end

    always @(posedge clk) begin
        if (lru_we) begin // update LRU order
            if (lru[3] == used) begin
                lru[3] <= lru[2];
                lru[2] <= lru[1];
                lru[1] <= lru[0];
                lru[0] <= used;
            end else if (lru[2] == used) begin
                lru[2] <= lru[1];
                lru[1] <= lru[0];
                lru[0] <= used;
            end else if (lru[1] == used) begin
                lru[1] <= lru[0];
                lru[0] <= used;
            end
            if (DEBUG) $display("MRU->LRU: %d %d %d %d", lru[0], lru[1], lru[2], lru[3]);
        end
    end

    assign lru_idx = lru[3];
endmodule
