`timescale 1ps/1ps

`define SIZE ((1<<WIDTH)-1)

// A direct-mapped cache
//
// 2 read ports
//
// Size of cache is given by 1 << WIDTH, which is a parameter specified
// by the user.
//
// Only one insert can happen at a time, which is OK because memory only
// has one read port.
module dmcache(input clk,
    // cache read
    input [15:0]raddr0, input re0, output [15:0]data_out0, output valid0,
    input [15:0]raddr1, input re1, output [15:0]data_out1, output valid1,
    // cache insert
    input [15:0]insert_adr, input [15:0]data_in, input valid_in,
    // cache evictions
    output [15:0]evicted_adr, output [15:0]evicted_data, output evicted_valid);

    parameter WIDTH = 2; // default to 4 words

    // output
    reg [15:0]data_out0_reg;
    reg valid0_reg = 0;
    assign data_out0 = data_out0_reg;
    assign valid0 = valid0_reg;

    reg [15:0]data_out1_reg;
    reg valid1_reg = 0;
    assign data_out1 = data_out1_reg;
    assign valid1 = valid1_reg;

    reg [15:0]evicted_adr_reg;
    reg [15:0]evicted_data_reg;
    reg evicted_valid_reg = 0;
    assign evicted_adr = evicted_adr_reg;
    assign evicted_data = evicted_data_reg;
    assign evicted_valid = evicted_valid_reg;

    // cache storage
    reg v[`SIZE:0];
    reg [(15-WIDTH):0]tags[`SIZE:0];
    reg [15:0]data[`SIZE:0];

    // initialize all to invalid
    integer initcounter;
    initial begin
        for(initcounter = 0; initcounter < `SIZE + 1; initcounter = initcounter + 1) begin
            v[initcounter] <= 0;
        end
    end

    // useful functions
    function [(WIDTH-1):0]line;
        input [15:0]adr;

        line = adr[(WIDTH-1):0];
    endfunction

    function [(15-WIDTH):0]tag;
        input [15:0]adr;

        tag = adr[15:(WIDTH)];
    endfunction

    function isHit;
        input [15:0]a; // memory address

        isHit = v[line(a)] && tags[line(a)] == tag(a);
    endfunction

    reg [1:0]entry_tmp;

    always @(posedge clk) begin
        // cache insert
        if (valid_in) begin
            v[line(insert_adr)] <= 1;
            tags[line(insert_adr)] <= tag(insert_adr);
            data[line(insert_adr)] <= data_in;
            //$display("#%m[%d] <= %x @ %x", line(insert_adr), data_in, insert_adr);
        end

        // cache reads
        if (re0 && isHit(raddr0)) begin
            valid0_reg <= 1;
            data_out0_reg <= data[line(raddr0)];
            //$display("#%m[%d] hit %x @ %x", line(raddr0), data[line(raddr0)], raddr0);
        end else begin
            valid0_reg <= 0;
        end
        if (re1 && isHit(raddr1)) begin
            valid1_reg <= 1;
            data_out1_reg <= data[line(raddr1)];
            //$display("#%m[%d] hit %x @ %x", line(raddr1), data[line(raddr1)], raddr1);
        end else begin
            valid1_reg <= 0;
        end
    end
endmodule
