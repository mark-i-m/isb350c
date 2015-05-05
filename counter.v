module counter(input isHalt, input clk, input W_v, output cycle);

    reg [15:0] count = 0;
    reg real insCount = 0;

    always @(posedge clk) begin
        if (W_v) begin
            insCount <= insCount + 1;
        end
        if (isHalt) begin
            $display("@%d cycles\t%d instrs\tCPI=%f",count, insCount, count / insCount);
        end
        if (count == 300) begin
            $display("#ran for 100000 cycles");
        end
        count <= count + 1;
    end

    assign cycle = count;

endmodule

