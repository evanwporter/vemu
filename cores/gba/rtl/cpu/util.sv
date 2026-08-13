`include "gba/util/logger.svh"

import gba_types_pkg::*;
import gba_cpu_types_pkg::*;
import gba_control_types_pkg::*;

package gba_cpu_util_pkg;

  function automatic logic eval_cond(input logic [3:0] cond, input logic N, input logic Z,
                                     input logic C, input logic V);
    case (cond)
      4'b0000: eval_cond = Z;  // EQ
      4'b0001: eval_cond = !Z;  // NE
      4'b0010: eval_cond = C;  // CS/HS
      4'b0011: eval_cond = !C;  // CC/LO
      4'b0100: eval_cond = N;  // MI
      4'b0101: eval_cond = !N;  // PL
      4'b0110: eval_cond = V;  // VS
      4'b0111: eval_cond = !V;  // VC
      4'b1000: eval_cond = C && !Z;  // HI
      4'b1001: eval_cond = !C || Z;  // LS
      4'b1010: eval_cond = (N == V);  // GE
      4'b1011: eval_cond = (N != V);  // LT
      4'b1100: eval_cond = !Z && (N == V);  // GT
      4'b1101: eval_cond = Z || (N != V);  // LE
      4'b1110: eval_cond = 1'b1;  // AL
      4'b1111: eval_cond = 1'b0;  // NV (never)
      default: eval_cond = 1'b0;
    endcase

    `LOG_TRACE(("eval_cond: cond=%b N=%0b Z=%0b C=%0b V=%0b -> pass=%0b", cond, N, Z, C, V, eval_cond))
  endfunction

  function automatic word_t read_reg(input cpu_regs_t regs, input cpu_mode_t mode,
                                     input logic [3:0] reg_num);
    unique case (reg_num)

      // R0–R7 : common
      4'd0: read_reg = regs.common.r0;
      4'd1: read_reg = regs.common.r1;
      4'd2: read_reg = regs.common.r2;
      4'd3: read_reg = regs.common.r3;
      4'd4: read_reg = regs.common.r4;
      4'd5: read_reg = regs.common.r5;
      4'd6: read_reg = regs.common.r6;
      4'd7: read_reg = regs.common.r7;

      // R8–R12 : banked only for FIQ
      4'd8:  read_reg = (mode == CPU_MODE_FIQ) ? regs.fiq.r8 : regs.user.r8;
      4'd9:  read_reg = (mode == CPU_MODE_FIQ) ? regs.fiq.r9 : regs.user.r9;
      4'd10: read_reg = (mode == CPU_MODE_FIQ) ? regs.fiq.r10 : regs.user.r10;
      4'd11: read_reg = (mode == CPU_MODE_FIQ) ? regs.fiq.r11 : regs.user.r11;
      4'd12: read_reg = (mode == CPU_MODE_FIQ) ? regs.fiq.r12 : regs.user.r12;

      // R13 / R14 : fully banked
      4'd13: begin
        unique case (mode)
          CPU_MODE_USR, CPU_MODE_SYS: read_reg = regs.user.r13;
          CPU_MODE_FIQ: read_reg = regs.fiq.r13;
          CPU_MODE_SVC: read_reg = regs.supervisor.r13;
          CPU_MODE_ABT: read_reg = regs.abort.r13;
          CPU_MODE_IRQ: read_reg = regs.irq.r13;
          CPU_MODE_UND: read_reg = regs.undefined.r13;
        endcase
      end

      4'd14: begin
        unique case (mode)
          CPU_MODE_USR, CPU_MODE_SYS: read_reg = regs.user.r14;
          CPU_MODE_FIQ: read_reg = regs.fiq.r14;
          CPU_MODE_SVC: read_reg = regs.supervisor.r14;
          CPU_MODE_ABT: read_reg = regs.abort.r14;
          CPU_MODE_IRQ: read_reg = regs.irq.r14;
          CPU_MODE_UND: read_reg = regs.undefined.r14;
        endcase
      end

      // R15 : PC (always user)
      4'd15: read_reg = regs.user.r15;

    endcase
  endfunction


  function automatic logic mode_has_spsr(cpu_mode_t mode);
    unique case (mode)
      CPU_MODE_FIQ, CPU_MODE_IRQ, CPU_MODE_SVC, CPU_MODE_ABT, CPU_MODE_UND: mode_has_spsr = 1'b1;
      CPU_MODE_USR, CPU_MODE_SYS: mode_has_spsr = 1'b0;  // USR/SYS
    endcase
  endfunction

  function automatic word_t read_spsr(input cpu_regs_t regs, input cpu_mode_t mode);
    unique case (mode)
      CPU_MODE_FIQ: read_spsr = regs.SPSR.fiq;
      CPU_MODE_IRQ: read_spsr = regs.SPSR.irq;
      CPU_MODE_SVC: read_spsr = regs.SPSR.supervisor;
      CPU_MODE_ABT: read_spsr = regs.SPSR.abort;
      CPU_MODE_UND: read_spsr = regs.SPSR.undefined;
      CPU_MODE_USR, CPU_MODE_SYS: read_spsr = regs.CPSR;  // don't-care; should not be used
    endcase
  endfunction

  function automatic alu_writeback_source_t get_alu_writeback(input alu_op_t opcode);
    case (opcode)
      ALU_OP_CMP, ALU_OP_CMP_NEG, ALU_OP_TEST, ALU_OP_TEST_EXCLUSIVE: begin
        return ALU_WB_NONE;
      end

      default: begin
        return ALU_WB_REG_RD;
      end
    endcase
  endfunction

  /// TODO: Look into replacing with $countones / $countbits
  function automatic logic [3:0] count_ones(input logic [15:0] value);
    logic [3:0] count;
    count = 4'd0;
    for (logic [4:0] i = 0; i < 16; i++) begin
      count += 4'(value[4'(i)]);
    end
    return count;
  endfunction

  /// Finds the first i'th 1 bit in `value`.
  // TODO: this should be a priority encoder
  function automatic logic [3:0] get_ith_bit(input logic [3:0] i, input logic [15:0] value);
    logic [3:0] found;
    found = 4'd0;
    for (logic [4:0] j = 0; j < 16; j++) begin
      if (value[4'(j)]) begin
        if (found == i) begin
          return 4'(j);
        end
        found += 4'd1;
      end
    end
    return 4'd0;
  endfunction : get_ith_bit

  function automatic logic [4:0] update_cpsr_mode(input exception_t exception);
    unique case (exception)
      EXCEPTION_NONE: update_cpsr_mode = 5'b10000;  // USR
      EXCEPTION_RESET: update_cpsr_mode = 5'b10000;  // TODO
      EXCEPTION_UNDEFINED: update_cpsr_mode = 5'b11011;  // UND
      EXCEPTION_SWI: update_cpsr_mode = 5'b10011;  // SVC
      EXCEPTION_PABT: update_cpsr_mode = 5'b10111;  // ABT
      EXCEPTION_DABT: update_cpsr_mode = 5'b10111;  // ABT
      EXCEPTION_IRQ: update_cpsr_mode = 5'b10010;  // IRQ
      EXCEPTION_FIQ: update_cpsr_mode = 5'b10001;  // FIQ
    endcase
  endfunction : update_cpsr_mode

  function automatic word_t apply_status_mask(input word_t write_data, input word_t status,
                                              input logic [3:0] mask);
    word_t result = status;

    if (mask[3]) result[31:24] = write_data[31:24];  // flags
    if (mask[2]) result[23:16] = write_data[23:16];  // status
    if (mask[1]) result[15:8] = write_data[15:8];  // extension
    if (mask[0]) result[7:0] = write_data[7:0];  // control

    return result;
  endfunction

endpackage : gba_cpu_util_pkg
