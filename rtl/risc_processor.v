module top_module(
    input clk,
    input rst
    );

    // --- IF STAGE ---
    wire [31:0] pc_out, pc_next, instruction;
    wire pc_write;

    PC p1 (
        .clk(clk),
        .rst(rst),
        .write_en(pc_write),
        .pc_in(pc_next),
        .pc_out(pc_out)
    );

    PC_adder pa1 (
        .pc_current(pc_out),
        .pc_next(pc_next)
    );

    IM i1 (
        .pc_current(pc_out),
        .instruction(instruction)
    );

    // --- IF/ID PIPELINE REGISTER ---
    wire [31:0] if_id_instr;
    wire if_id_write;

    IF_ID ifid (
        .clk(clk),
        .rst(rst),
        .write_en(if_id_write),
        .instruction(instruction),
        .data(if_id_instr)
    );

    // --- ID STAGE ---
    wire [3:0] id_opcode;
    wire [3:0] id_wn;
    wire [3:0] id_rn1;
    wire [3:0] id_rn2;
    wire [15:0] id_imm;

    assign id_opcode = if_id_instr[31:28];
    assign id_wn     = if_id_instr[27:24];
    assign id_rn1    = if_id_instr[23:20];
    assign id_rn2    = if_id_instr[19:16];
    assign id_imm    = if_id_instr[15:0];

    // Hazard Detection Logic
    // No load instruction exists in the current ISA, so MemRead is tied low.
    wire stall_mux_ctrl;

    HazardDetection haz_det (
        .id_ex_memread(1'b0),
        .id_ex_rt(idex_out[107:104]),
        .if_id_rs(id_rn1),
        .if_id_rt(id_rn2),
        .pc_write(pc_write),
        .if_id_write(if_id_write),
        .stall_mux_ctrl(stall_mux_ctrl)
    );

    // --- REGISTER FILE ---
    wire [31:0] data1, data2;
    wire [39:0] mem_wb_reg;
    wire [3:0] wb_opcode;

    assign wb_opcode = mem_wb_reg[35:32];

    // RegWrite: AND, ORI, NOR
    wire RegWrite_WB;

    assign RegWrite_WB =
        (wb_opcode == 4'b0000) ||
        (wb_opcode == 4'b0001) ||
        (wb_opcode == 4'b1111);

    RM r1 (
        .clk(clk),
        .rst(rst),
        .rs(id_rn1),
        .rt(id_rn2),
        .rd(mem_wb_reg[39:36]),
        .regwrite(RegWrite_WB),
        .write_data(mem_wb_reg[31:0]),
        .data1(data1),
        .data2(data2)
    );

    wire [31:0] sign_xtended;

    sign_extend s1 (
        .data_16(id_imm),
        .data_32(sign_xtended)
    );

    // --- ID/EX PIPELINE REGISTER ---
    wire [111:0] idex_out;

    ID_EX idex (
        .clk(clk),
        .rst(rst),
        .flush(stall_mux_ctrl),
        .rs(id_rn1),
        .rt(id_rn2),
        .rd(id_wn),
        .opcode(id_opcode),
        .data1(data1),
        .data2(data2),
        .sign_xtended(sign_xtended),
        .idex_data(idex_out)
    );

    // --- EX STAGE ---
    wire [3:0] ex_opcode;
    wire [1:0] forward_A, forward_B;

    assign ex_opcode = idex_out[99:96];

    ForwardingUnit fwd (
        .id_ex_rs(idex_out[111:108]),
        .id_ex_rt(idex_out[107:104]),
        .ex_mem_dest(exmem_out[72:69]),
        .ex_mem_opcode(exmem_out[68:65]),
        .mem_wb_dest(mem_wb_reg[39:36]),
        .mem_wb_opcode(wb_opcode),
        .forward_A(forward_A),
        .forward_B(forward_B)
    );

    // Forwarding multiplexers
    reg [31:0] alu_in_1;
    reg [31:0] forwarded_B_val;

    always @(*) begin
        case (forward_A)
            2'b10:   alu_in_1 = exmem_out[64:33];
            2'b01:   alu_in_1 = mem_wb_reg[31:0];
            default: alu_in_1 = idex_out[95:64];
        endcase

        case (forward_B)
            2'b10:   forwarded_B_val = exmem_out[64:33];
            2'b01:   forwarded_B_val = mem_wb_reg[31:0];
            default: forwarded_B_val = idex_out[63:32];
        endcase
    end

    // ALUSrc: immediate for ORI and store-style instructions
    wire ALUSrc_EX;

    assign ALUSrc_EX =
        (ex_opcode == 4'b0100) ||
        (ex_opcode == 4'b0010) ||
        (ex_opcode == 4'b0001);

    wire [31:0] alu_in_2;

    assign alu_in_2 = ALUSrc_EX ? idex_out[31:0] : forwarded_B_val;

    wire [31:0] alu_result;
    wire alu_zero;

    ALU a1 (
        .in_1(alu_in_1),
        .in_2(alu_in_2),
        .alu_op(ex_opcode),
        .out(alu_result),
        .zero(alu_zero)
    );

    // --- EX/MEM PIPELINE REGISTER ---
    // [72:69] rd
    // [68:65] opcode
    // [64:33] ALU result
    // [32:1]  store data
    // [0]     zero
    wire [72:0] exmem_out;

    EX_MEM e1 (
        .clk(clk),
        .rst(rst),
        .rd(idex_out[103:100]),
        .opcode(ex_opcode),
        .alu_out(alu_result),
        .data_2(forwarded_B_val),
        .zero_in(alu_zero),
        .data_out(exmem_out)
    );

    // --- MEM STAGE ---
    wire [3:0] mem_opcode;
    wire MemWrite_MEM;

    assign mem_opcode = exmem_out[68:65];

    assign MemWrite_MEM =
        (mem_opcode == 4'b0100) ||
        (mem_opcode == 4'b0010);

    data_mem d1 (
        .clk(clk),
        .address(exmem_out[64:33]),
        .data(exmem_out[32:1]),
        .memwrite(MemWrite_MEM)
    );

    // --- WB STAGE ---
    mem_wb m1 (
        .clk(clk),
        .rst(rst),
        .rd(exmem_out[72:69]),
        .opcode(mem_opcode),
        .alu_out(exmem_out[64:33]),
        .data_o(mem_wb_reg)
    );

endmodule


module PC(
    input clk,
    input rst,
    input write_en,
    input [31:0] pc_in,
    output reg [31:0] pc_out
);

    always @(posedge clk) begin
        if (rst)
            pc_out <= 32'b0;
        else if (write_en)
            pc_out <= pc_in;
    end

endmodule


module PC_adder(
    input [31:0] pc_current,
    output [31:0] pc_next
);

    assign pc_next = pc_current + 32'd4;

endmodule


module IM(
    input [31:0] pc_current,
    output reg [31:0] instruction
);

    // Small combinational ROM
    always @(*) begin
        case (pc_current[4:2])
            3'd0: instruction = 32'h01230000; // AND R1,R2,R3
            3'd1: instruction = 32'h40510000; // SW R1,0(R5)
            3'd2: instruction = 32'h2051000C; // SW R1,12(R5)
            3'd3: instruction = 32'h1710162D; // ORI R7,R1,0x162D
            3'd4: instruction = 32'hF8790000; // NOR R8,R7,R9
            default: instruction = 32'b0;
        endcase
    end

endmodule


module IF_ID(
    input clk,
    input rst,
    input write_en,
    input [31:0] instruction,
    output reg [31:0] data
);

    always @(posedge clk) begin
        if (rst)
            data <= 32'b0;
        else if (write_en)
            data <= instruction;
    end

endmodule


module HazardDetection(
    input id_ex_memread,
    input [3:0] id_ex_rt,
    input [3:0] if_id_rs,
    input [3:0] if_id_rt,
    output reg pc_write,
    output reg if_id_write,
    output reg stall_mux_ctrl
);

    always @(*) begin
        if (id_ex_memread &&
            ((id_ex_rt == if_id_rs) || (id_ex_rt == if_id_rt))) begin
            pc_write       = 1'b0;
            if_id_write    = 1'b0;
            stall_mux_ctrl = 1'b1;
        end
        else begin
            pc_write       = 1'b1;
            if_id_write    = 1'b1;
            stall_mux_ctrl = 1'b0;
        end
    end

endmodule


module RM(
    input clk,
    input rst,
    input [3:0] rs,
    input [3:0] rt,
    input [3:0] rd,
    input regwrite,
    input [31:0] write_data,
    output [31:0] data1,
    output [31:0] data2
);

    reg [31:0] reg_data [0:15];
    integer i;

    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 16; i = i + 1)
                reg_data[i] <= 32'b0;

            reg_data[2] <= 32'h0001234A;
            reg_data[3] <= 32'h000A1234;
            reg_data[5] <= 32'h00000016;
            reg_data[9] <= 32'h000B1234;
        end
        else if (regwrite && (rd != 4'b0000)) begin
            reg_data[rd] <= write_data;
        end
    end

    assign data1 = reg_data[rs];
    assign data2 = reg_data[rt];

endmodule


module sign_extend(
    input [15:0] data_16,
    output [31:0] data_32
);

    assign data_32 = {{16{data_16[15]}}, data_16};

endmodule


module ID_EX(
    input clk,
    input rst,
    input flush,
    input [3:0] rs,
    input [3:0] rt,
    input [3:0] rd,
    input [3:0] opcode,
    input [31:0] data1,
    input [31:0] data2,
    input [31:0] sign_xtended,
    output reg [111:0] idex_data
);

    always @(posedge clk) begin
        if (rst || flush)
            idex_data <= 112'b0;
        else
            idex_data <= {
                rs,
                rt,
                rd,
                opcode,
                data1,
                data2,
                sign_xtended
            };
    end

endmodule


module ForwardingUnit(
    input [3:0] id_ex_rs,
    input [3:0] id_ex_rt,
    input [3:0] ex_mem_dest,
    input [3:0] ex_mem_opcode,
    input [3:0] mem_wb_dest,
    input [3:0] mem_wb_opcode,
    output reg [1:0] forward_A,
    output reg [1:0] forward_B
);

    wire ex_mem_regwrite =
        (ex_mem_opcode == 4'b0000) ||
        (ex_mem_opcode == 4'b0001) ||
        (ex_mem_opcode == 4'b1111);

    wire mem_wb_regwrite =
        (mem_wb_opcode == 4'b0000) ||
        (mem_wb_opcode == 4'b0001) ||
        (mem_wb_opcode == 4'b1111);

    always @(*) begin
        forward_A = 2'b00;
        forward_B = 2'b00;

        if (ex_mem_regwrite && (ex_mem_dest != 4'b0000)) begin
            if (ex_mem_dest == id_ex_rs)
                forward_A = 2'b10;
            if (ex_mem_dest == id_ex_rt)
                forward_B = 2'b10;
        end

        if (mem_wb_regwrite && (mem_wb_dest != 4'b0000)) begin
            if ((mem_wb_dest == id_ex_rs) &&
                (forward_A != 2'b10))
                forward_A = 2'b01;

            if ((mem_wb_dest == id_ex_rt) &&
                (forward_B != 2'b10))
                forward_B = 2'b01;
        end
    end

endmodule


module ALU(
    input [31:0] in_1,
    input [31:0] in_2,
    input [3:0] alu_op,
    output reg [31:0] out,
    output zero
);

    assign zero = (out == 32'b0);

    always @(*) begin
        case (alu_op)
            4'b0000: out = in_1 & in_2;
            4'b0100,
            4'b0010: out = in_1 + in_2;
            4'b0001: out = in_1 | in_2;
            4'b1111: out = ~(in_1 | in_2);
            default: out = 32'b0;
        endcase
    end

endmodule


module EX_MEM(
    input clk,
    input rst,
    input [3:0] rd,
    input [3:0] opcode,
    input [31:0] alu_out,
    input [31:0] data_2,
    input zero_in,
    output reg [72:0] data_out
);

    always @(posedge clk) begin
        if (rst)
            data_out <= 73'b0;
        else
            data_out <= {rd, opcode, alu_out, data_2, zero_in};
    end

endmodule


module data_mem(
    input clk,
    input [31:0] address,
    input [31:0] data,
    input memwrite
);

    reg [31:0] d_mem [0:34];

    always @(posedge clk) begin
        if (memwrite && (address[31:2] < 30'd35))
            d_mem[address[31:2]] <= data;
    end

endmodule


module mem_wb(
    input clk,
    input rst,
    input [3:0] rd,
    input [3:0] opcode,
    input [31:0] alu_out,
    output reg [39:0] data_o
);

    always @(posedge clk) begin
        if (rst)
            data_o <= 40'b0;
        else
            data_o <= {rd, opcode, alu_out};
    end

endmodule
