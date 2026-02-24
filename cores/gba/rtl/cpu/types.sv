import gba_types_pkg::*;

package gba_cpu_types_pkg;

  typedef logic [3:0] reg_index_t;

  /**
    From: https://mgba-emu.github.io/gbatek/#overview-11

    System/User FIQ       Supervisor Abort     IRQ       Undefined
    --------------------------------------------------------------
    R0          R0        R0         R0        R0        R0
    R1          R1        R1         R1        R1        R1
    R2          R2        R2         R2        R2        R2
    R3          R3        R3         R3        R3        R3
    R4          R4        R4         R4        R4        R4
    R5          R5        R5         R5        R5        R5
    R6          R6        R6         R6        R6        R6
    R7          R7        R7         R7        R7        R7
    --------------------------------------------------------------
    R8          R8_fiq    R8         R8        R8        R8
    R9          R9_fiq    R9         R9        R9        R9
    R10         R10_fiq   R10        R10       R10       R10
    R11         R11_fiq   R11        R11       R11       R11
    R12         R12_fiq   R12        R12       R12       R12
    R13 (SP)    R13_fiq   R13_svc    R13_abt   R13_irq   R13_und
    R14 (LR)    R14_fiq   R14_svc    R14_abt   R14_irq   R14_und
    R15 (PC)    R15       R15        R15       R15       R15
    --------------------------------------------------------------
    CPSR        CPSR      CPSR       CPSR      CPSR      CPSR
    --          SPSR_fiq  SPSR_svc   SPSR_abt  SPSR_irq  SPSR_und
    --------------------------------------------------------------
  */
  typedef struct {

    struct {
      word_t r0;
      word_t r1;
      word_t r2;
      word_t r3;
      word_t r4;
      word_t r5;
      word_t r6;
      word_t r7;
    } common;

    struct {
      word_t r8;
      word_t r9;
      word_t r10;
      word_t r11;
      word_t r12;
      word_t r13;  // SP
      word_t r14;  // LR
      word_t r15;  // PC
    } user;

    struct {
      word_t r8;
      word_t r9;
      word_t r10;
      word_t r11;
      word_t r12;
      word_t r13;  // SP
      word_t r14;  // LR
    } fiq;

    struct {
      word_t r13;  // SP
      word_t r14;  // LR
    } supervisor;

    struct {
      word_t r13;  // SP
      word_t r14;  // LR
    } abort;

    struct {
      word_t r13;  // SP
      word_t r14;  // LR
    } irq;

    struct {
      word_t r13;  // SP
      word_t r14;  // LR
    } undefined;

    /**
      From: https://mgba-emu.github.io/gbatek/#current-program-status-register-cpsr
      
      ```plain
      Bit   Expl.
      31    N - Sign Flag       (0=Not Signed, 1=Signed)               ;\
      30    Z - Zero Flag       (0=Not Zero, 1=Zero)                   ; Condition
      29    C - Carry Flag      (0=Borrow/No Carry, 1=Carry/No Borrow) ; Code Flags
      28    V - Overflow Flag   (0=No Overflow, 1=Overflow)            ;/
      27    Q - Sticky Overflow (1=Sticky Overflow, ARMv5TE and up only)
      26-8  Reserved            (For future use) - Do not change manually!
      7     I - IRQ disable     (0=Enable, 1=Disable)                     ;\
      6     F - FIQ disable     (0=Enable, 1=Disable)                     ; Control
      5     T - State Bit       (0=ARM, 1=THUMB) - Do not change manually!; Bits
      4-0   M4-M0 - Mode Bits   (See below)         
      ```
    */
    word_t CPSR;

    struct {
      word_t fiq;
      word_t supervisor;
      word_t abort;
      word_t irq;
      word_t undefined;
    } SPSR;

  } cpu_regs_t;

  typedef enum logic {
    MODE_ARM   = 1'b0,
    MODE_THUMB = 1'b1
  } execution_mode_t;

  // TODO: figure out priority
  typedef enum logic [2:0] {
    /// No exception
    EXCEPTION_NONE = 3'd0,

    /// Reset
    EXCEPTION_RESET = 3'd1,

    /// Undefined instruction (attempting to execute an undefined / illegal instruction)
    EXCEPTION_UNDEFINED = 3'd2,

    /// Software Interrupt (SWI)
    EXCEPTION_SWI = 3'd3,

    /// Prefetch abort (fetching instruction from memory failed)
    EXCEPTION_PABT = 3'd4,

    /// Data abort (data access from memory failed)
    EXCEPTION_DABT = 3'd5,

    /// Interrupt Request (IRQ)
    EXCEPTION_IRQ = 3'd6,

    /// Fast Interrupt Request (FIQ)
    EXCEPTION_FIQ = 3'd7
  } exception_t;

  localparam logic [31:0] VECTOR_TABLE[0:7] = '{
      32'hXXXX_XXXX,  // NONE (illegal / unused)
      32'h0000_0000,  // RESET
      32'h0000_0004,  // UNDEFINED
      32'h0000_0008,  // SWI
      32'h0000_000C,  // PREFETCH_ABORT
      32'h0000_0010,  // DATA_ABORT
      32'h0000_0018,  // IRQ
      32'h0000_001C  // FIQ
  };

  typedef enum logic [2:0] {

    SET_CPU_MODE_NONE = 3'b000,

    /// User mode (USR)
    SET_CPU_MODE_USR,

    /// Fast Interrupt Request mode (FIQ)
    SET_CPU_MODE_FIQ,

    /// Interrupt Request mode (IRQ)
    SET_CPU_MODE_IRQ,

    /// Supervisor mode (SVC)
    SET_CPU_MODE_SVC,

    /// Abort mode (ABT)
    SET_CPU_MODE_ABT,

    /// Undefined mode (UND)
    SET_CPU_MODE_UND,

    /// System mode (SYS)
    SET_CPU_MODE_SYS
  } set_cpu_mode_t;

  typedef enum logic [2:0] {

    /// User mode (USR)
    CPU_MODE_USR,

    /// Fast Interrupt Request mode (FIQ)
    CPU_MODE_FIQ,

    /// Interrupt Request mode (IRQ)
    CPU_MODE_IRQ,

    /// Supervisor mode (SVC)
    CPU_MODE_SVC,

    /// Abort mode (ABT)
    CPU_MODE_ABT,

    /// Undefined mode (UND)
    CPU_MODE_UND,

    /// System mode (SYS)
    CPU_MODE_SYS
  } cpu_mode_t;

  typedef enum logic [1:0] {
    SHIFT_LSL = 2'b00,
    SHIFT_LSR = 2'b01,
    SHIFT_ASR = 2'b10,
    SHIFT_ROR = 2'b11
  } shift_type_t;

  /// Conditional codes
  /// https://mgba-emu.github.io/gbatek/#arm-condition-field-cond
  typedef enum logic [3:0] {
    /// Equal; Z = 1
    COND_EQ = 4'b0000,

    /// Not equal; Z = 0
    COND_NE = 4'b0001,

    /// Carry set; C = 1
    COND_CS_HS = 4'b0010,

    /// Carry cleared; C = 0
    COND_CC_LO = 4'b0011,

    /// Minus/negative; N = 1
    COND_MI = 4'b0100,

    /// Plus/positive or zero; N = 0
    COND_PL = 4'b0101,

    /// Overflow; V = 1
    COND_VS = 4'b0110,

    /// No overflow; V = 0
    COND_VC = 4'b0111,

    /// Unsigned higher; C = 1 and Z = 0
    COND_HI = 4'b1000,

    /// Unsigned lower or same; C = 0 or Z = 1
    COND_LS = 4'b1001,

    /// Signed greater or equal; N = V
    COND_GE = 4'b1010,

    /// Signed less than; N != V
    COND_LT = 4'b1011,

    /// Signed greater than; Z = 0 and N = V
    COND_GT = 4'b1100,

    /// Signed less or equal; Z = 1 or N != V
    COND_LE = 4'b1101,

    /// Always; -
    COND_AL = 4'b1110,

    /// Never; -
    COND_NV = 4'b1111
  } condition_t;


  typedef enum logic [4:0] {

    // ======================================================
    // Invalid / System
    // ======================================================

    /// Undefined / illegal instruction
    ARM_INSTR_UNDEFINED,

    /// Software interrupt (SWI)
    ARM_INSTR_SWI,

    /// Exception entry (prefetch abort, data abort, etc.)
    ARM_INSTR_EXCEPTION,

    // ======================================================
    // Branch
    // ======================================================

    /// Branch (B)
    ARM_INSTR_BRANCH,

    /// Branch with link (BL)
    ARM_INSTR_BRANCH_LINK,

    /// Branch and exchange (BX)
    ARM_INSTR_BRANCH_EX,

    // ======================================================
    // Data Processing
    // ======================================================

    /// Operand2 = immediate (rotate + imm8)
    ARM_INSTR_DATAPROC_IMM,

    /// Operand2 = register shifted by immediate
    ARM_INSTR_DATAPROC_REG_IMM,

    /// Operand2 = register shifted by register
    ARM_INSTR_DATAPROC_REG_REG,

    // ======================================================
    // Multiply
    // ======================================================

    /// MUL / MLA
    ARM_INSTR_MULTIPLY,

    /// UMULL / UMLAL / SMULL / SMLAL
    ARM_INSTR_MULTIPLY_LONG,

    // ======================================================
    // Single Data Transfer
    // ======================================================

    /// LDR
    ARM_INSTR_LOAD,

    /// STR
    ARM_INSTR_STORE,

    /// LDRH / LDRSB / LDRSH
    ARM_INSTR_LDR_HALF,

    /// STRH
    ARM_INSTR_STR_HALF,

    // ======================================================
    // Multiple Data Transfer
    // ======================================================

    /// LDM
    ARM_INSTR_LDM,

    /// STM
    ARM_INSTR_STM,

    /// SWP / SWPB
    ARM_INSTR_SWAP,

    // ======================================================
    // PSR Transfer
    // ======================================================

    /// MRS (read CPSR/SPSR)
    ARM_INSTR_MRS,

    /// MSR (write CPSR/SPSR)
    ARM_INSTR_MSR

  } arm_instr_t;

  typedef struct packed {
    /// Negative
    logic n;

    /// Zero
    logic z;

    /// Carry
    logic c;

    /// Overflow
    logic v;

  } flags_t;

  /// TODO: verify this is in order
  typedef enum logic [3:0] {
    ALU_OP_AND = 4'h0,
    ALU_OP_XOR = 4'h1,
    ALU_OP_SUB = 4'h2,
    ALU_OP_SUB_REVERSED = 4'h3,
    ALU_OP_ADD = 4'h4,
    ALU_OP_ADC = 4'h5,
    ALU_OP_SBC = 4'h6,
    ALU_OP_SBC_REVERSED = 4'h7,
    ALU_OP_TEST = 4'h8,
    ALU_OP_TEST_EXCLUSIVE = 4'h9,
    ALU_OP_CMP = 4'hA,
    ALU_OP_CMP_NEG = 4'hB,
    ALU_OP_OR = 4'hC,
    ALU_OP_MOV = 4'hD,
    ALU_OP_BIT_CLEAR = 4'hE,
    ALU_OP_NOT = 4'hF
  } alu_op_t;

endpackage : gba_cpu_types_pkg
