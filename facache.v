`timescale 1ps/1ps

// A 4-word fully-associative cache with LRU eviction policy
//
// 1 read port
//
// Due to the microarchitecture, we will never have a concurrent
// read and insert.
//
// If an entry is already in the cache, it will not be inserted
// again.
module facache(input clk, input [15:0]adr, input readEnable, //read cache
    input [15:0]insert_adr, input [15:0]data_in, input valid_in, //insert
    output [15:0]data_out, output valid_out, // read cache
    output [15:0]evicted_adr, output [15:0]evicted_data, output evicted_valid); //evictions

    reg [15:0]data_out_reg;
    reg valid_out_reg = 0;
    assign data_out = data_out_reg;
    assign valid_out = valid_out_reg;

    reg [15:0]evicted_adr_reg;
    reg [15:0]evicted_data_reg;
    reg evicted_valid_reg = 0;
    assign evicted_adr = evicted_adr_reg;
    assign evicted_data = evicted_data_reg;
    assign evicted_valid = evicted_valid_reg;

    // 4-words of storage
    reg v[3:0];
    reg [15:0]tag[3:0];
    reg [15:0]data[3:0];

    initial begin
        v[0] <= 0;
        v[1] <= 0;
        v[2] <= 0;
        v[3] <= 0;
    end

    // LRU info
    reg lru_write;
    reg [1:0]used;
    wire [1:0]lru_idx; //output: the current LRU idx
    lru lru0(clk, lru_write, used, lru_idx);

    function isHit;
        input [1:0]i;
        input [15:0]a;

        isHit = v[i] && tag[i] == a;
    endfunction

    reg [1:0]entry_tmp;

    always @(posedge clk) begin
        if (valid_in &&
            !isHit(0,insert_adr) &&
            !isHit(1,insert_adr) &&
            !isHit(2,insert_adr) &&
            !isHit(3,insert_adr)) begin // insert into cache
            // find the first invalide entry
            if (!v[0]) begin
                v[0] <= 1;
                tag[0] <= insert_adr;
                data[0] <= data_in;

                lru_write <= 1;
                used <= 0;

                //$display("#%m[0] <= %x @ %x", data_in, insert_adr);
            end else if (!v[1]) begin
                v[1] <= 1;
                tag[1] <= insert_adr;
                data[1] <= data_in;

                lru_write <= 1;
                used <= 1;

                //$display("#%m[1] <= %x @ %x", data_in, insert_adr);
            end else if (!v[2]) begin
                v[2] <= 1;
                tag[2] <= insert_adr;
                data[2] <= data_in;

                lru_write <= 1;
                used <= 2;

                //$display("#%m[2] <= %x @ %x", data_in, insert_adr);
            end else if (!v[3]) begin
                v[3] <= 1;
                tag[3] <= insert_adr;
                data[3] <= data_in;

                lru_write <= 1;
                used <= 3;

                //$display("#%m[3] <= %x @ %x", data_in, insert_adr);
            end else begin // cache eviction: LRU
                evicted_adr_reg <= tag[lru_idx];
                evicted_data_reg <= data[lru_idx];
                evicted_valid_reg <= 1;

                v[lru_idx] <= 1;
                tag[lru_idx] <= insert_adr;
                data[lru_idx] <= data_in;

                lru_write <= 1;
                used <= lru_idx;
                //$display("#%m[%d] <= %x @ %x", lru_idx, data_in, insert_adr);
            end
        end else if(readEnable) begin
            // read from cache
            if (isHit(0,adr)) begin
                valid_out_reg <= 1;
                data_out_reg <= data[0];

                lru_write <= 1;
                used <= 0;
                //$display("#%m[0] hit %x @ %x", data[0], adr);
            end else if (isHit(1,adr)) begin
                valid_out_reg <= 1;
                data_out_reg <= data[1];

                lru_write <= 1;
                used <= 1;
                //$display("#%m[1] hit %x @ %x", data[1], adr);
            end else if (isHit(2,adr)) begin
                valid_out_reg <= 1;
                data_out_reg <= data[2];

                lru_write <= 1;
                used <= 2;
                //$display("#%m[2] hit %x @ %x", data[2], adr);
            end else if (isHit(3,adr)) begin
                valid_out_reg <= 1;
                data_out_reg <= data[3];

                lru_write <= 1;
                used <= 3;
                //$display("#%m[3] hit %x @ %x", data[3], adr);
            end else begin
                valid_out_reg <= 0;
                data_out_reg <= 16'hxxxx;

                lru_write <= 0;
            end
        end
        if (evicted_valid_reg) begin
            evicted_valid_reg <= 0;
        end
    end
endmodule

module lru(input clk, input lru_we, input [1:0]used, output [1:0]lru_idx);
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
            ////$display("MRU->LRU: %d %d %d %d", lru[0], lru[1], lru[2], lru[3]);
        end
    end

    assign lru_idx = lru[3];
endmodule
