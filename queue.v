`timescale 1ps/1ps

// Implements a FIFO queue as a circular buffer. The number of
// entries is specified by the user. The default is 1 << 5 = 32.
//
// It is synchronous with the clk.
//
// When push is true, the value of data_in is queued.
// When pop is true, the head of the queue is dequeued.
// When flush is true, the queue is emptied.
//
// If the queue is full, then q_full = 1
// If the queue is empty, the q_empty = 1
//
// Pushing to a full queue or popping from an empty queue are
// undefined behavior.
//
// The head of the queue is always presented at data_out if the
// queue is not empty. Otherwise, the value is undefined.

module fifo(input clk,
            input push, input [WIDTH-1:0]data_in, output q_full,
            input pop, output [WIDTH-1:0]data_out, output q_empty,
            input flush);

    parameter SIZE = 5; // log_2 of the number of entries
    parameter WIDTH = 16; // number of bits per entry
    parameter DEBUG = 0; // print debug statements?

    // head and tail pointers
    reg [SIZE:0]head = 0; // first valid entry
    reg [SIZE:0]tail = 0; // first empty spot
    reg [SIZE:0]n = 0; // number of entries currently

    // data space
    reg [WIDTH-1:0]data[(1<<SIZE)-1:0];

    // update on clk tick
    always @(posedge clk) begin
        // push
        if (push && !q_full && !flush) begin
            data[tail] <= data_in;
            tail <= tail == ((1 << SIZE) -1) ? 0 : tail + 1;
            if (DEBUG) $display("%m[%d] push %x", tail, data_in);
        end
        // pop
        if (pop && !q_empty && !flush) begin
            head <= head == ((1 << SIZE) -1) ? 0 : head + 1;
            if (DEBUG) $display("%m[%d] pop  %x", head, data[head]);
        end
        // flush
        if (flush) begin
            head <= tail;
            n <= 0;
            if (DEBUG) $display("%m flush");
        end
        // update counts
        n <= flush ? 0 : n + ((push && !q_full && !flush) - (pop && !q_empty && !flush));
    end

    // output
    assign data_out = data[head]; // always present head
    assign q_full = n == (1 << SIZE);
    assign q_empty = n == 0;

endmodule
