import gba_control_types_pkg::*;
import gba_cpu_types_pkg::*;
import gba_cpu_util_pkg::*;
import gba_cpu_decoder_types_pkg::*;
import control_util_pkg::*;

`include "gba/cpu/util.svh"

module GBA_ControlUnit (
    input logic clk,
    input logic reset,
    GBA_Decoder_if.ControlUnit_side decoder_bus,
    input execution_mode_t execution_mode,
    output control_t control_signals,
    input logic flush_req
);

  /// Cycle counter to keep track of which cycle of the instruction we are on
  logic [7:0] cycle;

  logic [2:0] flush_cnt;

  /// We only enable the decoder when we are ready to fetch a new instruction.
  assign decoder_bus.pipeline_advance = control_signals.pipeline_advance;

  always_ff @(posedge clk) begin
    if (reset) begin
      cycle <= 8'd0;
    end else begin
      if (control_signals.pipeline_advance) begin
        $display("\n[ControlUnit] Instruction complete, preparing for next instruction");
        cycle <= 8'd0;
      end else begin
        cycle <= cycle + 8'd1;
        $display("\n[ControlUnit] Instruction not complete");
      end
    end
  end

  always_ff @(posedge clk) begin
    if (reset) begin
      /// Start with a flush so we can fetch the first instruction
      /// This will start flushing next cycle.
      flush_cnt <= 3'd3;
      $display("[ControlUnit] Reset, starting flush");
      $fflush();
    end else if (flush_req) begin
      flush_cnt <= 3'd1;
      $display("[ControlUnit] Flush requested, starting flush");
      $fflush();

    end else if (flush_cnt != 3'd0) begin
      flush_cnt <= flush_cnt - 3'd1;
      $display("[ControlUnit] Flushing, %0d cycles of flush remaining", flush_cnt);
      $fflush();
    end
  end

  always_ff @(posedge clk) begin
    if (reset) begin
    end else begin
      if (decoder_bus.instr_type == ARM_INSTR_DATAPROC_IMM) begin
        `DISPLAY_DECODED_DATAPROC_IMM(decoder_bus.word.arm, decoder_bus.decoded_regs,
                                      decoder_bus.instr_type, decoder_bus.condition_pass)
      end else if (decoder_bus.instr_type == ARM_INSTR_DATAPROC_REG_IMM) begin
        `DISPLAY_DECODED_DATAPROC_REG_IMM(decoder_bus.word.arm, decoder_bus.decoded_regs,
                                          decoder_bus.instr_type, decoder_bus.condition_pass)
      end else if (decoder_bus.instr_type == ARM_INSTR_DATAPROC_REG_REG) begin
        `DISPLAY_DECODED_DATAPROC_REG_REG(decoder_bus.word.arm, decoder_bus.decoded_regs,
                                          decoder_bus.instr_type, decoder_bus.condition_pass)
      end else if (decoder_bus.instr_type == ARM_INSTR_LOAD || decoder_bus.instr_type == ARM_INSTR_STORE) begin
        `DISPLAY_DECODED_LS(decoder_bus.word.arm, decoder_bus.decoded_regs, decoder_bus.instr_type,
                            decoder_bus.condition_pass)
      end else if (decoder_bus.instr_type == ARM_INSTR_LDM || decoder_bus.instr_type == ARM_INSTR_STM) begin
        `DISPLAY_DECODED_BLOCK(decoder_bus.word.arm, decoder_bus.decoded_regs,
                               decoder_bus.instr_type, decoder_bus.condition_pass)
      end else if (decoder_bus.instr_type == ARM_INSTR_LDR_HALF || decoder_bus.instr_type == ARM_INSTR_STR_HALF) begin
        `DISPLAY_DECODED_LS_HALF(decoder_bus.word.arm, decoder_bus.decoded_regs,
                                 decoder_bus.instr_type, decoder_bus.condition_pass)
      end else if (decoder_bus.instr_type == ARM_INSTR_SWAP) begin
        `DISPLAY_DECODED_SWAP(decoder_bus.word.arm, decoder_bus.decoded_regs,
                              decoder_bus.instr_type, decoder_bus.condition_pass)
      end else if (decoder_bus.instr_type == ARM_INSTR_BRANCH || decoder_bus.instr_type == ARM_INSTR_BRANCH_LINK) begin
        `DISPLAY_DECODED_BRANCH(decoder_bus.word.arm, decoder_bus.decoded_regs,
                                decoder_bus.instr_type, decoder_bus.condition_pass)
      end else if (decoder_bus.instr_type == ARM_INSTR_MULTIPLY) begin
        `DISPLAY_DECODED_MULT(decoder_bus.word.arm, decoder_bus.decoded_regs,
                              decoder_bus.instr_type, decoder_bus.condition_pass)
      end else if (decoder_bus.instr_type == ARM_INSTR_MSR) begin
        `DISPLAY_DECODED_MSR(decoder_bus.word.arm, decoder_bus.decoded_regs,
                             decoder_bus.instr_type, decoder_bus.condition_pass)
      end else if (decoder_bus.instr_type == ARM_INSTR_MRS) begin
        `DISPLAY_DECODED_MRS(decoder_bus.word.arm, decoder_bus.decoded_regs,
                             decoder_bus.instr_type, decoder_bus.condition_pass)
      end else begin
        $display("[ControlUnit] Decoded instruction type is undefined");
      end
    end
  end

  always_comb begin
    // For use in block data transfer instructions
    logic [3:0] regs_count;

    regs_count = 4'd0;

    control_signals = '0;

    control_signals.pipeline_advance = 1'b0;

    if (flush_cnt == 3'd3) begin
      /// Start by writing the Address to PC

      control_signals.addr_bus_src = ADDR_SRC_PC;

      $display("[ControlUnit] In reset phase, preparing for flush");
      $fflush();

    end else if (flush_cnt == 3'd2 || flush_req) begin
      /// Plan for fetch and decode next cycle.
      control_signals |= fetch_next_instr();
      control_signals.incrementer_writeback = 1;
      control_signals.addr_bus_src = ADDR_SRC_INCR;

      $display("\n[ControlUnit] Flush cycle 1, fetching instruction");
      $fflush();

    end else if (flush_cnt == 3'd1) begin
      control_signals |= fetch_next_instr();
      control_signals.incrementer_writeback = 1;
      control_signals.addr_bus_src = ADDR_SRC_INCR;
      control_signals.pipeline_advance = 1'b1;

      $display("[ControlUnit] Flush cycle 2, flushing instruction");
      $fflush();

    end else if (decoder_bus.condition_pass == 1'b0) begin
      // If the condition check fails, we still want to advance the pipeline and fetch the next instruction
      control_signals |= fetch_next_instr();
      control_signals.incrementer_writeback = 1;
      control_signals.addr_bus_src = ADDR_SRC_INCR;
      control_signals.pipeline_advance = 1'b1;

      $display(
          "[ControlUnit] Condition check failed, advancing pipeline to fetch next instruction");
      $fflush();

    end else begin

      case (decoder_bus.instr_type)

        // ============================
        // Data Processing (Immediate)
        // ============================

        ARM_INSTR_DATAPROC_IMM: begin
          // $display("[ControlUnit] Decoding data processing immediate instruction with IR=0x%08x",
          //          decoder_bus.word.arm.IR);
          // $fflush();

          if (cycle == 8'd0) begin
            control_signals.B_bus_source = B_BUS_SRC_IMM;
            control_signals.B_bus_imm = 24'(decoder_bus.word.arm.data_proc_imm.imm8);

            control_signals.shift_amount = {decoder_bus.word.arm.data_proc_imm.rotate, 1'b0};

            if (decoder_bus.word.arm.data_proc_imm.use_lsl) control_signals.shift_type = SHIFT_LSL;
            else control_signals.shift_type = SHIFT_ROR;

            control_signals.ALU_op = alu_op_t'(decoder_bus.word.arm.data_proc_imm.opcode);

            control_signals.ALU_writeback = gba_cpu_util_pkg::get_alu_writeback(
                alu_op_t'(decoder_bus.word.arm.data_proc_imm.opcode));
            control_signals.ALU_set_flags = decoder_bus.word.arm.data_proc_imm.set_flags;
            $display("[ControlUnit] ALU writeback source=%0d, set_flags=%b",
                     control_signals.ALU_writeback, control_signals.ALU_set_flags);

            control_signals.pipeline_advance = 1'b1;

            if (decoder_bus.decoded_regs.Rd == 4'd15) begin
              control_signals.restore_cpsr_from_spsr = decoder_bus.word.arm.data_proc_imm.set_flags;
              control_signals.addr_bus_src = ADDR_SRC_ALU;
            end else control_signals.addr_bus_src = ADDR_SRC_INCR;

            if (decoder_bus.word.arm.data_proc_imm.align_flag) begin
              control_signals.A_bus_align = 1'b1;
            end

            control_signals |= fetch_next_instr();
            control_signals.incrementer_writeback = 1'b1;


            $display("[ControlUnit] Decoding complete, preparing for next instruction");
          end
        end

        // ============================
        // Data Processing (Reg + Reg)
        // ============================

        ARM_INSTR_DATAPROC_REG_REG: begin
          // Performs one internal cycle
          // Notably we don't fetch or decode this cycle
          if (cycle == 8'd0) begin
            // decoder_bus.enable = 1'b0;

            // control_signals |= fetch_next_instr();

            control_signals.incrementer_writeback = 1'b1;

            // control_signals.addr_bus_src = ADDR_SRC_INCR;

            control_signals.B_bus_source = B_BUS_SRC_REG_RS;

            control_signals.shift_latch_amt = 1'b1;

            $display("[ControlUnit] Instr done is %b, cycle is %0d",
                     control_signals.pipeline_advance, cycle);
          end

          if (cycle == 8'd1) begin
            control_signals |= fetch_next_instr();

            control_signals.shift_use_latch = 1'b1;

            control_signals.B_bus_source = B_BUS_SRC_REG_RM;

            control_signals.shift_type = decoder_bus.word.arm.data_proc_reg_reg.shift_type;
            control_signals.shift_use_latch = 1'b1;

            control_signals.ALU_op = alu_op_t'(decoder_bus.word.arm.data_proc_reg_reg.opcode);

            control_signals.ALU_writeback = gba_cpu_util_pkg::get_alu_writeback(
                alu_op_t'(decoder_bus.word.arm.data_proc_reg_reg.opcode));
            control_signals.ALU_set_flags = decoder_bus.word.arm.data_proc_reg_reg.set_flags;

            $display("[ControlUnit] 2 Instr done is %b, cycle is %0d",
                     control_signals.pipeline_advance, cycle);

            if (decoder_bus.decoded_regs.Rd == 4'd15) begin
              control_signals.restore_cpsr_from_spsr = decoder_bus.word.arm.data_proc_reg_reg.set_flags;
              control_signals.addr_bus_src = ADDR_SRC_ALU;
            end else control_signals.addr_bus_src = ADDR_SRC_INCR;

            control_signals.pipeline_advance = 1'b1;
          end
        end

        // ============================
        // Data Processing (Reg + Imm)
        // ============================

        ARM_INSTR_DATAPROC_REG_IMM: begin

          control_signals.B_bus_source = B_BUS_SRC_REG_RM;

          control_signals.shift_type = decoder_bus.word.arm.data_proc_reg_imm.shift_type;
          control_signals.shift_amount = decoder_bus.word.arm.data_proc_reg_imm.shift_amount;

          control_signals.ALU_op = alu_op_t'(decoder_bus.word.arm.data_proc_reg_imm.opcode);

          control_signals.ALU_writeback =
              gba_cpu_util_pkg::get_alu_writeback(decoder_bus.word.arm.data_proc_reg_imm.opcode);
          control_signals.ALU_set_flags = decoder_bus.word.arm.data_proc_reg_imm.set_flags;

          if (decoder_bus.word.arm.data_proc_reg_imm.shift_type == SHIFT_ROR &&
              decoder_bus.word.arm.data_proc_reg_imm.shift_amount == 5'd0) begin
            // Register shift-immediate encoding: ROR #0 => RRX
            control_signals.shift_use_rxx = 1'b1;
          end

          control_signals |= fetch_next_instr();

          if (decoder_bus.decoded_regs.Rd == 4'd15) begin
            control_signals.restore_cpsr_from_spsr = decoder_bus.word.arm.data_proc_reg_imm.set_flags;
          end

          if (gba_cpu_util_pkg::get_alu_writeback(
                  decoder_bus.word.arm.data_proc_reg_imm.opcode
              ) == ALU_WB_REG_RD && decoder_bus.decoded_regs.Rd == 4'd15) begin
            control_signals.restore_cpsr_from_spsr = decoder_bus.word.arm.data_proc_reg_imm.set_flags;
            control_signals.addr_bus_src = ADDR_SRC_ALU;
          end else begin
            control_signals.incrementer_writeback = 1'b1;
            control_signals.addr_bus_src = ADDR_SRC_INCR;
          end

          control_signals.pipeline_advance = 1'b1;
        end

        // ============================
        // Multiply
        // ============================

        ARM_INSTR_MULTIPLY: begin
          unique case (decoder_bus.word.arm.mul.opcode)
            ARM_MUL, ARM_MLA: begin
              if (cycle == 8'd0) begin
                $display(
                    "[ControlUnit] Cycle 0 of multiply instruction, preparing for multiplication");
                control_signals.multiplier_enable = 1'b1;

                control_signals.A_bus_source = A_BUS_SRC_RS;
                control_signals.B_bus_source = B_BUS_SRC_REG_RM;

                control_signals.incrementer_writeback = 1'b1;
              end

              if (cycle == 8'd1) begin
                // Process Accumulator
                $display("[ControlUnit] Cycle 1 of multiply instruction");

                control_signals.multiplier_enable = 1'b1;
                control_signals.ALU_writeback = ALU_WB_REG_RD;
                if (decoder_bus.word.arm.mul.opcode == ARM_MUL) begin
                  control_signals.A_bus_source = A_BUS_SRC_IMM;
                  control_signals.A_bus_imm = 7'(0);
                end else if (decoder_bus.word.arm.mul.opcode == ARM_MLA) begin
                  $display("[ControlUnit] Multiply instruction, using Rn (R%0d) as B bus source",
                           decoder_bus.decoded_regs.Rn);
                  control_signals.A_bus_source = A_BUS_SRC_RN;
                end
                control_signals.ALU_op = ALU_OP_MOV;

                control_signals.B_bus_source = B_BUS_SRC_MULTIPLIER;

                control_signals.ALU_set_flags = decoder_bus.word.arm.mul.S;

                control_signals.pipeline_advance = 1'b1;
                control_signals.addr_bus_src = ADDR_SRC_INCR;

                control_signals |= fetch_next_instr();
              end
            end

            ARM_UMULL, ARM_UMLAL, ARM_SMULL, ARM_SMLAL: begin
              if (cycle == 8'd0) begin
                $display(
                    "[ControlUnit] Cycle 0 of multiply instruction, preparing for multiplication");
                control_signals.multiplier_enable = 1'b1;

                control_signals.A_bus_source = A_BUS_SRC_RS;
                control_signals.B_bus_source = B_BUS_SRC_REG_RM;

                control_signals.incrementer_writeback = 1'b1;
              end

              if (cycle == 8'd1) begin
                $display(
                    "[ControlUnit] Cycle 1 of multiply instruction, preparing for multiplication");
                control_signals.multiplier_enable = 1'b1;

                if (decoder_bus.word.arm.mul.opcode == ARM_UMULL || decoder_bus.word.arm.mul.opcode == ARM_SMULL) begin
                  control_signals.A_bus_source = A_BUS_SRC_IMM;
                  control_signals.A_bus_imm = 7'(0);
                end else if (decoder_bus.word.arm.mul.opcode == ARM_UMLAL || decoder_bus.word.arm.mul.opcode == ARM_SMLAL) begin
                  $display("[ControlUnit] Multiply instruction, using Rn (R%0d) as B bus source",
                           decoder_bus.decoded_regs.Rn);
                  control_signals.A_bus_source = A_BUS_SRC_RD;
                end

                if (decoder_bus.word.arm.mul.opcode == ARM_UMULL || decoder_bus.word.arm.mul.opcode == ARM_SMULL) begin
                  control_signals.B_bus_source = B_BUS_SRC_IMM;
                  control_signals.B_bus_imm = 24'(0);
                end else if (decoder_bus.word.arm.mul.opcode == ARM_UMLAL || decoder_bus.word.arm.mul.opcode == ARM_SMLAL) begin
                  $display("[ControlUnit] Multiply instruction, using Rn (R%0d) as B bus source",
                           decoder_bus.decoded_regs.Rn);
                  control_signals.B_bus_source = B_BUS_SRC_REG_RN;
                end
              end

              if (cycle == 8'd2) begin
                // Process Accumulator
                $display("[ControlUnit] Cycle 2 of multiply instruction");

                control_signals.multiplier_enable = 1'b1;
                control_signals.ALU_writeback = ALU_WB_REG_RN;
                control_signals.ALU_op = ALU_OP_MOV;

                control_signals.B_bus_source = B_BUS_SRC_MULTIPLIER;
              end

              if (cycle == 8'd3) begin
                // Process Accumulator
                $display("[ControlUnit] Cycle 3 of multiply instruction");

                control_signals.multiplier_enable = 1'b1;
                control_signals.ALU_writeback = ALU_WB_REG_RD;
                control_signals.ALU_op = ALU_OP_MOV;

                control_signals.B_bus_source = B_BUS_SRC_MULTIPLIER;

                control_signals.mult_set_flags = decoder_bus.word.arm.mul.S;

                control_signals.pipeline_advance = 1'b1;
                control_signals.addr_bus_src = ADDR_SRC_INCR;

                control_signals |= fetch_next_instr();
              end
            end

            default: ;
          endcase

        end

        // ============================
        // Load / Store (Single)
        // ============================

        ARM_INSTR_STORE, ARM_INSTR_LOAD: begin
          if (cycle == 8'd0) begin
            $display("[ControlUnit] Cycle 0 of load/store instruction, calculating address");

            // Perform a fetch in this cycle
            control_signals |= fetch_next_instr();

            // Write PC with Address + 1.
            // This ensures that we can return to the correct address after 
            // the memory access is complete.
            control_signals.incrementer_writeback = 1'b1;

            control_signals |= calc_ls_address(
                decoder_bus.word.arm.ls.U,
                decoder_bus.word.arm.ls.P,
                decoder_bus.word.arm.ls.wt,
                decoder_bus.word.arm.ls.I,
                decoder_bus.word.arm.ls.offset.imm12
            );

            if (decoder_bus.word.arm.ls.align_flag) begin
              control_signals.A_bus_align = 1'b1;
            end

            // Depending on the instruction, operand b can either be an immediate or 
            // a register with optional shift
            if (decoder_bus.word.arm.ls.I == ARM_LDR_STR_IMMEDIATE) begin
              // Immediate offset with an optional rotation/shift

              control_signals.B_bus_source = B_BUS_SRC_IMM;
              control_signals.B_bus_imm = 24'(decoder_bus.word.arm.ls.offset.imm12);

              // No shift
              control_signals.shift_type = SHIFT_LSL;
              control_signals.shift_amount = 5'd0;

            end else begin
              // We are using a register offset with an optional shift

              control_signals.B_bus_source = B_BUS_SRC_REG_RM;
              control_signals.shift_type   = decoder_bus.word.arm.ls.offset.shifted.shift_type;
              control_signals.shift_amount = decoder_bus.word.arm.ls.offset.shifted.shift_amount;

              if (decoder_bus.word.arm.data_proc_reg_imm.shift_type == SHIFT_ROR &&
                  decoder_bus.word.arm.data_proc_reg_imm.shift_amount == 5'd0) begin
                // Register shift-immediate encoding: ROR #0 => RRX
                control_signals.shift_use_rxx = 1'b1;
              end
            end
          end

          if (decoder_bus.instr_type == ARM_INSTR_LOAD) begin

            if (cycle == 8'd1) begin

              $display(
                  "[ControlUnit] Cycle 1 of load instruction, address calculation done, preparing for memory read and writeback");

              control_signals.ALU_op = decoder_bus.word.arm.ls.U ? ALU_OP_ADD : ALU_OP_SUB;

              // Do we writeback?
              if (decoder_bus.word.arm.ls.P == ARM_LDR_STR_POST_OFFSET 
                  || decoder_bus.word.arm.ls.wt == 1'b1) begin
                // Since we are writing back to the base register, 
                // we need to make sure to use the offset for the writeback
                // which we latched in the previous cycle
                control_signals.ALU_use_op_b_latch = 1'b1;
                control_signals.ALU_writeback = ALU_WB_REG_RN;

                $display("[ControlUnit] Load instruction requires writeback to base register R%0d",
                         decoder_bus.decoded_regs.Rn);
              end

              control_signals.memory_byte_transfer = decoder_bus.word.arm.ls.B;

              control_signals.memory_read_en = 1'b1;

              // Load the PC back into the address bus
              control_signals.addr_bus_src = ADDR_SRC_PC;

            end

            if (cycle == 8'd2) begin
              $display(
                  "[ControlUnit] Cycle 2 of load instruction, latching read data and preparing for writeback");

              control_signals.pipeline_advance = 1'b1;

              // Allows op B to pass through the ALU unmodified
              control_signals.ALU_op = ALU_OP_MOV;

              // Uses the value read from memory as the value to write 
              // back to the register file
              control_signals.B_bus_source = B_BUS_SRC_READ_DATA;

              // Write back to Rd from the ALU output, which is the 
              // value read from memory
              control_signals.ALU_writeback = ALU_WB_REG_RD;

              control_signals.memory_byte_transfer = decoder_bus.word.arm.ls.B;

              // Load the PC back into the address bus
              control_signals.addr_bus_src = ADDR_SRC_PC;

            end
          end

          if (decoder_bus.instr_type == ARM_INSTR_STORE) begin
            if (cycle == 8'd1) begin
              control_signals.pipeline_advance = 1'b1;

              control_signals.B_bus_source = B_BUS_SRC_REG_RD;

              control_signals.ALU_op = decoder_bus.word.arm.ls.U ? ALU_OP_ADD : ALU_OP_SUB;

              control_signals.memory_write_en = 1'b1;

              control_signals.memory_byte_transfer = decoder_bus.word.arm.ls.B;

              // Do we writeback?
              if (decoder_bus.word.arm.ls.P == ARM_LDR_STR_POST_OFFSET 
                  || decoder_bus.word.arm.ls.wt == 1'b1) begin
                // Since we are writing back to the base register, 
                // we need to make sure to use the offset for the writeback
                // which we latched in the previous cycle
                control_signals.ALU_use_op_b_latch = 1'b1;
                control_signals.ALU_writeback = ALU_WB_REG_RN;

                $display("[ControlUnit] Store instruction requires writeback to base register R%0d",
                         decoder_bus.decoded_regs.Rn);
              end

              // Load the PC back into the address bus
              control_signals.addr_bus_src = ADDR_SRC_PC;
            end
          end
        end

        ARM_INSTR_LDR_HALF, ARM_INSTR_STR_HALF: begin
          // TODO: This is copied from above, but we need to put this into a function.
          if (cycle == 8'd0) begin
            $display("[ControlUnit] Cycle 0 of load/store instruction, calculating address");

            // Perform a fetch in this cycle
            control_signals |= fetch_instr_early();

            // Write PC with Address + 1.
            // This ensures that we can return to the correct address after 
            // the memory access is complete.
            control_signals.incrementer_writeback = 1'b1;

            control_signals |= calc_ls_address(
                decoder_bus.word.arm.ls_half.U,
                decoder_bus.word.arm.ls_half.P,
                decoder_bus.word.arm.ls_half.W,
                decoder_bus.word.arm.ls_half.I,
                12'(decoder_bus.word.arm.ls_half.imm_offset)
            );

            // Depending on the instruction, operand b can either be an immediate or 
            // a register with optional shift
            if (decoder_bus.word.arm.ls_half.I) begin
              // Immediate offset with an optional rotation/shift

              control_signals.B_bus_source = B_BUS_SRC_IMM;
              control_signals.B_bus_imm = 24'(decoder_bus.word.arm.ls_half.imm_offset);

              // No shift
              control_signals.shift_type = SHIFT_LSL;
              control_signals.shift_amount = 5'd0;

            end else begin
              // We are using a register offset

              control_signals.B_bus_source = B_BUS_SRC_REG_RM;

              // No shift
              control_signals.shift_type   = SHIFT_LSL;
              control_signals.shift_amount = 5'd0;
            end
          end

          if (decoder_bus.instr_type == ARM_INSTR_LDR_HALF) begin
            if (cycle == 8'd1) begin

              $display(
                  "[ControlUnit] Cycle 1 of load instruction, address calculation done, preparing for memory read and writeback");

              control_signals.ALU_op = decoder_bus.word.arm.ls_half.U ? ALU_OP_ADD : ALU_OP_SUB;

              // Do we writeback?
              if (decoder_bus.word.arm.ls_half.P == ARM_LDR_STR_POST_OFFSET 
                  || decoder_bus.word.arm.ls_half.W == 1'b1) begin
                // Since we are writing back to the base register, 
                // we need to make sure to use the offset for the writeback
                // which we latched in the previous cycle
                control_signals.ALU_use_op_b_latch = 1'b1;
                control_signals.ALU_writeback = ALU_WB_REG_RN;

                $display("[ControlUnit] Load instruction requires writeback to base register R%0d",
                         decoder_bus.decoded_regs.Rn);
              end

              if (decoder_bus.word.arm.ls_half.opcode == ARM_LOAD_STORE_HALFWORD) begin
                control_signals.memory_halfword_transfer = 1'b1;
              end else if (decoder_bus.word.arm.ls_half.opcode == ARM_LOAD_SIGNED_HALFWORD) begin
                control_signals.memory_signed_transfer   = 1'b1;
                control_signals.memory_halfword_transfer = 1'b1;
              end else if (decoder_bus.word.arm.ls_half.opcode == ARM_LOAD_SIGNED_BYTE) begin
                control_signals.memory_byte_transfer   = 1'b1;
                control_signals.memory_signed_transfer = 1'b1;
              end

              control_signals.memory_read_en = 1'b1;

              // Load the PC back into the address bus
              control_signals.addr_bus_src   = ADDR_SRC_PC;
            end

            if (cycle == 8'd2) begin
              $display(
                  "[ControlUnit] Cycle 2 of load instruction, latching read data and preparing for writeback");

              control_signals.pipeline_advance = 1'b1;

              // Allows op B to pass through the ALU unmodified
              control_signals.ALU_op = ALU_OP_MOV;

              // Uses the value read from memory as the value to write 
              // back to the register file
              control_signals.B_bus_source = B_BUS_SRC_READ_DATA;

              // Write back to Rd from the ALU output, which is the 
              // value read from memory
              control_signals.ALU_writeback = ALU_WB_REG_RD;

              if (decoder_bus.word.arm.ls_half.opcode == ARM_LOAD_STORE_HALFWORD) begin
                control_signals.memory_halfword_transfer = 1'b1;
              end else if (decoder_bus.word.arm.ls_half.opcode == ARM_LOAD_SIGNED_HALFWORD) begin
                control_signals.memory_signed_transfer   = 1'b1;
                control_signals.memory_halfword_transfer = 1'b1;
              end else if (decoder_bus.word.arm.ls_half.opcode == ARM_LOAD_SIGNED_BYTE) begin
                control_signals.memory_byte_transfer   = 1'b1;
                control_signals.memory_signed_transfer = 1'b1;
              end

              control_signals.memory_advance_early_fetched_IR = 1'b1;

              // Load the PC back into the address bus
              control_signals.addr_bus_src = ADDR_SRC_PC;

            end
          end else if (decoder_bus.instr_type == ARM_INSTR_STR_HALF) begin
            if (cycle == 8'd1) begin
              $display(
                  "[ControlUnit] Cycle 1 of store instruction, address calculation done, preparing for memory write");

              control_signals.pipeline_advance = 1'b1;

              control_signals.B_bus_source = B_BUS_SRC_REG_RD;

              control_signals.ALU_op = decoder_bus.word.arm.ls_half.U ? ALU_OP_ADD : ALU_OP_SUB;

              control_signals.memory_write_en = 1'b1;

              control_signals.memory_halfword_transfer = 1'b1;

              // Do we writeback?
              if (decoder_bus.word.arm.ls_half.P == ARM_LDR_STR_POST_OFFSET 
                  || decoder_bus.word.arm.ls_half.W == 1'b1) begin
                // Since we are writing back to the base register, 
                // we need to make sure to use the offset for the writeback
                // which we latched in the previous cycle
                control_signals.ALU_use_op_b_latch = 1'b1;
                control_signals.ALU_writeback = ALU_WB_REG_RN;

                $display("[ControlUnit] Store instruction requires writeback to base register R%0d",
                         decoder_bus.decoded_regs.Rn);
              end

              control_signals.memory_advance_early_fetched_IR = 1'b1;

              // Load the PC back into the address bus
              control_signals.addr_bus_src = ADDR_SRC_PC;
            end
          end

          $display("[ControlUnit] Detected halfword load/store instruction");
        end

        // TODO: Only make byte_transfer high when its needed
        ARM_INSTR_SWAP: begin
          $display("[ControlUnit] Detected SWP instruction");
          if (cycle == 8'd0) begin
            control_signals |= fetch_next_instr();

            // Save address so we can return to it
            control_signals.incrementer_writeback = 1'b1;

            // We don't need to modify Rn in any way
            control_signals.ALU_disable_op_b = 1'b1;

            // Update address with Rn
            control_signals.A_bus_source = A_BUS_SRC_RN;
            control_signals.addr_bus_src = ADDR_SRC_ALU;
            control_signals.ALU_op = ALU_OP_ADD;

            control_signals.memory_byte_transfer = decoder_bus.word.arm.swap.B;
          end

          if (cycle == 8'd1) begin
            control_signals.memory_read_en = 1'b1;
            control_signals.memory_byte_transfer = decoder_bus.word.arm.swap.B;
          end

          if (cycle == 8'd2) begin
            control_signals.B_bus_source   = B_BUS_SRC_READ_DATA;
            control_signals.ALU_latch_op_b = 1'b1;
          end

          if (cycle == 8'd3) begin
            control_signals.A_bus_source = A_BUS_SRC_RD;
            control_signals.ALU_use_op_b_latch = 1'b1;
            control_signals.ALU_op = ALU_OP_MOV;

            control_signals.memory_byte_transfer = decoder_bus.word.arm.swap.B;

            control_signals.B_bus_source = B_BUS_SRC_REG_RM;
            control_signals.ALU_writeback = ALU_WB_REG_RD;
            control_signals.memory_write_en = 1'b1;

            control_signals.pipeline_advance = 1'b1;

            // Restore address from PC
            control_signals.addr_bus_src = ADDR_SRC_PC;
          end
        end

        // ============================
        // Load / Store (Block)
        // ============================

        ARM_INSTR_LDM, ARM_INSTR_STM: begin
          regs_count = count_ones(decoder_bus.word.arm.block.reg_list);

          control_signals.force_user_mode =
            decoder_bus.word.arm.block.S &&
            (
              (decoder_bus.instr_type == ARM_INSTR_STM) ||
              (decoder_bus.instr_type == ARM_INSTR_LDM && !decoder_bus.word.arm.block.reg_list[15])
            );

          control_signals.force_no_align_pc = decoder_bus.word.arm.block.force_no_align_pc;

          // First cycle: Prefetch and calculate first address
          if (cycle == 8'd0) begin
            // // Perform a prefetch
            // control_signals |= fetch_next_instr();

            // // Stash address in PC so we can return later
            // control_signals.stash_addr = 1'b1;

            control_signals.incrementer_writeback = 1'b1;

            // Update address for next cycle
            control_signals.addr_bus_src = ADDR_SRC_ALU;

            control_signals.B_bus_source = B_BUS_SRC_REG_RN;

            control_signals.A_bus_source = A_BUS_SRC_IMM;
            control_signals.A_bus_imm = regs_count * 4;

            // If its pre offset we add/subtract the offset to the base register before the memory access
            if (decoder_bus.word.arm.block.P == ARM_LDR_STR_PRE_OFFSET) begin
              if (decoder_bus.word.arm.block.W == 1'b1) begin
                // Updating the base register with the offset is enabled so we 
                // latch operand b for the writeback in the next cycle
                control_signals.ALU_latch_op_b = 1'b1;

                $display(
                    "[ControlUnit] Block load/store with pre-indexing and writeback, latching offset for writeback");
              end

              if (decoder_bus.word.arm.block.U == 1'b1) begin
                if (regs_count == 0) control_signals.A_bus_imm = 7'h40;
                else control_signals.A_bus_imm = 7'd4;

                control_signals.ALU_op = ALU_OP_ADD;

                $display(
                    "[ControlUnit] Block load/store with pre-indexing and writeback, adding offset to base register R%0d before memory access",
                    decoder_bus.decoded_regs.Rn);
              end else begin
                if (regs_count == 0) control_signals.A_bus_imm = 7'h40;
                else control_signals.A_bus_imm = 6'(regs_count) * 4;

                control_signals.ALU_op = ALU_OP_SUB_REVERSED;

                $display(
                    "[ControlUnit] Block load/store with pre-indexing and writeback, subtracting offset from base register R%0d before memory access",
                    decoder_bus.decoded_regs.Rn);
              end
            end else begin  // POST OFFSET 

              // For block transfers, we must generate the FIRST transfer address here.

              if (decoder_bus.word.arm.block.U == 1'b1) begin
                // Increment After (IA)
                control_signals.ALU_op = ALU_OP_MOV;

              end else begin
                // Decrement After (DA)

                control_signals.A_bus_source = A_BUS_SRC_IMM;
                control_signals.A_bus_imm = (regs_count * 4) - 4;

                control_signals.ALU_op = ALU_OP_SUB_REVERSED;
              end

              // Still latch for writeback
              control_signals.ALU_latch_op_b = 1'b1;
            end

            $display("[ControlUnit] Cycle 0 of LDM instruction, calculating address");
          end else if (decoder_bus.instr_type == ARM_INSTR_LDM) begin

            // Optionally writeback address to Rn and 
            // fetch first first word from memory
            if (cycle == 8'd1) begin

              // Read the first word in the block
              control_signals.memory_read_en = 1'b1;

              // Increment address for next (sequential) memory access
              control_signals.addr_bus_src = ADDR_SRC_INCR;
              control_signals.addr_incr_force_p4 = 1'b1;

              control_signals.A_bus_source = A_BUS_SRC_IMM;
              control_signals.A_bus_imm = regs_count * 4;

              control_signals.ALU_op = decoder_bus.word.arm.block.U ? ALU_OP_ADD : ALU_OP_SUB_REVERSED;

              if (regs_count == 0) begin
                control_signals.ALU_use_op_b_latch = 1'b1;
                control_signals.ALU_writeback = ALU_WB_REG_RN;
                control_signals.A_bus_imm = 7'h40;
              end else

              // Do we writeback?
              // We do so if the base register is not in the register list
              if (decoder_bus.word.arm.block.reg_list[decoder_bus.decoded_regs.Rn] == 1'b0 &&
                  decoder_bus.word.arm.block.W == 1'b1) begin
                // Since we are writing back to the base register, 
                // we need to make sure to use the offset for the writeback
                // which we latched in the previous cycle
                control_signals.ALU_use_op_b_latch = 1'b1;
                control_signals.ALU_writeback = ALU_WB_REG_RN;

                $display("[ControlUnit] Load instruction requires writeback to base register R%0d",
                         decoder_bus.decoded_regs.Rn);
              end

              $display(
                  "[ControlUnit] Cycle 1 of LDM instruction, address calculation done, preparing for memory read");
            end else

            // Latch the last fetched word into the register file and 
            // increment address for the next memory access
            if (cycle < 8'(regs_count)) begin
              control_signals.Rp_imm =
                  get_ith_bit(4'(cycle - 8'd2), decoder_bus.word.arm.block.reg_list);

              control_signals.ALU_writeback = ALU_WB_REG_RP;

              control_signals.B_bus_source = B_BUS_SRC_READ_DATA;

              control_signals.addr_bus_src = ADDR_SRC_INCR;
              control_signals.addr_incr_force_p4 = 1'b1;

              // Read the next word in the block
              control_signals.memory_read_en = 1'b1;

              // Let the B_bus word pass through the ALU unmodified for the writeback
              control_signals.ALU_op = ALU_OP_MOV;
            end else

            // Latch the last fetched word into the register file and
            // update the address bus back to PC for the next instruction
            // So we can fetch next cycle
            if (cycle == 8'(regs_count)) begin
              control_signals.Rp_imm =
                  get_ith_bit(4'(cycle - 8'd2), decoder_bus.word.arm.block.reg_list);

              control_signals.ALU_writeback = ALU_WB_REG_RP;

              control_signals.B_bus_source = B_BUS_SRC_READ_DATA;

              control_signals.addr_bus_src = ADDR_SRC_PC;

              // Read the next word in the block
              control_signals.memory_read_en = 1'b1;

              // Let the B_bus word pass through the ALU unmodified for the writeback
              control_signals.ALU_op = ALU_OP_MOV;
            end else

            // Latch the final fetched word into the register file and 
            // update the address bus back to PC for the next instruction
            if (cycle == 8'd1 + 8'(regs_count) && regs_count != 0) begin

              // If in the final cycle, r15 is being written too,
              // then we need to update the address as well.

              if (decoder_bus.word.arm.block.reg_list[15]) begin
                control_signals.addr_bus_src = ADDR_SRC_ALU;
              end else begin
                control_signals.addr_bus_src = ADDR_SRC_INCR;
              end

              control_signals |= fetch_next_instr();

              control_signals.ALU_writeback = ALU_WB_REG_RP;
              control_signals.Rp_imm =
                  get_ith_bit(4'(cycle - 8'd2), decoder_bus.word.arm.block.reg_list);

              // Let the B_bus word pass through the ALU unmodified for the writeback
              control_signals.ALU_op = ALU_OP_MOV;

              control_signals.B_bus_source = B_BUS_SRC_READ_DATA;

              control_signals.pipeline_advance = 1'b1;

              if (decoder_bus.word.arm.block.S && decoder_bus.word.arm.block.reg_list[15]) begin
                control_signals.restore_cpsr_from_spsr = 1'b1;
                $display(
                    "[ControlUnit] Load instruction with S bit set and PC in reg list, restoring CPSR from SPSR");
              end

              $display(
                  "[ControlUnit] Cycle %0d of LDM instruction, latching final word and preparing for next instruction",
                  cycle);
            end

            if (cycle == 8'd2 && regs_count == 0) begin
              control_signals.addr_bus_src = ADDR_SRC_PC;

              control_signals.ALU_writeback = ALU_WB_REG_RP;
              control_signals.Rp_imm = 4'd15;

              // Let the B_bus word pass through the ALU unmodified for the writeback
              control_signals.ALU_op = ALU_OP_MOV;

              control_signals.B_bus_source = B_BUS_SRC_READ_DATA;

              control_signals.pipeline_advance = 1'b1;

              $display(
                  "[ControlUnit] Cycle %0d of LDM instruction, reg list is empty latching final word and preparing for next instruction",
                  cycle);
            end
          end else if (decoder_bus.instr_type == ARM_INSTR_STM) begin
            if (cycle == 8'd1 && regs_count == 0) begin
              control_signals.Rp_imm = 4'd15;

              // Write the next register in the block to memory
              control_signals.memory_write_en = 1'b1;

              control_signals.B_bus_source = B_BUS_SRC_REG_RP;

              control_signals.A_bus_source = A_BUS_SRC_IMM;
              control_signals.A_bus_imm = 7'h40;

              control_signals.ALU_op = decoder_bus.word.arm.block.U ? ALU_OP_ADD : ALU_OP_SUB_REVERSED;

              control_signals.ALU_use_op_b_latch = 1'b1;
              control_signals.ALU_writeback = ALU_WB_REG_RN;

              control_signals.addr_bus_src = ADDR_SRC_PC;

              control_signals.pipeline_advance = 1'b1;

              $display(
                  "[ControlUnit] Cycle 1 of STM instruction, address calculation done, preparing for memory write");
            end else

            // Optionally writeback address to Rn and 
            // write first first word to memory
            if (cycle == 8'd1) begin
              control_signals.Rp_imm =
                  get_ith_bit(4'(cycle - 8'd1), decoder_bus.word.arm.block.reg_list);

              // Write the next register in the block to memory
              control_signals.memory_write_en = 1'b1;

              control_signals.B_bus_source = B_BUS_SRC_REG_RP;

              // Increment address for next (sequential) memory access
              control_signals.addr_bus_src = ADDR_SRC_INCR;
              control_signals.addr_incr_force_p4 = 1'b1;

              control_signals.A_bus_source = A_BUS_SRC_IMM;
              control_signals.A_bus_imm = regs_count * 4;

              control_signals.ALU_op = decoder_bus.word.arm.block.U ? ALU_OP_ADD : ALU_OP_SUB_REVERSED;

              // Do we writeback?
              if (decoder_bus.word.arm.block.W == 1'b1) begin
                // Since we are writing back to the base register, 
                // we need to make sure to use the offset for the writeback
                // which we latched in the previous cycle
                control_signals.ALU_use_op_b_latch = 1'b1;
                control_signals.ALU_writeback = ALU_WB_REG_RN;

                $display("[ControlUnit] Store instruction requires writeback to base register R%0d",
                         decoder_bus.decoded_regs.Rn);
              end

              $display(
                  "[ControlUnit] Cycle 1 of STM instruction, address calculation done, preparing for memory write");
            end else

            // Write the current register into memory and 
            // increment address for the next memory access
            if (cycle < 8'(regs_count)) begin
              control_signals.Rp_imm =
                  get_ith_bit(4'(cycle - 8'd1), decoder_bus.word.arm.block.reg_list);

              control_signals.B_bus_source = B_BUS_SRC_REG_RP;

              control_signals.addr_bus_src = ADDR_SRC_INCR;
              control_signals.addr_incr_force_p4 = 1'b1;

              // Write the next word in the block
              control_signals.memory_write_en = 1'b1;

              $display("[ControlUnit] Cycle %0d of STM instruction, writing register R%0d to data",
                       cycle, control_signals.Rp_imm);

            end else

            // Write the current register into memory and 
            // update the address bus back to PC for the next instruction
            if (cycle == 8'(regs_count)) begin
              control_signals.Rp_imm =
                  get_ith_bit(4'(cycle - 8'd1), decoder_bus.word.arm.block.reg_list);

              control_signals.B_bus_source = B_BUS_SRC_REG_RP;

              control_signals.addr_bus_src = ADDR_SRC_PC_RESTORE;

              // Write the next word in the block
              control_signals.memory_write_en = 1'b1;

              $display("[ControlUnit] Cycle %0d of STM instruction, writing register R%0d to data",
                       cycle, control_signals.Rp_imm);

            end else

            // We do not write this block. Instead we fetch the next instruction
            // from memory and latch it to the fetched IR
            if (cycle == 8'd1 + 8'(regs_count)) begin

              control_signals |= fetch_next_instr();
              // control_signals.incrementer_writeback = 1'b1;

              control_signals.Rp_imm =
                  get_ith_bit(4'(cycle - 8'd1), decoder_bus.word.arm.block.reg_list);

              control_signals.B_bus_source = B_BUS_SRC_REG_RP;

              control_signals.addr_bus_src = ADDR_SRC_INCR;

              // We do not write the next word in the block
              control_signals.memory_write_en = 1'b0;

              control_signals.pipeline_advance = 1'b1;

              $display(
                  "[ControlUnit] Cycle %0d of STM instruction writing register R%0d to data, and preparing for next instruction",
                  cycle, control_signals.Rp_imm);
            end

          end

          $display("[ControlUnit] Detected multiple data transfer instruction.");
        end

        // ============================
        // Branch
        // ============================

        ARM_INSTR_BRANCH: begin
          $display("[ControlUnit] Detected branch instruction, preparing to update PC");
          if (cycle == 8'd0) begin
            control_signals.ALU_op = ALU_OP_ADD;
            control_signals.addr_bus_src = ADDR_SRC_ALU;

            control_signals.A_bus_source = A_BUS_SRC_RN;

            control_signals.ALU_writeback = ALU_WB_REG_RN;

            control_signals.B_bus_source = B_BUS_SRC_IMM;
            control_signals.B_bus_imm = decoder_bus.word.arm.branch.imm24;
            control_signals.B_bus_sign_extend = 1'b1;

            control_signals.shift_type = SHIFT_LSL;
            control_signals.shift_amount = 5'd2;

            control_signals.pipeline_advance = 1'b1;
          end
        end

        // TODO: Currently this instr lasts an extra cycle. We need to overlap the fetch and cycle 2.
        ARM_INSTR_BRANCH_LINK: begin
          if (cycle == 8'd0) begin
            // Rd should be R14 (LR)
            control_signals.ALU_writeback = ALU_WB_REG_RD;

            control_signals.ALU_op = ALU_OP_SUB;
            control_signals.A_bus_source = A_BUS_SRC_RN;

            control_signals.B_bus_source = B_BUS_SRC_IMM;
            control_signals.B_bus_imm = 24'd4;

            $display("[ControlUnit] Branch with Link instruction, writing return address to R%0d",
                     decoder_bus.decoded_regs.Rd);
          end

          if (cycle == 8'd1) begin
            control_signals.ALU_op = ALU_OP_ADD;
            control_signals.addr_bus_src = ADDR_SRC_ALU;

            control_signals.A_bus_source = A_BUS_SRC_RN;

            control_signals.ALU_writeback = ALU_WB_REG_RN;

            control_signals.B_bus_source = B_BUS_SRC_IMM;
            control_signals.B_bus_imm = decoder_bus.word.arm.branch.imm24;
            control_signals.B_bus_sign_extend = 1'b1;

            control_signals.shift_type = SHIFT_LSL;
            control_signals.shift_amount = 5'd2;

            control_signals.pipeline_advance = 1'b1;
          end
        end

        ARM_INSTR_BRANCH_EX: begin
          if (cycle == 8'd0) begin
            control_signals.ALU_op = ALU_OP_MOV;
            control_signals.addr_bus_src = ADDR_SRC_ALU;

            // control_signals.ALU_writeback = ALU_WB_REG_RP;
            // control_signals.Rp_imm = 4'd15;
            // pe
            control_signals.B_bus_source = B_BUS_SRC_REG_RN;

            control_signals.set_thumb_mode = 1'b1;

            control_signals.pipeline_advance = 1'b1;

            $display(
                "[ControlUnit] Branch Exchange instruction, switching to Thumb mode and updating PC");
          end
        end

        ARM_INSTR_SWI: begin
          if (cycle == 8'd0) begin
            // Rd should be R14 (LR)
            control_signals.ALU_writeback = ALU_WB_REG_RD;

            control_signals.ALU_op = ALU_OP_SUB;
            control_signals.A_bus_source = A_BUS_SRC_RN;

            control_signals.B_bus_source = B_BUS_SRC_IMM;
            control_signals.B_bus_imm = 24'd4;

            control_signals.exception = EXCEPTION_SWI;

            $display(
                "[ControlUnit] Software Interrupt instruction, writing return address to R%0d and preparing for exception handling",
                decoder_bus.decoded_regs.Rd);

            control_signals.pipeline_advance = 1'b1;
          end
        end

        // ============================
        // PSR Transfer
        // ============================
        ARM_INSTR_MRS: begin
          $display("[ControlUnit] Detected PSR transfer instruction");
          if (cycle == 8'd0) begin
            unique case (decoder_bus.word.arm.mrs.psr)
              ARM_PSR_CPSR: begin
                control_signals.B_bus_source = B_BUS_SRC_CPSR;
              end

              ARM_PSR_SPSR: begin
                control_signals.B_bus_source = B_BUS_SRC_SPSR;
                $display(
                    "[ControlUnit] MRS instruction accessing SPSR, only valid in privileged modes");
              end
            endcase

            $display("[ControlUnit] Detected MRS instruction accessing %s",
                     decoder_bus.word.arm.mrs.psr == ARM_PSR_CPSR ? "CPSR" : "SPSR");

            control_signals |= fetch_next_instr();
            control_signals.pipeline_advance = 1'b1;
            control_signals.incrementer_writeback = 1'b1;
            control_signals.addr_bus_src = ADDR_SRC_INCR;

            control_signals.ALU_op = ALU_OP_MOV;
            control_signals.ALU_writeback = ALU_WB_REG_RD;

            $display("[ControlUnit] MRS instruction, moving CPSR to R%0d",
                     decoder_bus.decoded_regs.Rd);
          end
        end

        ARM_INSTR_MSR: begin
          $display("[ControlUnit] Detected PSR transfer instruction");
          if (cycle == 8'd0) begin
            $display("[ControlUnit] MSR instruction, moving R%0d to CPSR",
                     decoder_bus.decoded_regs.Rm);
            control_signals.ALU_op = ALU_OP_MOV;

            control_signals |= fetch_next_instr();
            control_signals.pipeline_advance = 1'b1;
            control_signals.incrementer_writeback = 1'b1;
            control_signals.addr_bus_src = ADDR_SRC_INCR;

            control_signals.status_reg_write_mask = {
              decoder_bus.word.arm.msr.f,
              decoder_bus.word.arm.msr.s,
              decoder_bus.word.arm.msr.x,
              decoder_bus.word.arm.msr.c
            };

            unique case (decoder_bus.word.arm.msr.psr)
              ARM_PSR_CPSR: begin
                control_signals.ALU_writeback = ALU_WB_REG_CSPR;
              end

              ARM_PSR_SPSR: begin
                control_signals.ALU_writeback = ALU_WB_REG_SPSR;
              end
            endcase

            if (decoder_bus.word.arm.msr.I) begin
              control_signals.B_bus_source = B_BUS_SRC_IMM;
              control_signals.B_bus_imm = {16'd0, decoder_bus.word.arm.msr.imm8};
              control_signals.shift_type = SHIFT_ROR;
              control_signals.shift_amount = decoder_bus.word.arm.msr.rotate << 1;
            end else begin
              control_signals.B_bus_source = B_BUS_SRC_REG_RM;
              control_signals.shift_type   = SHIFT_LSL;
              control_signals.shift_amount = 5'd0;
            end
          end
        end

        default: ;
      endcase
    end
  end

endmodule : GBA_ControlUnit
