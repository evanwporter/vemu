`ifndef CPU_UTIL_SVH
`define CPU_UTIL_SVH

`define TRACE_CPU \
  $display("[%0t] PC=%0d Fetch-IR=%h Decoder-IR=%h instr=%0d addr=%0d flush=%b cycle=%0d WB=%0d Rd=%0d A_bus=%0d B_bus=%0d ALU=%0d LatchedReadData=%0d mode=%s exec_mode=%s", \
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
  );

`define DISPLAY_CONTROL(ctrl) \
  $display("---- CONTROL WORD ----"); \
  $display("Exception             : %s", ctrl.exception.name()); \
  $display("incrementer_writeback : %0b", ctrl.incrementer_writeback); \
  $display("ALU_writeback         : %s", ctrl.ALU_writeback.name()); \
  $display("A_bus_source          : %s", ctrl.A_bus_source.name()); \
  $display("A_bus_imm             : 0x%0d", ctrl.A_bus_imm); \
  $display("B_bus_source          : %s", ctrl.B_bus_source.name()); \
  $display("B_bus_imm             : 0x%03h", ctrl.B_bus_imm); \
  $display("addr_bus_src          : %s", ctrl.addr_bus_src.name()); \
  $display("memory_write_en       : %0b", ctrl.memory_write_en); \
  $display("memory_read_en        : %0b", ctrl.memory_read_en); \
  $display("memory_latch_IR       : %0b", ctrl.memory_latch_IR); \
  $display("memory_byte_transfer  : %0b", ctrl.memory_byte_transfer); \
  $display("memory_half_transfer  : %0b", ctrl.memory_halfword_transfer); \
  $display("memory_signed_transfer: %0b", ctrl.memory_signed_transfer); \
  $display("multiplier_enable     : %0b", ctrl.multiplier_enable); \
  $display("force_no_align_pc     : %0b", ctrl.force_no_align_pc); \
  $display("ALU_latch_op_b        : %0b", ctrl.ALU_latch_op_b); \
  $display("ALU_use_op_b_latch    : %0b", ctrl.ALU_use_op_b_latch); \
  $display("ALU_disable_op_b      : %0b", ctrl.ALU_disable_op_b); \
  $display("Rp_imm                : %0d", ctrl.Rp_imm); \
  $display("ALU_set_flags         : %0b", ctrl.ALU_set_flags); \
  $display("ALU_op                : %s", ctrl.ALU_op.name()); \
  $display("shift_latch_amt       : %0b", ctrl.shift_latch_amt); \
  $display("shift_use_latch       : %0b", ctrl.shift_use_latch); \
  $display("shift_type            : %s", ctrl.shift_type.name()); \
  $display("shift_use_rxx         : %0b", ctrl.shift_use_rxx); \
  $display("shift_amount          : %0d", ctrl.shift_amount); \
  $display("pipeline_advance      : %0b", ctrl.pipeline_advance); \
  $display("----------------------"); \
  $fflush();

`define DISPLAY_DECODED_DATAPROC_IMM(word, regs, instr_type, condition_pass) \
  begin \
    $display("---- DECODED WORD (DATAPROC_IMM) ----");                      \
    // $display("IR        = 0x%08x", (word).IR);                              \
    $display("opcode    = %0d",   (word).data_proc_imm.opcode);   \
    $display("S bit     = %0b",   (word).data_proc_imm.set_flags);\
    $display("Rn        = R%0d",  (regs).Rn); \
    $display("Rd        = R%0d",  (regs).Rd); \
    $display("Rm        = R%0d",  (regs).Rm);                               \
    $display("Rs        = R%0d",  (regs).Rs);                               \
    $display("imm8      = 0x%02x", \
             (word).data_proc_imm.imm8);                          \
    $display("cond pass = %0d", condition_pass); \
    $display("rotate    = %0d (actual ROR=%0d)",                            \
             (word).data_proc_imm.rotate,                         \
             ((word).data_proc_imm.rotate << 1));                 \
    $display("------------------------------------");                       \
    $fflush();                                                              \
  end

`define DISPLAY_DECODED_DATAPROC_REG_IMM(word, regs, instr_type, condition_pass) \
  begin \
    $display("---- DECODED WORD (DATAPROC_REG_IMM) ----");                 \
    // $display("IR          = 0x%08x", (word).IR);                           \
    $display("opcode      = %0d",   (word).data_proc_reg_imm.opcode); \
    $display("S bit       = %0b",   (word).data_proc_reg_imm.set_flags); \
    $display("Rn          = R%0d",  (regs).Rn);                            \
    $display("Rd          = R%0d",  (regs).Rd);                            \
    $display("Rm          = R%0d",  (regs).Rm);                            \
    $display("shift type  = %s",    (word).data_proc_reg_imm.shift_type.name()); \
    $display("shift amt   = %0d",   (word).data_proc_reg_imm.shift_amount); \
    $display("cond pass   = %0d",   condition_pass);               \
    $display("----------------------------------------");                   \
    $fflush();                                                            \
  end

  `define DISPLAY_DECODED_DATAPROC_REG_REG(word, regs, instr_type, condition_pass) \
  begin \
    $display("---- DECODED WORD (DATAPROC_REG_REG) ----");                  \
    // $display("IR          = 0x%08x", (word).IR);                           \
    $display("opcode      = %0d",   (word).data_proc_reg_reg.opcode); \
    $display("S bit       = %0b",   (word).data_proc_reg_reg.set_flags); \
    $display("Rn          = R%0d",  (regs).Rn);                            \
    $display("Rd          = R%0d",  (regs).Rd);                            \
    $display("Rm          = R%0d",  (regs).Rm);                            \
    $display("Rs          = R%0d",  (regs).Rs);                            \
    $display("shift type  = %s",    (word).data_proc_reg_reg.shift_type.name()); \
    $display("cond pass   = %0d",   condition_pass);               \
    $display("------------------------------------------");                  \
    $fflush();                                                            \
  end

`define DISPLAY_DECODED_LS(word, regs, instr_type, condition_pass) \
  begin \
    $display("---- DECODED WORD (LOAD / STORE) ----"); \
    // $display("IR           = 0x%08x", (word).IR); \
    $display("instr_type   = %s", instr_type.name()); \
    $display("cond pass    = %0d", condition_pass); \
    $display("Rn           = R%0d", (regs).Rn); \
    $display("Rd           = R%0d", (regs).Rd); \
    $display("Rm           = R%0d", (regs).Rm); \
    $display(""); \
    $display("Addressing:"); \
    $display("  I (offset) = %s", (word).ls.I.name()); \
    $display("  P (index)  = %s", (word).ls.P.name()); \
    $display("  U (add)    = %0b", (word).ls.U); \
    $display("  B (size)   = %s", (word).ls.B.name()); \
    $display("  W (write)  = %0b", (word).ls.wt); \
    if ((word).ls.I == ARM_LDR_STR_REGISTER) begin \
      $display("Offset (register shifted):"); \
      $display("  shift type = %s", \
               (word).ls.offset.shifted.shift_type.name()); \
      $display("  shift amt  = %0d", \
               (word).ls.offset.shifted.shift_amount); \
    end else begin \
      $display("Offset (immediate):"); \
      $display("  imm12      = 0x%03h", \
               (word).ls.offset.imm12); \
    end \
    $display("------------------------------------"); \
    $fflush(); \
  end

`define DISPLAY_DECODED_BLOCK(word, regs, instr_type, condition_pass) \
  begin \
    $display("---- DECODED WORD (BLOCK DATA TRANSFER) ----"); \
    // $display("IR           = 0x%08x", (word).IR); \
    $display("instr_type   = %s", instr_type.name()); \
    $display("cond pass    = %0d", condition_pass); \
    $display("Rn (base)    = R%0d", (regs).Rn); \
    $display(""); \
    $display("Addressing Mode:"); \
    $display("  P (index)  = %s", (word).block.P.name()); \
    $display("  U (add)    = %0b", (word).block.U); \
    $display("  S (PSR)    = %0b", (word).block.S); \
    $display("  W (wb)     = %0b", (word).block.W); \
    $display(""); \
    $display("Register List (reg_list = 0x%04h):", \
             (word).block.reg_list); \
    for (int i = 0; i < 16; i++) begin \
      if ((word).block.reg_list[i]) \
        $write("R%0d ", i); \
    end \
    $display(""); \
    $display("--------------------------------------------"); \
    $fflush(); \
  end

`define DISPLAY_DECODED_LS_HALF(word, regs, instr_type, condition_pass) \
  begin \
    $display("---- DECODED WORD (LS_HALF: halfword/signed transfer) ----"); \
    // $display("IR           = 0x%08x", (word).IR); \
    $display("instr_type   = %s", instr_type.name()); \
    $display("cond pass    = %0d", condition_pass); \
    $display("Rn (base)    = R%0d", (regs).Rn); \
    $display("Rd (dest)    = R%0d", (regs).Rd); \
    $display("Rm (offset)  = R%0d", (regs).Rm); \
    $display(""); \
    $display("Addressing:"); \
    $display("  P (index)  = %s", (word).ls_half.P.name()); \
    $display("  U (add)    = %0b", (word).ls_half.U); \
    $display("  I (offset) = %0b", (word).ls_half.I); \
    $display("  W (wb)     = %0b", (word).ls_half.W); \
    $display(""); \
    $display("Transfer type (opcode) = %s", (word).ls_half.opcode.name()); \
    unique case ((word).ls_half.opcode) \
      ARM_LOAD_STORE_HALFWORD: begin \
        $display("  Meaning: Unsigned halfword (LDRH/STRH)"); \
      end \
      ARM_LOAD_SIGNED_BYTE: begin \
        $display("  Meaning: Signed byte load (LDRSB)"); \
      end \
      ARM_LOAD_SIGNED_HALFWORD: begin \
        $display("  Meaning: Signed halfword load (LDRSH)"); \
      end \
      ARM_LOAD_STORE_INVALID: begin \
        $display("  Meaning: INVALID/Reserved"); \
      end \
    endcase \
    $display(""); \
    if ((word).ls_half.I == ARM_LDR_STR_IMMEDIATE) begin \
      $display("Offset (immediate imm8) = 0x%02h (%0d)", \
               (word).ls_half.imm_offset, \
               (word).ls_half.imm_offset); \
    end else begin \
      $display("Offset (register) = R%0d (unshifted for halfword/signed transfers)", \
               (regs).Rm); \
    end \
    $display("-----------------------------------------------"); \
    $fflush(); \
  end

`define DISPLAY_DECODED_SWAP(word, regs, instr_type, condition_pass) \
  begin \
    $display("---- DECODED WORD (LOAD / STORE) ----"); \
    // $display("IR           = 0x%08x", (word).IR); \
    $display("instr_type   = %s", instr_type.name()); \
    $display("cond pass    = %0d", condition_pass); \
    $display("Rn           = R%0d", (regs).Rn); \
    $display("Rd           = R%0d", (regs).Rd); \
    $display("Rm           = R%0d", (regs).Rm); \
    $display(""); \
    $display("Addressing:"); \
    $display("  B (size)   = %s", (word).swap.B.name()); \
    $display("------------------------------------"); \
    $fflush(); \
  end

`define DISPLAY_DECODED_BRANCH(word, regs, instr_type, condition_pass) \
  begin \
    logic signed [31:0] signed_imm; \
    logic signed [31:0] shifted_imm; \
    signed_imm  = {{8{(word).branch.imm24[23]}}, \
                   (word).branch.imm24}; \
    shifted_imm = signed_imm <<< 2; \
    $display("---- DECODED WORD (BRANCH) ----"); \
    // $display("IR           = 0x%08x", (word).IR); \
    $display("instr_type   = %s", instr_type.name()); \
    $display("cond pass    = %0d", condition_pass); \
    $display("Rn (base)    = R%0d", (regs).Rn); \
    $display("Rd (dest)    = R%0d", (regs).Rd); \
    $display(""); \
    $display("imm24 raw    = 0x%06h", \
             (word).branch.imm24); \
    $display("imm24 signed = %0d (0x%08x)", \
             signed_imm, signed_imm); \
    $display("imm24<<2     = %0d (0x%08x)", \
             shifted_imm, shifted_imm); \
    $display("--------------------------------"); \
    $fflush(); \
  end

`define DISPLAY_DECODED_MULT(word, regs, instr_type, condition_pass) \
  begin \
    $display("---- DECODED WORD (MULT) ----"); \
    // $display("IR           = 0x%08x", (word).IR); \
    $display("instr_type   = %s", instr_type.name()); \
    $display("cond pass    = %0d", condition_pass); \
    $display("Rn (accum)   = R%0d", (regs).Rn); \
    $display("Rd (dest)    = R%0d", (regs).Rd); \
    $display("Rm (operand) = R%0d", (regs).Rm); \
    $display("Rs (operand) = R%0d", (regs).Rs); \
    $display("opcode       = %s", (word).mul.opcode.name()); \
    $display("--------------------------------"); \
    $fflush(); \
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
                $display("Warning: writing unaligned value 0x%08x to PC in THUMB mode", (VALUE)); \
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

`endif // CPU_UTIL_SVH
