import gba_control_types_pkg::*;
import gba_cpu_types_pkg::*;
import gba_cpu_decoder_types_pkg::*;

package decoder_util_pkg;

  localparam alu_op_t THUMB_ALU_LUT[0:15] = '{
      ALU_OP_AND,  // 0x0
      ALU_OP_XOR,  // 0x1
      ALU_OP_MOV,  // 0x2 (LSL uses MOV w/ shift)
      ALU_OP_MOV,  // 0x3 (LSR)
      ALU_OP_MOV,  // 0x4 (ASR)
      ALU_OP_ADC,  // 0x5
      ALU_OP_SBC,  // 0x6
      ALU_OP_MOV,  // 0x7 (ROR)
      ALU_OP_TEST,  // 0x8
      ALU_OP_SUB_REVERSED,  // 0x9 (NEG)
      ALU_OP_CMP,  // 0xA
      ALU_OP_CMP_NEG,  // 0xB (CMN)
      ALU_OP_OR,  // 0xC
      ALU_OP_AND,  // 0xD (NONE)
      ALU_OP_BIT_CLEAR,  // 0xE
      ALU_OP_NOT  // 0xF
  };

  localparam shift_type_t THUMB_SHIFT_LUT[0:15] = '{
      SHIFT_LSL,  // 0
      SHIFT_LSL,  // 1
      SHIFT_LSL,  // 2
      SHIFT_LSR,  // 3
      SHIFT_ASR,  // 4
      SHIFT_LSL,  // 5
      SHIFT_LSL,  // 6
      SHIFT_ROR,  // 7
      SHIFT_LSL,  // 8
      SHIFT_LSL,  // 9; NONE
      SHIFT_LSL,  // A
      SHIFT_LSL,  // B
      SHIFT_LSL,  // C
      SHIFT_LSL,  // D; NONE
      SHIFT_LSL,  // E
      SHIFT_LSL  // F
  };
endpackage : decoder_util_pkg
