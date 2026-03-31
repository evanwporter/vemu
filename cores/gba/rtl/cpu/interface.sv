import gba_types_pkg::*;
import gba_cpu_types_pkg::*;
import gba_cpu_decoder_types_pkg::*;

interface GBA_Decoder_if (
    input word_t IR,
    input execution_mode_t execution_mode,
    input flags_t flags
);

  logic enable;
  decoded_word_t word;

  decoded_regs_t decoded_regs;

  logic pipeline_advance;

  arm_instr_t instr_type;

  // Bits 31-28
  /// Whether the condition code check passed and the 
  /// instruction should be executed. This is computed in 
  /// the Decoder and used in the Control Unit to determine 
  /// whether to execute the instruction or treat it as a NOP.
  logic condition_pass;

  modport Decoder_side(
      input IR, flags, pipeline_advance, execution_mode,
      output word, condition_pass, instr_type, decoded_regs
  );

  modport ControlUnit_side(
      input word, decoded_regs, condition_pass, instr_type,
      output pipeline_advance
  );

endinterface : GBA_Decoder_if

interface GBA_ALU_if (
    input word_t op_a
);

  /// Whether to latch the B_bus value into the ALU for use in the next cycle
  logic latch_op_b;

  /// Whether to use the latched B_bus value in the ALU for the current cycle
  /// This is used for times when I just want to let the a op pass through the ALU 
  /// unchanged.
  logic use_op_b_latch;

  /// Whether to use the B_bus value in the ALU for the current cycle
  /// If false, then regardless of what the B_bus value is, the ALU will use zero as its B operand
  logic disable_op_b;

  alu_op_t alu_op;

  flags_t flags_in;

  word_t result;
  flags_t flags_out;

  modport ALU_side(
      input op_a, alu_op, flags_in, use_op_b_latch, disable_op_b, latch_op_b,
      output result, flags_out
  );
endinterface : GBA_ALU_if

interface GBA_Shifter_if (
    input word_t R_in
);

  /// Shift amount (0–31)
  logic [4:0] shift_amount;

  /// Signal to latch the shift amount from the Rs register
  logic shift_latch_amt;

  /// Signal to use the latched shift amount
  logic shift_use_latch;

  logic shift_use_rxx;

  shift_type_t shift_type;
  logic carry_in;  // CPSR.C 

  word_t op_b;
  logic carry_out;

  modport shifter_side(
      input R_in,
      input shift_amount,
      input shift_type,
      input carry_in,
      input shift_latch_amt,
      input shift_use_latch,
      input shift_use_rxx,
      output op_b,
      output carry_out
  );

  modport ALU_side(input op_b, input carry_out);

endinterface : GBA_Shifter_if

interface GBA_Multiplier_if (
    input word_t A_bus,
    input word_t B_bus
);

  logic enable;
  word_t result;

  multiply_opcode_t opcode;

  struct packed {
    logic N;
    logic Z;
  } flags;

  modport Multiplier_side(input A_bus, B_bus, enable, opcode, output result, flags);

endinterface : GBA_Multiplier_if
