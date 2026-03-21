import gba_types_pkg::*;
import gba_cpu_types_pkg::*;

package gba_cpu_decoder_types_pkg;

  typedef enum logic {
    ARM_LDR_STR_WORD,
    ARM_LDR_STR_BYTE
  } bit_length_flag_t;

  /// TODO verify order
  typedef enum logic {
    /// Immediate Offset
    /// Offset it by an immediate value encoded in the instruction
    ARM_LDR_STR_IMMEDIATE,

    /// Shifted Register Offset
    /// Offset it by a register value (Rm)
    ARM_LDR_STR_REGISTER
  } mem_offset_flag_t;

  typedef enum logic {
    ARM_LDR_STR_POST_OFFSET,
    ARM_LDR_STR_PRE_OFFSET
  } pre_post_offset_flag_t;

  typedef enum logic [1:0] {
    ARM_LOAD_STORE_INVALID = 2'd0,
    ARM_LOAD_STORE_HALFWORD = 2'd1,
    ARM_LOAD_SIGNED_BYTE = 2'd2,
    ARM_LOAD_SIGNED_HALFWORD = 2'd3
  } signed_halfword_flag_t;

  typedef enum logic [3:0] {
    /// Multiply
    ARM_MUL = 4'b0000,

    /// Multiply and Accumulate
    ARM_MLA = 4'b0001,

    /// Unsigned Multiply Long
    ARM_UMULL = 4'b0100,

    /// Unsigned Multiply Long Accumulate
    ARM_UMLAL = 4'b0101,

    /// Signed Multiply Long
    ARM_SMULL = 4'b0110,

    /// Signed Multiply Long Accumulate
    ARM_SMLAL = 4'b0111
  } multiply_opcode_t;

  // TODO: make into a union
  typedef union packed {

    // ======================================================
    // Data Processing
    // ======================================================

    /// Data Processing Immediate (ARM_INSTR_DATAPROC_IMM)
    struct packed {
      logic [4:0] _pad;

      // Required for thumb
      logic align_flag;

      logic use_lsl;

      // Bits 24-21
      alu_op_t opcode;

      // Bit 20
      logic set_flags;

      // Bits 11-8
      logic [3:0] rotate;

      // Bits 7-0
      logic [7:0] imm8;
    } data_proc_imm;

    /// Data Processing Register Immediate Shift (ARM_INSTR_DATAPROC_REG_IMM)
    struct packed {
      logic [11:0] _pad;

      // Bits 24-21
      alu_op_t opcode;

      // Bit 20
      logic set_flags;

      // Bits 11-7
      logic [4:0] shift_amount;

      // Bits 6-5
      shift_type_t shift_type;
    } data_proc_reg_imm;

    /// Data Processing Register Register Shift (ARM_INSTR_DATAPROC_REG_REG)
    struct packed {
      logic [16:0] _pad;

      // Bits 24-21
      alu_op_t opcode;

      // Bit 20
      logic set_flags;

      // Bits 11-8
      // The rotate amount is stored wholly within Rs
      // logic [3:0] rotate;

      // Bits 6-5
      shift_type_t shift_type;
    } data_proc_reg_reg;


    // ======================================================
    // Single Data Transfer (Word / Byte)
    // ======================================================

    /// ARM_INSTR_LOAD / ARM_INSTR_STORE
    struct packed {
      logic [5:0] _pad;

      // Some THUMB instructions involving the use of PC require PC 
      // to be word-aligned
      logic align_flag;

      // Bit 25
      mem_offset_flag_t I;

      // Bit 24
      pre_post_offset_flag_t P;

      // Bit 23
      logic U;

      // Byte / Word bit (0=transfer 32bit/word, 1=transfer 8bit/byte)
      // Bit 22
      bit_length_flag_t B;

      // Bit 21
      logic wt;

      // Rn
      // Rd

      union packed {

        struct packed {
          logic [4:0] _pad;

          // Bits 11-7
          logic [4:0] shift_amount;

          // Bits 6-5
          shift_type_t shift_type;
        } shifted;

        logic [11:0] imm12;
      } offset;

      // Uses Rm as offset register
    } ls;

    // ======================================================
    // Single Data Transfer (Doubleword / Halfword)
    // ======================================================

    /// ARM_INSTR_LOAD / ARM_INSTR_STORE
    struct packed {
      logic [9:0] _pad;

      // Bit 24
      pre_post_offset_flag_t P;

      // Bit 23
      logic U;

      // Bit 22
      logic I;

      /// Writeback flag
      // Bit 21
      logic W;

      logic [7:0] imm_offset;

      // Rn
      // Rd

      signed_halfword_flag_t opcode;

      // Uses Rm as offset register
    } ls_half;

    struct packed {
      logic [22:0] _pad;

      // Bits 22
      bit_length_flag_t B;
    } swap;

    // ======================================================
    // Block Data Transfer
    // ======================================================

    /// ARM_INSTR_LDM / ARM_INSTR_STM
    // https://mgba-emu.github.io/gbatek/#opcode-format-5
    struct packed {
      logic [2:0] _pad;

      logic force_no_align_pc;

      // Bit 24
      pre_post_offset_flag_t P;

      // Bit 23
      logic U;

      // PSR & force user bit (0=No, 1=load PSR or force user mode)
      // Bit 22
      logic S;

      // Bit 21
      // Writeback bit (1) writeback; (0) no writeback
      logic W;

      // Bits 15-0
      logic [15:0] reg_list;
    } block;


    // ======================================================
    // Branch
    // ======================================================

    /// ARM_INSTR_BRANCH / ARM_INSTR_BRANCH_LINK
    struct packed {
      // Bits 23-0
      logic [23:0] imm24;
    } branch;


    // ======================================================
    // PSR Transfer
    // ======================================================

    /// MSR (immediate form)
    struct packed {
      logic [11:0] _pad;

      // Bits 11-8
      logic [3:0] rotate;

      // Bits 7-0
      logic [7:0] imm8;
    } psr_imm;


    // ======================================================
    // Software Interrupt
    // ======================================================

    /// ARM_INSTR_SWI
    struct packed {
      // Bits 23-0
      logic [23:0] comment;
    } swi;

    // ======================================================
    // Multiply
    // ======================================================

    struct packed {
      logic [18:0] _pad;

      /// Set condition flags
      logic S;

      // Bits 24-21
      multiply_opcode_t opcode;
    } mul;
  } arm_t;

  typedef union packed {
    struct packed {
      logic [16:0] _pad;
      shift_type_t shift_type;
      logic [4:0]  offset;
    } shifted;
  } thumb_t;

  typedef union packed {
    arm_t   arm;
    thumb_t thumb;
  } decoded_word_t;

  typedef struct packed {
    // ARM: Bits 15-12
    // THUMB: 2-0
    logic [3:0] Rd;

    // ARM: Bits 19-16
    // THUMB: 8-6 (aka Ro)
    logic [3:0] Rn;

    // Bits 3-0
    logic [3:0] Rm;

    // ARM: Bits 11-8
    // THUMB: 5-3 (aka Rb)
    logic [3:0] Rs;
  } decoded_regs_t;

endpackage : gba_cpu_decoder_types_pkg
