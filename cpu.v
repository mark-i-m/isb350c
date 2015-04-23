`timescale 1ps/1ps

// Implementation of OoO processor with Tomasulo algo
//
//  3 FXU
//  1 LD
//
// 3 levels of data caches
//  - 4 words
//  - fully associative
//
// 1 level of instruction caches
//  - 2^10 words
//  - direct mapped
//
// 32 entry instruction buffer
//
// 4 reservation stations per FU

// Opcodes
`define MOV 0
`define ADD 1
`define JMP 2
`define HLT 3
`define LD  4
`define LDR 5
`define JEQ 6

// Dispatch states:
`define DP  0 // Pop
`define DD  1 // Dispatch
`define DW0 2 // Waiting for FUs
`define DW1 3 // Waiting for IB
`define DH  4 // Waiting to halt

// tons of macros
`define ISSUED(rs_num) rs[rs_num][51]
`define BUSY(rs_num) rs[rs_num][50]
`define OP(rs_num) rs[rs_num][49:46]
`define READY(rs_num, which) (!which ? rs[rs_num][45] : rs[rs_num][44])
`define SRC(rs_num, which) (!which ? rs[rs_num][43:38] : rs[rs_num][37:32])
`define VAL(rs_num, which) (!which ? rs[rs_num][31:16] : rs[rs_num][15:0])

module main();

    initial begin
        $dumpfile("cpu.vcd");
        $dumpvars(4,main);
    end

    reg isDisplayed = 0;
    always @(posedge clk) begin
        if (isHalted && !isDisplayed) begin
            $display("#0:%x",regs[0]);
            $display("#1:%x",regs[1]);
            $display("#2:%x",regs[2]);
            $display("#3:%x",regs[3]);
            $display("#4:%x",regs[4]);
            $display("#5:%x",regs[5]);
            $display("#6:%x",regs[6]);
            $display("#7:%x",regs[7]);
            $display("#8:%x",regs[8]);
            $display("#9:%x",regs[9]);
            $display("#10:%x",regs[10]);
            $display("#11:%x",regs[11]);
            $display("#12:%x",regs[12]);
            $display("#13:%x",regs[13]);
            $display("#14:%x",regs[14]);
            $display("#15:%x",regs[15]);
//            $finish;
            isDisplayed = 1;
        end
    end

    // clock
    wire clk;
    clock c0(clk);

    reg isHalted = 0;

    // regs
    reg busy[0:15];
    reg [15:0]src[0:15];
    reg [15:0]regs[0:15];

    wire busy0 = busy[0];
    wire busy1 = busy[1];
    wire busy2 = busy[2];
    wire busy3 = busy[3];
    wire busy4 = busy[4];
    wire busy5 = busy[5];
    wire busy6 = busy[6];
    wire busy7 = busy[7];
    wire busy8 = busy[8];
    wire busy9 = busy[9];
    wire busy10 = busy[10];
    wire busy11 = busy[11];
    wire busy12 = busy[12];
    wire busy13 = busy[13];
    wire busy14 = busy[14];
    wire busy15 = busy[15];

    wire [5:0]src0 = src[0];
    wire [5:0]src1 = src[1];
    wire [5:0]src2 = src[2];
    wire [5:0]src3 = src[3];
    wire [5:0]src4 = src[4];
    wire [5:0]src5 = src[5];
    wire [5:0]src6 = src[6];
    wire [5:0]src7 = src[7];
    wire [5:0]src8 = src[8];
    wire [5:0]src9 = src[9];
    wire [5:0]src10 = src[10];
    wire [5:0]src11 = src[11];
    wire [5:0]src12 = src[12];
    wire [5:0]src13 = src[13];
    wire [5:0]src14 = src[14];
    wire [5:0]src15 = src[15];

    wire [15:0]regs0 = regs[0];
    wire [15:0]regs1 = regs[1];
    wire [15:0]regs2 = regs[2];
    wire [15:0]regs3 = regs[3];
    wire [15:0]regs4 = regs[4];
    wire [15:0]regs5 = regs[5];
    wire [15:0]regs6 = regs[6];
    wire [15:0]regs7 = regs[7];
    wire [15:0]regs8 = regs[8];
    wire [15:0]regs9 = regs[9];
    wire [15:0]regs10 = regs[10];
    wire [15:0]regs11 = regs[11];
    wire [15:0]regs12 = regs[12];
    wire [15:0]regs13 = regs[13];
    wire [15:0]regs14 = regs[14];
    wire [15:0]regs15 = regs[15];

    initial begin
        busy[0] <= 0;
        busy[1] <= 0;
        busy[2] <= 0;
        busy[3] <= 0;
        busy[4] <= 0;
        busy[5] <= 0;
        busy[6] <= 0;
        busy[7] <= 0;
        busy[8] <= 0;
        busy[9] <= 0;
        busy[10] <= 0;
        busy[11] <= 0;
        busy[12] <= 0;
        busy[13] <= 0;
        busy[14] <= 0;
        busy[15] <= 0;
    end

    // check the CDB to writeback values
    integer reg_i;
    always @(posedge clk) begin
        for(reg_i = 0; reg_i < 16; reg_i = reg_i + 1) begin
            if (busy[reg_i] && cdb0_v && cdb0_rs_num == src[reg_i]) begin
                busy[reg_i] <= 0;
                regs[reg_i] <= cdb0_data;
            end else
            if (busy[reg_i] && cdb1_v && cdb1_rs_num == src[reg_i]) begin
                busy[reg_i] <= 0;
                regs[reg_i] <= cdb1_data;
            end else
            if (busy[reg_i] && cdb2_v && cdb2_rs_num == src[reg_i]) begin
                busy[reg_i] <= 0;
                regs[reg_i] <= cdb2_data;
            end else
            if (busy[reg_i] && cdb3_v && cdb3_rs_num == src[reg_i]) begin
                busy[reg_i] <= 0;
                regs[reg_i] <= cdb3_data;
            end
        end
    end

    // main memory
    memcontr i0(clk,
       mem_re_f, mem_raddr_f,
       mem_re_ld, mem_raddr_ld,
       imem_ready,
       imem_raddr_out,
       imem_data_out,
       dmem_ready,
       dmem_raddr_out,
       dmem_data_out);

    wire [15:0]imem_raddr_out;
    wire [15:0]imem_data_out;
    wire imem_ready;

    wire [15:0]dmem_raddr_out;
    wire [15:0]dmem_data_out;
    wire dmem_ready;

    wire mem_re_f;
    wire [15:0]mem_raddr_f;

    wire mem_re_ld;
    wire [15:0]mem_raddr_ld;

    /////////////////////// Fetch Unit /////////////////////////////////////

    fetch f0(clk,
        ib_push, ib_push_data, ib_full,
        mem_raddr_f, mem_re_f,
        imem_raddr_out, imem_data_out, imem_ready,
        fxu0_jeqReady /*|| fxu1_jeqReady || fxu2_jeqReady*/,
        /*fxu0_jeqReady ?*/ cdb0_data[0] /*: // if a jeq is ready, read the value
        fxu1_jeqReady ? cdb1_data[0] : // from the CDB
        cdb2_data[0]*/,
        isHalted
        );

    // instr buffer
    fifo ib0(clk,
        ib_push, ib_push_data, ib_full,
        ib_pop, ib_data_out, ib_empty);

    wire ib_full, ib_empty;

    wire ib_push;
    wire [15:0]ib_push_data;

    reg ib_pop = 0;
    wire [15:0]ib_data_out;

    ///////////////////////// Dispatch /////////////////////////////////////

    // useful functions
    function cdbSatisfiesReg;
        input [3:0]r;

        assign cdbSatisfiesReg = (cdb0_v & (cdb0_rs_num == src[r]) & busy[r]) ||
                                 (cdb1_v & (cdb1_rs_num == src[r]) & busy[r]) ||
                                 (cdb2_v & (cdb2_rs_num == src[r]) & busy[r]) ||
                                 (cdb3_v & (cdb3_rs_num == src[r]) & busy[r]);
    endfunction

    function [15:0]cdbRegVal;
        input [3:0]r;

        assign cdbRegVal = (cdb0_rs_num == src[r] && cdb0_v) ? cdb0_data :
                           (cdb1_rs_num == src[r] && cdb1_v) ? cdb1_data :
                           (cdb2_rs_num == src[r] && cdb2_v) ? cdb2_data :
                            cdb3_data;
    endfunction

    // dispatch state
    reg [2:0]dstate = `DW1; // start off waiting for IB

    // decode
    wire [15:0]inst = ib_data_out;
    wire [3:0]opcode = inst[15:12];
    wire [3:0]ra = inst[11:8];
    wire [3:0]rb = inst[7:4];
    wire [3:0]rt = inst[3:0];
    wire [15:0]jjj = inst[11:0]; // zero-extended
    wire [15:0]ii = inst[11:4]; // zero-extended

    always @(posedge clk) begin
        case(dstate)
            `DP : begin // set pop flag to pop instruction
                // ib_pop should be 1 before entering this state
                // should not be in this state if IB is empty
                ib_pop <= 0;

                dstate <= `DD;
            end
            `DD : begin // normal operation
                case(opcode)
                    `HLT : begin
                        dstate <= `DH;
                    end
                    `MOV, `ADD, `JEQ : begin
                        // find needed RS and insert
                        // then update reg file
                        //
                        // formulate MOV as ADD: ii + 0
                        if (!fxu0_full) begin
                            rs[fxu0_next_rs][50] <= 1; // busy

                            rs[fxu0_next_rs][49:46] <= opcode == `MOV ? `ADD : opcode;

                            // first operand
                            rs[fxu0_next_rs][45] <= !busy[ra] |
                                cdbSatisfiesReg(ra) |
                                opcode == `MOV;
                            rs[fxu0_next_rs][43:38] <= src[ra];
                            rs[fxu0_next_rs][31:16] <= opcode == `MOV ? ii :
                                                    cdbSatisfiesReg(ra) ? cdbRegVal(ra) :
                                                    regs[ra];

                            // second operand
                            rs[fxu0_next_rs][44] <= !busy[rb] |
                                cdbSatisfiesReg(rb) |
                                opcode == `MOV;
                            rs[fxu0_next_rs][37:32] <= src[rb];
                            rs[fxu0_next_rs][15:0] <= opcode == `MOV ? 0 :
                                                   cdbSatisfiesReg(rb) ? cdbRegVal(rb) :
                                                   regs[rb];

                            // no register write by JEQ
                            if (opcode != `JEQ) begin
                                busy[rt] <= 1;
                                src[rt] <= fxu0_next_rs;
                            end

                            if (!ib_empty) begin
                                ib_pop <= 1;
                                dstate <= `DP;
                            end else begin
                                dstate <= `DW1;
                            end
                        $display("dispatch %x to %x", inst, fxu0_next_rs);
                        end else begin // wait
                            dstate <= `DW0;
                        end
                    end
                    `LD, `LDR : begin
                        // find needed RS and insert
                        // update reg file
                        //
                        // formulate LD as LDR: mem[ii + 0]

                        if (!ld0_full) begin
                            rs[ld0_next_rs][50] <= 1; // busy

                            rs[ld0_next_rs][49:46] <= `LDR;

                            rs[ld0_next_rs][45] <= !busy[ra] ||
                                cdbSatisfiesReg(ra) ||
                                opcode == `LD;
                            rs[ld0_next_rs][43:38] <= src[ra];
                            rs[ld0_next_rs][31:16] <= opcode == `LD ? ii :
                                                  cdbSatisfiesReg(ra) ? cdbRegVal(ra) :
                                                  regs[ra];

                            rs[ld0_next_rs][44] <= !busy[rb] ||
                                cdbSatisfiesReg(rb) ||
                                opcode == `LD;
                            rs[ld0_next_rs][37:32] <= src[rb];
                            rs[ld0_next_rs][15:0] <= opcode == `LD ? 0 :
                                                 cdbSatisfiesReg(rb) ? cdbRegVal(rb) :
                                                 regs[rb];

                            busy[rt] <= 1;
                            src[rt] <= ld0_next_rs;

                            if (!ib_empty) begin
                                ib_pop <= 1;
                                dstate <= `DP;
                            end else begin
                                dstate <= `DW1;
                            end
                        $display("dispatch %x", inst);
                        end else begin // wait
                            dstate <= `DW0;
                        end
                    end
                endcase
            end
            `DW0 : begin // waiting for FUs
                case(opcode)
                    `ADD, `JEQ, `MOV : begin
                        if (!fxu0_full/* || !fxu1_full || !fxu2_full*/) begin
                            dstate <= `DD;
                        end
                    end
                    `LD, `LDR : begin
                        if (!ld0_full) begin
                            dstate <= `DD;
                        end
                    end

                    default : begin
                        $display("non-blocking instruction waiting for FU");
                        $finish;
                    end
                endcase
            end
            `DW1 : begin // waiting for IB
                if (!ib_empty) begin
                    ib_pop <= 1;
                    dstate <= `DP;
                end
            end
            `DH : begin // waiting to halt
                if (!busy[0] &&
                    !busy[1] &&
                    !busy[2] &&
                    !busy[3] &&
                    !busy[4] &&
                    !busy[5] &&
                    !busy[6] &&
                    !busy[7] &&
                    !busy[8] &&
                    !busy[9] &&
                    !busy[10] &&
                    !busy[11] &&
                    !busy[12] &&
                    !busy[13] &&
                    !busy[14] &&
                    !busy[15]) begin
                    isHalted <= 1;
                end
            end

            default : begin
                $display("unknown dispatch state %d", dstate);
                $finish;
            end
        endcase
    end

    ///////////////////Reservation Stations////////////////////////////////

    // Reservation stations:
    // bits field in order
    // 1    issued
    // 1    busy
    // 4    op
    // 2    ready
    // 12   src
    // 32   val
    // -----------
    // 51   total

    // 4 reservation stations for ld: 0, 1, 2, 3
    // 4 reservation stations for fxu: 4, 5, 6, 7
    reg [51:0]rs[0:7];

    wire [51:0]rs0 = rs[0];
    wire [51:0]rs1 = rs[1];
    wire [51:0]rs2 = rs[2];
    wire [51:0]rs3 = rs[3];
    wire [51:0]rs4 = rs[4];
    wire [51:0]rs5 = rs[5];
    wire [51:0]rs6 = rs[6];
    wire [51:0]rs7 = rs[7];

    initial begin
        for (rsn = 0 ; rsn < 8; rsn = rsn + 1) begin
            rs[rsn] <= 0;
        end
    end

    //function `ISSUED;
    //    input [5:0]rs_num;

    //    `ISSUED = rs[rs_num][51];
    //endfunction

    //function `BUSY;
    //    input [5:0]rs_num;

    //    `BUSY = rs[rs_num][50];
    //endfunction

    //function [3:0]`OP;
    //    input [5:0]rs_num;

    //    `OP = rs[rs_num][49:46];
    //endfunction

    // 2 params: which src, which rs
    //function `READY;
    //    input [5:0]rs_num;
    //    input which; // 1 = src1, 0 = src0

    //    `READY = !which ? rs[rs_num][45] : rs[rs_num][44];
    //endfunction

    //function [5:0]`SRC;
    //    input [5:0]rs_num;
    //    input which; // 1 = src1, 0 = src0

    //    `SRC = !which ? rs[rs_num][43:38] : rs[rs_num][37:32];
    //endfunction

    //function [15:0]`VAL;
    //    input [5:0]rs_num;
    //    input which; // 1 = src1, 0 = src0

    //    `VAL = !which ? rs[rs_num][31:16] : rs[rs_num][15:0];
    //endfunction

    function cdbSatisfiesRs;
        input [5:0]rs_num;
        input [1:0]cdb_num;
        input which;

        cdbSatisfiesRs = cdbIsValid(cdb_num) && !`READY(rs_num, which) &&
                        cdbRsNum(cdb_num) == `SRC(rs_num, which);
    endfunction

    function readyToIssue;
        input [5:0]rs_num;

        readyToIssue = `BUSY(rs_num) &&
            `READY(rs_num, 0) &&
            `READY(rs_num, 1) &&
            !`ISSUED(rs_num);
    endfunction

    // check CDB
    integer rsn;//rs#n
    integer cdbn; //cdb#n
    always @(posedge clk) begin
        for (rsn = 0 ; rsn < 8; rsn = rsn + 1) begin
            if (`BUSY(rsn)) begin
                for(cdbn = 0; cdbn < 4; cdbn = cdbn + 1) begin
                    if(cdbIsValid(cdbn) && cdbRsNum(cdbn) == rsn) begin
                        rs[rsn][50] <= 0; // not busy
                        rs[rsn][51] <= 0; // not issued
                    end
                    if(cdbSatisfiesRs(rsn, cdbn, 0)) begin
                        rs[rsn][45] <= 1;
                        rs[rsn][31:16] <= cdbData(cdbn);
                    end
                    if(cdbSatisfiesRs(rsn, cdbn, 1)) begin
                        rs[rsn][44] <= 1;
                        rs[rsn][15:0] <= cdbData(cdbn);
                    end
                end
            end
        end

        if (!fxu0_busy) begin
            if (readyToIssue(4)) begin
                fxu0_rs_ready <= 1;
                fxu0_ready_rs_num <= 4;
                fxu0_op <= `OP(4);
                fxu0_val0 <= `VAL(4,0);
                fxu0_val1 <= `VAL(4,1);
                rs[4][51] <= 1;
            end else if (readyToIssue(5)) begin
                fxu0_rs_ready <= 1;
                fxu0_ready_rs_num <= 5;
                fxu0_op <= `OP(5);
                fxu0_val0 <= `VAL(5,0);
                fxu0_val1 <= `VAL(5,1);
                rs[5][51] <= 1;
            end else if (readyToIssue(6)) begin
                fxu0_rs_ready <= 1;
                fxu0_ready_rs_num <= 6;
                fxu0_op <= `OP(6);
                fxu0_val0 <= `VAL(6,0);
                fxu0_val1 <= `VAL(6,1);
                rs[6][51] <= 1;
            end else if (readyToIssue(7)) begin
                fxu0_rs_ready <= 1;
                fxu0_ready_rs_num <= 7;
                fxu0_op <= `OP(7);
                fxu0_val0 <= `VAL(7,0);
                fxu0_val1 <= `VAL(7,1);
                rs[7][51] <= 1;
            end else begin
                fxu0_rs_ready <= 0;
            end
        end else begin
            fxu0_rs_ready <= 0;
        end

        if (!ld0_busy) begin
            if (readyToIssue(0)) begin
                ld0_rs_ready <= 1;
                ld0_ready_rs_num <= 0;
                ld0_raddr <= `VAL(0,0) + `VAL(0,1);
                rs[0][51] <= 1;
            end else if (readyToIssue(1)) begin
                ld0_rs_ready <= 1;
                ld0_ready_rs_num <= 1;
                ld0_raddr <= `VAL(1,0) + `VAL(1,1);
                rs[1][51] <= 1;
            end else if (readyToIssue(2)) begin
                ld0_rs_ready <= 1;
                ld0_ready_rs_num <= 2;
                ld0_raddr <= `VAL(2,0) + `VAL(2,1);
                rs[2][51] <= 1;
            end else if (readyToIssue(3)) begin
                ld0_rs_ready <= 1;
                ld0_ready_rs_num <= 3;
                ld0_raddr <= `VAL(3,0) + `VAL(3,1);
                rs[3][51] <= 1;
            end else begin
                ld0_rs_ready <= 0;
            end
        end else begin
            ld0_rs_ready <= 0;
        end

    end

    ////////////////////// FUs /////////////////////////////////////////////
    // 3 FXUs
    // 1 LD

    fxu fxu0(clk,
        fxu0_rs_ready, fxu0_ready_rs_num, fxu0_op,
        fxu0_val0, fxu0_val1,

        cdb0_v, cdb0_rs_num, cdb0_data,

        fxu0_jeqReady,

        fxu0_busy
    );

    reg       fxu0_rs_ready = 0;
    reg  [5:0]fxu0_ready_rs_num;
    reg  [3:0]fxu0_op;
    reg [15:0]fxu0_val0, fxu0_val1;

    wire      fxu0_jeqReady;
    wire      fxu0_busy;

    wire fxu0_full = `BUSY(4) && `BUSY(5) && `BUSY(6) && `BUSY(7);
    wire [5:0]fxu0_next_rs = !`BUSY(4) ? 4 :
                       !`BUSY(5) ? 5 :
                       !`BUSY(6) ? 6 : 7;


    ld ld0(clk,
        ld0_rs_ready, ld0_ready_rs_num, ld0_raddr,

        cdb3_v, cdb3_rs_num, cdb3_data,

        mem_raddr_ld, mem_re_ld,
        dmem_raddr_out, dmem_data_out, dmem_ready,

        ld0_busy
    );

    reg       ld0_rs_ready = 0;
    reg  [5:0]ld0_ready_rs_num;
    reg [15:0]ld0_raddr;

    wire ld0_busy;

    wire ld0_full = `BUSY(0) && `BUSY(1) && `BUSY(2) && `BUSY(3);
    wire [5:0]ld0_next_rs = !`BUSY(0) ? 0 :
                      !`BUSY(1) ? 1 :
                      !`BUSY(2) ? 2 : 3;

    ////////////////////// CDB /////////////////////////////////////////////

    wire cdb0_v, cdb3_v;
    reg cdb1_v = 0, cdb2_v = 0;

    wire [5:0]cdb0_rs_num, cdb1_rs_num, cdb2_rs_num, cdb3_rs_num;
    wire [15:0]cdb0_data, cdb1_data, cdb2_data, cdb3_data;

    // useful functions
    function cdbIsValid;
        input [1:0]cdb_num;

        case(cdb_num)
            0 : begin
                cdbIsValid = cdb0_v;
            end
            1 : begin
                cdbIsValid = cdb1_v;
            end
            2 : begin
                cdbIsValid = cdb2_v;
            end
            3 : begin
                cdbIsValid = cdb3_v;
            end
        endcase
    endfunction

    function [5:0]cdbRsNum;
        input [1:0]cdb_num;

        case(cdb_num)
            0 : begin
                cdbRsNum = cdb0_rs_num;
            end
            1 : begin
                cdbRsNum = cdb1_rs_num;
            end
            2 : begin
                cdbRsNum = cdb2_rs_num;
            end
            3 : begin
                cdbRsNum = cdb3_rs_num;
            end
        endcase
    endfunction

    function [15:0]cdbData;
        input [1:0]cdb_num;

        case(cdb_num)
            0 : begin
                cdbData = cdb0_data;
            end
            1 : begin
                cdbData = cdb1_data;
            end
            2 : begin
                cdbData = cdb2_data;
            end
            3 : begin
                cdbData = cdb3_data;
            end
        endcase
    endfunction

endmodule
