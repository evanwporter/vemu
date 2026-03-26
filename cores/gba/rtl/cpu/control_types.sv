// Control model for ARM7 CPU
//  Each shared bus selects exactly one source per cycle.
//  Buses broadcast their value to all connected modules.
//  Each module independently decides whether to accept or ignore the bus
//   based on its control signals.

import gba_cpu_types_pkg::*;

package gba_control_types_pkg;

  typedef enum logic [2:0] {
    /// Don't change the current address on the address bus
    ADDR_SRC_NONE,

    /// Places the PC onto the address bus
    ADDR_SRC_PC,

    /// Places the ALU output onto the address bus
    ADDR_SRC_ALU,

    /// Increments the current address on the address bus
    ADDR_SRC_INCR,

    /// Places PC - 4 onto the address bus.
    /// TODO maybe i can just remove ADDR_SRC_PC and make this the default?
    ADDR_SRC_PC_RESTORE
  } address_source_t;

  typedef enum logic [1:0] {
    /// By default, the A bus uses the value from register Rn
    A_BUS_SRC_RN,

    /// Load the value from register Rs onto the A bus
    A_BUS_SRC_RS,

    /// Load the value from register Rs onto the A bus
    A_BUS_SRC_RD,

    /// Set the A_bus to the immediate value
    /// If set, then `A_bus_imm` must be assigned.
    A_BUS_SRC_IMM

  } A_bus_source_t;

  typedef enum logic [3:0] {
    B_BUS_SRC_NONE,

    /// Read immediate from IR
    /// If set, then `B_bus_imm` must be assigned.
    B_BUS_SRC_IMM,

    /// Read data from memory
    B_BUS_SRC_READ_DATA,

    /// Read data from register Rn
    B_BUS_SRC_REG_RN,

    /// Read data from register Rm
    B_BUS_SRC_REG_RM,

    /// Read data from register Rs
    B_BUS_SRC_REG_RS,

    /// Read data from register Rd
    B_BUS_SRC_REG_RD,

    /// Read data from register Rp (immediate value)
    /// If set, then `Rp_imm` must be assigned to specify which register to read from
    B_BUS_SRC_REG_RP,

    /// Read data from output of multiplier unit
    B_BUS_SRC_MULTIPLIER

  } B_bus_source_t;

  typedef enum logic [3:0] {
    ALU_WB_NONE,

    /// Write back ALU output to register Rd
    ALU_WB_REG_RD,

    /// Write back ALU output to register Rs
    ALU_WB_REG_RS,

    /// Write back ALU output to register Rn
    ALU_WB_REG_RN,

    /// If set, we need also need to set `Rp_imm`
    ALU_WB_REG_RP
  } alu_writeback_source_t;

  typedef struct packed {

    // ======================================================
    // Register Bank
    // ======================================================

    /// Whether to update the `PC` with `address + 4`
    logic incrementer_writeback;

    /// Write back to register `Rd` from ALU output
    alu_writeback_source_t ALU_writeback;

    /// An immediate value we can use to specify a register
    reg_index_t Rp_imm;

    /// TODO: Refactor
    logic force_user_mode;

    /// Dataproc and LDM instruction can optionally restore the CPSR from the 
    /// SPSR when writing back to the PC provided that certain conditions are met.
    logic restore_cpsr_from_spsr;

    /// TODO: If the only exception that the Controlunit can raise is undefined instruction, 
    /// then we can get away with just a boolean here.
    exception_t exception;

    logic set_thumb_mode;

    // ======================================================
    // A Bus
    // ======================================================

    A_bus_source_t A_bus_source;

    /// Immediate value to place on the A bus, if selected in `A_bus_source`
    logic [6:0] A_bus_imm;

    // TODO: Refactor these into something cleaner
    /// Whether to align the A bus value by masking off the lower 2 bits. 
    /// This is used for load/store instructions and ADD instructions.
    logic A_bus_align;

    logic force_no_align_pc;

    // ======================================================
    // B Bus
    // ======================================================

    B_bus_source_t B_bus_source;

    /// Immediate value to place on the B bus, if selected in `B_bus_source`
    logic [23:0] B_bus_imm;

    logic B_bus_sign_extend;

    // ======================================================
    // Address Module
    // ======================================================

    /// Used to specify the source for the address bus
    address_source_t addr_bus_src;

    // ======================================================
    // Memory Module
    // ======================================================

    /// Whether to accept the B_bus as data to write to memory
    logic memory_write_en;

    /// Whether to read data from memory and place it on the B_bus
    logic memory_read_en;

    logic memory_latch_IR;

    /// TODO: Implement more instruction to see if I need this
    // logic memory_latch_read_bus;

    // TODO: Combine following three logic into two bit enum

    /// Whether to transfer a byte (instead of a word) for memory read/write operations
    logic memory_byte_transfer;

    logic memory_halfword_transfer;

    logic memory_signed_transfer;

    // ======================================================
    // Multiplier Module
    // ======================================================

    logic multiplier_enable;

    // ======================================================
    // ALU
    // ======================================================

    /// Whether to latch the B_bus value into the ALU for use in the next cycle
    logic ALU_latch_op_b;

    /// Whether to use the latched B_bus value in the ALU for the current cycle
    logic ALU_use_op_b_latch;

    /// Whether to use the B_bus value in the ALU for the current cycle
    /// If true, then regardless of what the B_bus value is, the ALU will use zero as its B operand
    logic ALU_disable_op_b;

    // TODO: Perhaps remove this and instead perfer implied logic?
    logic ALU_set_flags;

    /// The ALU operation to perform in the current cycle
    alu_op_t ALU_op;

    // ======================================================
    // Barrel Shifter
    // ======================================================

    /// Whether the barrel shifter should latch the shift amount from the Rs register
    logic shift_latch_amt;

    /// Lets the barrel shifter know that the shift amount has been latched from 
    /// the Rs register, so it should use that instead of the immediate shift amount
    logic shift_use_latch;

    shift_type_t shift_type;

    logic shift_use_rxx;

    logic [4:0] shift_amount;

    // ======================================================
    // Pipeline Control
    // ======================================================

    /// Control unit will handle the flush instead of the PC triggering one
    logic pipeline_handle_flush;

    logic pipeline_advance;

  } control_t;

endpackage : gba_control_types_pkg
