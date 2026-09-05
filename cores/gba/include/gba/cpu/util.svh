`ifndef CPU_UTIL_SVH
`define CPU_UTIL_SVH

`define TRACE_CPU \
  `LOG_TRACE(("[%0t] PC=%0d Fetch-IR=%h Decoder-IR=%h instr=%0d addr=%0d flush=%b cycle=%0d WB=%0d Rd=%0d A_bus=%0d B_bus=%0d ALU=%0d LatchedReadData=%0d mode=%s exec_mode=%s", \
    $time, \
    regs.user.r15, \
    IR, \
    decoder_inst.IR, \
    decoder_bus.instr_type, \
    bus.addr, \
    controlUnit.flush_cnt != 3'd0, \
    controlUnit.cycle, \
    control_signals.ALU_writeback, \
    decoder_bus.decoded_regs.Rd, \
    A_bus, \
    B_bus, \
    alu_bus.result, \
    read_data, \
    cpu_mode.name(), \
    execution_mode.name() \
  ))

`define DISPLAY_CONTROL(ctrl) \
  `LOG_TRACE(("---- CONTROL WORD ----")) \
  `LOG_TRACE(("Exception             : %s", ctrl.exception.name())) \
  `LOG_TRACE(("incrementer_writeback : %0b", ctrl.incrementer_writeback)) \
  `LOG_TRACE(("ALU_writeback         : %s", ctrl.ALU_writeback.name())) \
  `LOG_TRACE(("A_bus_source          : %s", ctrl.A_bus_source.name())) \
  `LOG_TRACE(("A_bus_imm             : 0x%0d", ctrl.A_bus_imm)) \
  `LOG_TRACE(("B_bus_source          : %s", ctrl.B_bus_source.name())) \
  `LOG_TRACE(("B_bus_imm             : 0x%03h", ctrl.B_bus_imm)) \
  `LOG_TRACE(("addr_bus_src          : %s", ctrl.addr_bus_src.name())) \
  `LOG_TRACE(("memory_write_en       : %0b", ctrl.memory_write_en)) \
  `LOG_TRACE(("memory_read_en        : %0b", ctrl.memory_read_en)) \
  `LOG_TRACE(("memory_latch_IR       : %0b", ctrl.memory_latch_IR)) \
  `LOG_TRACE(("memory_byte_transfer  : %0b", ctrl.memory_byte_transfer)) \
  `LOG_TRACE(("memory_half_transfer  : %0b", ctrl.memory_halfword_transfer)) \
  `LOG_TRACE(("memory_signed_transfer: %0b", ctrl.memory_signed_transfer)) \
  `LOG_TRACE(("multiplier_enable     : %0b", ctrl.multiplier_enable)) \
  `LOG_TRACE(("force_no_align_pc     : %0b", ctrl.force_no_align_pc)) \
  `LOG_TRACE(("ALU_latch_op_b        : %0b", ctrl.ALU_latch_op_b)) \
  `LOG_TRACE(("ALU_use_op_b_latch    : %0b", ctrl.ALU_use_op_b_latch)) \
  `LOG_TRACE(("ALU_disable_op_b      : %0b", ctrl.ALU_disable_op_b)) \
  `LOG_TRACE(("Rp_imm                : %0d", ctrl.Rp_imm)) \
  `LOG_TRACE(("ALU_set_flags         : %0b", ctrl.ALU_set_flags)) \
  `LOG_TRACE(("ALU_op                : %s", ctrl.ALU_op.name())) \
  `LOG_TRACE(("shift_latch_amt       : %0b", ctrl.shift_latch_amt)) \
  `LOG_TRACE(("shift_use_latch       : %0b", ctrl.shift_use_latch)) \
  `LOG_TRACE(("shift_type            : %s", ctrl.shift_type.name())) \
  `LOG_TRACE(("shift_use_rxx         : %0b", ctrl.shift_use_rxx)) \
  `LOG_TRACE(("shift_amount          : %0d", ctrl.shift_amount)) \
  `LOG_TRACE(("pipeline_advance      : %0b", ctrl.pipeline_advance)) \
  `LOG_TRACE(("----------------------"))

`define DISPLAY_DECODED_DATAPROC_IMM(word, regs, instr_type, condition_pass) \
  begin \
    `LOG_TRACE(("---- DECODED WORD (DATAPROC_IMM) ----"))                      \
    // `LOG_TRACE(("IR        = 0x%08x", (word).IR))                              \
    `LOG_TRACE(("opcode    = %0d",   (word).data_proc_imm.opcode))   \
    `LOG_TRACE(("S bit     = %0b",   (word).data_proc_imm.set_flags))\
    `LOG_TRACE(("Rn        = R%0d",  (regs).Rn)) \
    `LOG_TRACE(("Rd        = R%0d",  (regs).Rd)) \
    `LOG_TRACE(("Rm        = R%0d",  (regs).Rm))                               \
    `LOG_TRACE(("Rs        = R%0d",  (regs).Rs))                               \
    `LOG_TRACE(("imm8      = 0x%02x", \
             (word).data_proc_imm.imm8))                          \
    `LOG_TRACE(("cond pass = %0d", condition_pass)) \
    `LOG_TRACE(("rotate    = %0d (actual ROR=%0d)",                            \
             (word).data_proc_imm.rotate,                         \
             ((word).data_proc_imm.rotate << 1)))                 \
    `LOG_TRACE(("------------------------------------"))                       \
  end

`define DISPLAY_DECODED_DATAPROC_REG_IMM(word, regs, instr_type, condition_pass) \
  begin \
    `LOG_TRACE(("---- DECODED WORD (DATAPROC_REG_IMM) ----"))                 \
    // `LOG_TRACE(("IR          = 0x%08x", (word).IR))                           \
    `LOG_TRACE(("opcode      = %s",    (word).data_proc_reg_imm.opcode)) \
    `LOG_TRACE(("S bit       = %0b",   (word).data_proc_reg_imm.set_flags)) \
    `LOG_TRACE(("Rn          = R%0d",  (regs).Rn))                            \
    `LOG_TRACE(("Rd          = R%0d",  (regs).Rd))                            \
    `LOG_TRACE(("Rm          = R%0d",  (regs).Rm))                            \
    `LOG_TRACE(("shift type  = %s",    (word).data_proc_reg_imm.shift_type.name())) \
    `LOG_TRACE(("shift amt   = %0d",   (word).data_proc_reg_imm.shift_amount)) \
    `LOG_TRACE(("cond pass   = %0d",   condition_pass))               \
    `LOG_TRACE(("----------------------------------------"))                   \
  end

`define DISPLAY_DECODED_DATAPROC_REG_REG(word, regs, instr_type, condition_pass) \
  begin \
    `LOG_TRACE(("---- DECODED WORD (DATAPROC_REG_REG) ----"))                  \
    // `LOG_TRACE(("IR          = 0x%08x", (word).IR))                           \
    `LOG_TRACE(("opcode      = %0d",   (word).data_proc_reg_reg.opcode)) \
    `LOG_TRACE(("S bit       = %0b",   (word).data_proc_reg_reg.set_flags)) \
    `LOG_TRACE(("Rn          = R%0d",  (regs).Rn))                            \
    `LOG_TRACE(("Rd          = R%0d",  (regs).Rd))                            \
    `LOG_TRACE(("Rm          = R%0d",  (regs).Rm))                            \
    `LOG_TRACE(("Rs          = R%0d",  (regs).Rs))                            \
    `LOG_TRACE(("shift type  = %s",    (word).data_proc_reg_reg.shift_type.name())) \
    `LOG_TRACE(("cond pass   = %0d",   condition_pass))               \
    `LOG_TRACE(("------------------------------------------"))                  \
  end

`define DISPLAY_DECODED_LS(word, regs, instr_type, condition_pass) \
  begin \
    `LOG_TRACE(("---- DECODED WORD (LOAD / STORE) ----")) \
    // `LOG_TRACE(("IR           = 0x%08x", (word).IR)) \
    `LOG_TRACE(("instr_type   = %s", instr_type.name())) \
    `LOG_TRACE(("cond pass    = %0d", condition_pass)) \
    `LOG_TRACE(("Rn           = R%0d", (regs).Rn)) \
    `LOG_TRACE(("Rd           = R%0d", (regs).Rd)) \
    `LOG_TRACE(("Rm           = R%0d", (regs).Rm)) \
    `LOG_TRACE(("")) \
    `LOG_TRACE(("Addressing:")) \
    `LOG_TRACE(("  I (offset) = %s", (word).ls.I.name())) \
    `LOG_TRACE(("  P (index)  = %s", (word).ls.P.name())) \
    `LOG_TRACE(("  U (add)    = %0b", (word).ls.U)) \
    `LOG_TRACE(("  B (size)   = %s", (word).ls.B.name())) \
    `LOG_TRACE(("  W (write)  = %0b", (word).ls.wt)) \
    if ((word).ls.I == ARM_LDR_STR_REGISTER) begin \
      `LOG_TRACE(("Offset (register shifted):")) \
      `LOG_TRACE(("  shift type = %s", \
               (word).ls.offset.shifted.shift_type.name())) \
      `LOG_TRACE(("  shift amt  = %0d", \
               (word).ls.offset.shifted.shift_amount)) \
    end else begin \
      `LOG_TRACE(("Offset (immediate):")) \
      `LOG_TRACE(("  imm12      = 0x%03h", \
               (word).ls.offset.imm12)) \
    end \
    `LOG_TRACE(("------------------------------------")) \
  end

`define DISPLAY_DECODED_BLOCK(word, regs, instr_type, condition_pass) \
  begin \
    `LOG_TRACE(("---- DECODED WORD (BLOCK DATA TRANSFER) ----")) \
    // `LOG_TRACE(("IR           = 0x%08x", (word).IR)) \
    `LOG_TRACE(("instr_type   = %s", instr_type.name())) \
    `LOG_TRACE(("cond pass    = %0d", condition_pass)) \
    `LOG_TRACE(("Rn (base)    = R%0d", (regs).Rn)) \
    `LOG_TRACE(("")) \
    `LOG_TRACE(("Addressing Mode:")) \
    `LOG_TRACE(("  P (index)  = %s", (word).block.P.name())) \
    `LOG_TRACE(("  U (add)    = %0b", (word).block.U)) \
    `LOG_TRACE(("  S (PSR)    = %0b", (word).block.S)) \
    `LOG_TRACE(("  W (wb)     = %0b", (word).block.W)) \
    `LOG_TRACE(("")) \
    `LOG_TRACE(("Register List (reg_list = 0x%04h):", \
             (word).block.reg_list)) \
    for (int i = 0; i < 16; i++) begin \
      if ((word).block.reg_list[i]) \
        `LOG_TRACE(("R%0d", i)) \
    end \
    `LOG_TRACE(("")) \
    `LOG_TRACE(("--------------------------------------------")) \
  end

`define DISPLAY_DECODED_LS_HALF(word, regs, instr_type, condition_pass) \
  begin \
    `LOG_TRACE(("---- DECODED WORD (LS_HALF: halfword/signed transfer) ----")) \
    // `LOG_TRACE(("IR           = 0x%08x", (word).IR)) \
    `LOG_TRACE(("instr_type   = %s", instr_type.name())) \
    `LOG_TRACE(("cond pass    = %0d", condition_pass)) \
    `LOG_TRACE(("Rn (base)    = R%0d", (regs).Rn)) \
    `LOG_TRACE(("Rd (dest)    = R%0d", (regs).Rd)) \
    `LOG_TRACE(("Rm (offset)  = R%0d", (regs).Rm)) \
    `LOG_TRACE(("")) \
    `LOG_TRACE(("Addressing:")) \
    `LOG_TRACE(("  P (index)  = %s", (word).ls_half.P.name())) \
    `LOG_TRACE(("  U (add)    = %0b", (word).ls_half.U)) \
    `LOG_TRACE(("  I (offset) = %0b", (word).ls_half.I)) \
    `LOG_TRACE(("  W (wb)     = %0b", (word).ls_half.W)) \
    `LOG_TRACE(("")) \
    `LOG_TRACE(("Transfer type (opcode) = %s", (word).ls_half.opcode.name())) \
    unique case ((word).ls_half.opcode) \
      ARM_LOAD_STORE_HALFWORD: begin \
        `LOG_TRACE(("  Meaning: Unsigned halfword (LDRH/STRH)")) \
      end \
      ARM_LOAD_SIGNED_BYTE: begin \
        `LOG_TRACE(("  Meaning: Signed byte load (LDRSB)")) \
      end \
      ARM_LOAD_SIGNED_HALFWORD: begin \
        `LOG_TRACE(("  Meaning: Signed halfword load (LDRSH)")) \
      end \
      ARM_LOAD_STORE_INVALID: begin \
        `LOG_TRACE(("  Meaning: INVALID/Reserved")) \
      end \
    endcase \
    `LOG_TRACE(("")) \
    if ((word).ls_half.I == ARM_LDR_STR_IMMEDIATE) begin \
      `LOG_TRACE(("Offset (immediate imm8) = 0x%02h (%0d)", \
               (word).ls_half.imm_offset, \
               (word).ls_half.imm_offset)) \
    end else begin \
      `LOG_TRACE(("Offset (register) = R%0d (unshifted for halfword/signed transfers)", \
               (regs).Rm)) \
    end \
    `LOG_TRACE(("-----------------------------------------------")) \
  end

`define DISPLAY_DECODED_SWAP(word, regs, instr_type, condition_pass) \
  begin \
    `LOG_TRACE(("---- DECODED WORD (LOAD / STORE) ----")) \
    // `LOG_TRACE(("IR           = 0x%08x", (word).IR)) \
    `LOG_TRACE(("instr_type   = %s", instr_type.name())) \
    `LOG_TRACE(("cond pass    = %0d", condition_pass)) \
    `LOG_TRACE(("Rn           = R%0d", (regs).Rn)) \
    `LOG_TRACE(("Rd           = R%0d", (regs).Rd)) \
    `LOG_TRACE(("Rm           = R%0d", (regs).Rm)) \
    `LOG_TRACE(("")) \
    `LOG_TRACE(("Addressing:")) \
    `LOG_TRACE(("  B (size)   = %s", (word).swap.B.name())) \
    `LOG_TRACE(("------------------------------------")) \
  end

`define DISPLAY_DECODED_BRANCH(word, regs, instr_type, condition_pass) \
  begin \
    logic signed [31:0] signed_imm; \
    logic signed [31:0] shifted_imm; \
    signed_imm  = {{8{(word).branch.imm24[23]}}, \
                   (word).branch.imm24}; \
    shifted_imm = signed_imm <<< 2; \
    `LOG_TRACE(("---- DECODED WORD (BRANCH) ----")) \
    // `LOG_TRACE(("IR           = 0x%08x", (word).IR)) \
    `LOG_TRACE(("instr_type   = %s", instr_type.name())) \
    `LOG_TRACE(("cond pass    = %0d", condition_pass)) \
    `LOG_TRACE(("Rn (base)    = R%0d", (regs).Rn)) \
    `LOG_TRACE(("Rd (dest)    = R%0d", (regs).Rd)) \
    `LOG_TRACE(("")) \
    `LOG_TRACE(("imm24 raw    = 0x%06h", \
             (word).branch.imm24)) \
    `LOG_TRACE(("imm24 signed = %0d (0x%08x)", \
             signed_imm, signed_imm)) \
    `LOG_TRACE(("imm24<<2     = %0d (0x%08x)", \
             shifted_imm, shifted_imm)) \
    `LOG_TRACE(("--------------------------------")) \
  end

`define DISPLAY_DECODED_MULT(word, regs, instr_type, condition_pass) \
  begin \
    `LOG_TRACE(("---- DECODED WORD (MULT) ----")) \
    // `LOG_TRACE(("IR           = 0x%08x", (word).IR)) \
    `LOG_TRACE(("instr_type   = %s", instr_type.name())) \
    `LOG_TRACE(("cond pass    = %0d", condition_pass)) \
    `LOG_TRACE(("Rn (accum)   = R%0d", (regs).Rn)) \
    `LOG_TRACE(("Rd (dest)    = R%0d", (regs).Rd)) \
    `LOG_TRACE(("Rm (operand) = R%0d", (regs).Rm)) \
    `LOG_TRACE(("Rs (operand) = R%0d", (regs).Rs)) \
    `LOG_TRACE(("S bit        = %0b", (word).mul.S)) \
    `LOG_TRACE(("opcode       = %s", (word).mul.opcode.name())) \
    `LOG_TRACE(("--------------------------------")) \
  end

`define DISPLAY_DECODED_MSR(word, regs, instr_type, condition_pass) \
  begin \
    `LOG_TRACE(("---- DECODED WORD (MSR) ----")) \
    `LOG_TRACE(("instr_type   = %s", instr_type.name())) \
    `LOG_TRACE(("cond pass    = %0d", condition_pass)) \
    `LOG_TRACE(("")) \
    `LOG_TRACE(("Target PSR   = %s", (word).msr.psr.name())) \
    `LOG_TRACE(("Fields:")) \
    `LOG_TRACE(("  f (flags)  = %0b", (word).msr.f)) \
    `LOG_TRACE(("  s (status) = %0b", (word).msr.s)) \
    `LOG_TRACE(("  x (ext)    = %0b", (word).msr.x)) \
    `LOG_TRACE(("  c (ctrl)   = %0b", (word).msr.c)) \
    `LOG_TRACE(("")) \
    if ((word).msr.I) begin \
      `LOG_TRACE(("Operand      = immediate")) \
      `LOG_TRACE(("  imm8       = 0x%02h", (word).msr.imm8)) \
      `LOG_TRACE(("  rotate     = %0d (ROR=%0d)", \
               (word).msr.rotate, (word).msr.rotate << 1)) \
    end else begin \
      `LOG_TRACE(("Operand      = register")) \
      `LOG_TRACE(("  Rm         = R%0d", (regs).Rm)) \
    end \
    `LOG_TRACE(("--------------------------------")) \
  end

`define DISPLAY_DECODED_MRS(word, regs, instr_type, condition_pass) \
  begin \
    `LOG_TRACE(("---- DECODED WORD (MRS) ----")) \
    `LOG_TRACE(("instr_type   = %s", instr_type.name())) \
    `LOG_TRACE(("cond pass    = %0d", condition_pass)) \
    `LOG_TRACE(("")) \
    `LOG_TRACE(("Source PSR   = %s", (word).mrs.psr.name())) \
    `LOG_TRACE(("Destination  = R%0d", (regs).Rd)) \
    `LOG_TRACE(("--------------------------------")) \
  end

`define WRITE_REG(REGS, MODE, REGNUM, VALUE, EXEC_MODE, ALIGN_PC) \
  begin \
    unique case (REGNUM) \
      4'd0:  (REGS).common.r0  <= (VALUE); \
      4'd1:  (REGS).common.r1  <= (VALUE); \
      4'd2:  (REGS).common.r2  <= (VALUE); \
      4'd3:  (REGS).common.r3  <= (VALUE); \
      4'd4:  (REGS).common.r4  <= (VALUE); \
      4'd5:  (REGS).common.r5  <= (VALUE); \
      4'd6:  (REGS).common.r6  <= (VALUE); \
      4'd7:  (REGS).common.r7  <= (VALUE); \
      4'd8: begin \
        if ((MODE) == CPU_MODE_FIQ) (REGS).fiq.r8  <= (VALUE); \
        else (REGS).user.r8 <= (VALUE); \
      end \
      4'd9: begin \
        if ((MODE) == CPU_MODE_FIQ) (REGS).fiq.r9  <= (VALUE); \
        else (REGS).user.r9 <= (VALUE); \
      end \
      4'd10: begin \
        if ((MODE) == CPU_MODE_FIQ) (REGS).fiq.r10 <= (VALUE); \
        else (REGS).user.r10<= (VALUE); \
      end \
      4'd11: begin \
        if ((MODE) == CPU_MODE_FIQ) (REGS).fiq.r11 <= (VALUE); \
        else (REGS).user.r11<= (VALUE); \
      end \
      4'd12: begin \
        if ((MODE) == CPU_MODE_FIQ) (REGS).fiq.r12 <= (VALUE); \
        else (REGS).user.r12<= (VALUE); \
      end \
      4'd13: begin \
        unique case (MODE) \
          CPU_MODE_USR, CPU_MODE_SYS: (REGS).user.r13 <= (VALUE); \
          CPU_MODE_FIQ: (REGS).fiq.r13 <= (VALUE); \
          CPU_MODE_SVC: (REGS).supervisor.r13 <= (VALUE); \
          CPU_MODE_ABT: (REGS).abort.r13 <= (VALUE); \
          CPU_MODE_IRQ: (REGS).irq.r13 <= (VALUE); \
          CPU_MODE_UND: (REGS).undefined.r13 <= (VALUE);  \
        endcase \
      end \
      4'd14: begin \
        unique case (MODE) \
          CPU_MODE_USR, CPU_MODE_SYS: (REGS).user.r14 <= (VALUE); \
          CPU_MODE_FIQ: (REGS).fiq.r14 <= (VALUE); \
          CPU_MODE_SVC: (REGS).supervisor.r14 <= (VALUE); \
          CPU_MODE_ABT: (REGS).abort.r14 <= (VALUE); \
          CPU_MODE_IRQ: (REGS).irq.r14 <= (VALUE); \
          CPU_MODE_UND: (REGS).undefined.r14 <= (VALUE); \
        endcase \
      end \
      4'd15: begin \
        unique case (EXEC_MODE) \
          MODE_ARM: (REGS).user.r15 <= (VALUE); \
          MODE_THUMB: begin \
              if (ALIGN_PC) (REGS).user.r15 <= (VALUE) & ~32'd1; \
              else begin \
                (REGS).user.r15 <= (VALUE); \
                `LOG_TRACE(("Warning: writing unaligned value 0x%08x to PC in THUMB mode", (VALUE))) \
              end \
          end \
        endcase \
      end \
    endcase \
  end

`define WRITE_SPSR(REGS, MODE, VALUE) \
    begin \
      unique case (MODE) \
        CPU_MODE_USR, CPU_MODE_SYS: ;  /* No SPSR for USR/SYS */ \
        CPU_MODE_FIQ: (REGS).SPSR.fiq <= (VALUE); \
        CPU_MODE_IRQ: (REGS).SPSR.irq <= (VALUE); \
        CPU_MODE_SVC: (REGS).SPSR.supervisor <= (VALUE); \
        CPU_MODE_ABT: (REGS).SPSR.abort <= (VALUE); \
        CPU_MODE_UND: (REGS).SPSR.undefined <= (VALUE); \
      endcase \
    end

`define PC_WRITE_EXCEPTION(REGS, MODE) \
    begin \
      unique case (MODE) \
        CPU_MODE_USR, CPU_MODE_SYS: (REGS).user.r15 <= 32'h00000004; \
        CPU_MODE_UND: (REGS).undefined.r15 <= 32'h00000018; \
        CPU_MODE_SVC: (REGS).supervisor.r15 <= 32'h0000000C; \
        CPU_MODE_FIQ: (REGS).fiq.r15 <= 32'h00000008; \
        CPU_MODE_ABT: (REGS).abort.r15 <= 32'h00000010; \
        CPU_MODE_IRQ: (REGS).irq.r15 <= 32'h00000014; \
      endcase \
    end

`endif  // CPU_UTIL_SVH
