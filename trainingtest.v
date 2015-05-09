`timescale 1ps/1ps

module ttest();

    // debugging
    initial begin
        $dumpfile("test.vcd");
        $dumpvars(4,ttest);
    end

    // clk
    wire clk;
    clock c0(clk);

    // counter
    counter ctr(stop_ctr, clk, 0, cycle);
    reg stop_ctr = 0;

    wire [15:0]cycle;

    // stuff
    reg v_in = 0;
    reg [15:0]pc;
    reg [15:0]addr;

    isb #(1) i0(clk,
        v_in, pc, addr,
        ,
    );

    always @(posedge clk) begin
        case(cycle)
            10 : begin
                v_in <= 1;
                pc <= 16'h0000;
                addr <= 16'h0010;
            end
            11 : begin
                v_in <= 1;
                pc <= 16'h0000;
                addr <= 16'h0011;
            end
            12 : begin
                v_in <= 1;
                pc <= 16'h0000;
                addr <= 16'h0012;
            end
            13 : begin
                v_in <= 1;
                pc <= 16'h0000;
                addr <= 16'h0011;
            end
            14 : begin
                v_in <= 1;
                pc <= 16'h0000;
                addr <= 16'h0012;
            end
            15 : begin
                v_in <= 1;
                pc <= 16'h0000;
                addr <= 16'h0011;
            end
            16 : begin
                v_in <= 1;
                pc <= 16'h0000;
                addr <= 16'h0012;
            end
            17 : begin
                v_in <= 1;
                pc <= 16'h0000;
                addr <= 16'h0011;
            end


            100 : begin
                stop_ctr <= 1;
            end
            default : begin
                v_in <= 0;
                pc <= 16'hxxxx;
                addr <= 16'hxxxx;
            end
        endcase
    end
endmodule
