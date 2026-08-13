`include "gba/util/logger.svh"

import gba_types_pkg::*;
import gba_cpu_types_pkg::*;

module ALU (
    input clk,
    input reset,
    GBA_ALU_if.ALU_side bus,
    GBA_Shifter_if.ALU_side shifter_bus
);

  word_t op_b_latch;

  wire [31:0] op_b = bus.use_op_b_latch ? op_b_latch : (bus.disable_op_b ? 32'h0 : shifter_bus.op_b);

  always_comb begin
    if (bus.use_op_b_latch) begin
      `LOG_TRACE(("[ALU] Using latched result 0x%08x", op_b_latch))
    end
  end

  wire carry_in = shifter_bus.carry_out;

  always_ff @(posedge clk) begin
    if (reset) begin
      op_b_latch <= 32'h0;
    end else begin
      `LOG_TRACE((
          "[ALU] op=%s, latch_op_b=%b, use_op_b_latch=%b, disable_op_b=%b, op_a=%0d, op_b=%0d, result=%0d",
          bus.alu_op.name(), bus.latch_op_b, bus.use_op_b_latch, bus.disable_op_b, bus.op_a, op_b,
          bus.result))

      if (bus.latch_op_b) begin
        op_b_latch <= shifter_bus.op_b;
      end
    end
  end

  logic [32:0] temp;

  always_comb begin
    // Defaults
    bus.result = 32'h0;
    bus.flags_out.n = bus.flags_in.n;
    bus.flags_out.z = bus.flags_in.z;
    bus.flags_out.c = bus.flags_in.c;
    bus.flags_out.v = bus.flags_in.v;

    `LOG_TRACE(("ALU operation: op_a=0x%08x op_b=0x%08x alu_op=%s carry_in=%b, bus.result=0x%08x",
             bus.op_a, op_b, bus.alu_op.name(), carry_in, bus.result))

    temp = 33'h0;

    unique case (bus.alu_op)

      ALU_OP_MOV: begin
        bus.result = op_b;
        bus.flags_out.c = shifter_bus.carry_out;
      end

      ALU_OP_NOT: begin
        bus.result = ~op_b;
        bus.flags_out.c = shifter_bus.carry_out;
      end

      ALU_OP_AND, ALU_OP_TEST: begin
        bus.result = bus.op_a & op_b;
        bus.flags_out.c = shifter_bus.carry_out;
      end

      ALU_OP_XOR, ALU_OP_TEST_EXCLUSIVE: begin
        bus.result = bus.op_a ^ op_b;
        bus.flags_out.c = shifter_bus.carry_out;
      end

      ALU_OP_OR: begin
        bus.result = bus.op_a | op_b;
        bus.flags_out.c = shifter_bus.carry_out;
      end

      ALU_OP_BIT_CLEAR: begin
        bus.result = bus.op_a & ~op_b;
        bus.flags_out.c = shifter_bus.carry_out;
      end

      ALU_OP_ADD, ALU_OP_CMP_NEG: begin
        temp = {1'b0, bus.op_a} + {1'b0, op_b};
        bus.result = temp[31:0];
        bus.flags_out.c = temp[32];
        bus.flags_out.v = ~(bus.op_a[31] ^ op_b[31]) & (bus.op_a[31] ^ bus.result[31]);
      end

      ALU_OP_ADC: begin
        temp = {1'b0, bus.op_a} + {1'b0, op_b} + {32'b0, bus.flags_in.c};
        bus.result = temp[31:0];
        bus.flags_out.c = temp[32];
        bus.flags_out.v = ~(bus.op_a[31] ^ op_b[31]) & (bus.op_a[31] ^ bus.result[31]);
      end

      ALU_OP_SUB, ALU_OP_CMP: begin
        temp = {1'b0, bus.op_a} - {1'b0, op_b};
        bus.result = temp[31:0];
        bus.flags_out.c = ~temp[32];  // NOT borrow
        bus.flags_out.v = (bus.op_a[31] ^ op_b[31]) & (bus.op_a[31] ^ bus.result[31]);
      end

      ALU_OP_SBC: begin
        temp = {1'b0, bus.op_a} - {1'b0, op_b} - {32'b0, ~bus.flags_in.c};
        bus.result = temp[31:0];
        bus.flags_out.c = ~temp[32];
        bus.flags_out.v = (bus.op_a[31] ^ op_b[31]) & (bus.op_a[31] ^ bus.result[31]);
      end

      ALU_OP_SUB_REVERSED: begin
        temp = {1'b0, op_b} - {1'b0, bus.op_a};
        bus.result = temp[31:0];
        bus.flags_out.c = ~temp[32];
        bus.flags_out.v = (bus.op_a[31] ^ op_b[31]) & (op_b[31] ^ bus.result[31]);
      end

      ALU_OP_SBC_REVERSED: begin
        temp = {1'b0, op_b} - {1'b0, bus.op_a} - {32'b0, ~bus.flags_in.c};
        bus.result = temp[31:0];
        bus.flags_out.c = ~temp[32];
        bus.flags_out.v = (bus.op_a[31] ^ op_b[31]) & (op_b[31] ^ bus.result[31]);
      end

    endcase

    bus.flags_out.n = bus.result[31];
    bus.flags_out.z = (bus.result == 32'h0);
  end


endmodule : ALU
