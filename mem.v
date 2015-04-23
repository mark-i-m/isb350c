/* memory */

`timescale 1ps/1ps

// Protocol:
//  set fetchEnable = 1
//      fetchAddr = read address
//
//  A few cycles later:
//      fetchReady = 1
//      fetchData = data
//
module mem(input clk,
    // fetch port
    input fetchEnable,
    input [15:0]fetchAddr,
    output fetchReady,
    output [15:0]fetchData,

    // load port
    input loadEnable,
    input [15:0]loadAddr,
    output loadReady,
    output [15:0]loadData



);

    reg [15:0]data[1023:0];

    /* Simulation -- read initial content from file */
    initial begin
        $readmemh("mem.hex",data);
    end

    reg [15:0]fetchPtr = 16'hxxxx;
    reg [15:0]fetchCounter = 0;

    assign fetchReady = (fetchCounter == 1);
    assign fetchData = (fetchCounter == 1) ? data[fetchPtr] : 16'hxxxx;

    always @(posedge clk) begin
        if (fetchEnable) begin
            fetchPtr <= fetchAddr;
            fetchCounter <= 1;
        end else begin
            if (fetchCounter > 0) begin
                fetchCounter <= fetchCounter - 1;
            end else begin
                fetchPtr <= 16'hxxxx;
            end
        end
    end

    reg [15:0]loadPtr = 16'hxxxx;
    reg [15:0]loadCounter = 0;

    assign loadReady = (loadCounter == 1);
    assign loadData = (loadCounter == 1) ? data[loadPtr] : 16'hxxxx;

    always @(posedge clk) begin
        if (loadEnable) begin
            loadPtr <= loadAddr;
            loadCounter <= 100;
        end else begin
            if (loadCounter > 0) begin
                loadCounter <= loadCounter - 1;
            end else begin
                loadPtr <= 16'hxxxx;
            end
        end
    end

endmodule
