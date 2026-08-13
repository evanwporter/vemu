`include "gba/util/logger.svh"

import gba_types_pkg::*;
import gba_cpu_types_pkg::*;
import gba_control_types_pkg::*;
import gba_cpu_util_pkg::*;
import gba_mmu_types_pkg::*;

`include "gba/cpu/util.svh"

module ARM7TMDI (
    input logic clk,
    input logic reset,

    GBA_Bus_if.Master_side bus
);

  control_t control_signals;

  word_t IR;

  word_t early_fetched_IR;

  logic flush_req;
  logic flush_req_pending;

  cpu_regs_t regs;

  word_t A_bus;
  word_t B_bus;

  cpu_mode_t cpu_mode;

  /// Data that has been latched from the read bus
  word_t read_data;

  execution_mode_t execution_mode;
  assign execution_mode = execution_mode_t'(regs.CPSR[5]);

  (* maybe_unused *)
  wire [15:0] IR_THUMB = IR[15:0];

  always_comb begin
    if (control_signals.exception != EXCEPTION_NONE) begin
      // TODO: think about combining with `update_cpsr_mode`
      unique case (control_signals.exception)
        EXCEPTION_NONE: cpu_mode = CPU_MODE_USR;  // Impossible to reach
        EXCEPTION_RESET: cpu_mode = CPU_MODE_USR;  // TODO;
        EXCEPTION_UNDEFINED: cpu_mode = CPU_MODE_UND;
        EXCEPTION_SWI: cpu_mode = CPU_MODE_SVC;
        EXCEPTION_PABT: cpu_mode = CPU_MODE_ABT;
        EXCEPTION_DABT: cpu_mode = CPU_MODE_ABT;
        EXCEPTION_IRQ: cpu_mode = CPU_MODE_IRQ;
        EXCEPTION_FIQ: cpu_mode = CPU_MODE_FIQ;
      endcase
    end else begin
      unique casez (regs.CPSR[4:0])

        5'b0??00: cpu_mode = CPU_MODE_USR;  // Old User
        5'b0??01: cpu_mode = CPU_MODE_FIQ;  // Old FIQ
        5'b0??10: cpu_mode = CPU_MODE_IRQ;  // Old IRQ
        5'b0??11: cpu_mode = CPU_MODE_SVC;  // Old Supervisor

        5'b10000: cpu_mode = CPU_MODE_USR;  // User
        5'b10001: cpu_mode = CPU_MODE_FIQ;  // FIQ
        5'b10010: cpu_mode = CPU_MODE_IRQ;  // IRQ
        5'b10011: cpu_mode = CPU_MODE_SVC;  // Supervisor
        5'b10111: cpu_mode = CPU_MODE_ABT;  // Abort
        5'b11011: cpu_mode = CPU_MODE_UND;  // Undefined
        5'b11111: cpu_mode = CPU_MODE_SYS;  // System

        default: begin
          cpu_mode = CPU_MODE_USR;
          $warning("Illegal CPSR mode encoding: %b", regs.CPSR[4:0]);
        end
      endcase
    end
  end

  GBA_Decoder_if decoder_bus (
      .IR(IR),
      .execution_mode(execution_mode),
      .flags(regs.CPSR[31:28])
  );

  GBA_ALU_if alu_bus (.op_a(A_bus));
  GBA_Shifter_if shifter_bus (.R_in(B_bus));
  GBA_Multiplier_if multiplier_bus (
      .A_bus(A_bus),
      .B_bus(B_bus)
  );

  assign shifter_bus.shift_latch_amt = control_signals.shift_latch_amt;
  assign shifter_bus.shift_use_latch = control_signals.shift_use_latch;
  assign shifter_bus.shift_amount = control_signals.shift_amount;
  assign shifter_bus.shift_type = control_signals.shift_type;
  assign shifter_bus.carry_in = regs.CPSR[29];  // CPSR.C
  assign shifter_bus.shift_use_rxx = control_signals.shift_use_rxx;

  assign alu_bus.alu_op = control_signals.ALU_op;
  assign alu_bus.use_op_b_latch = control_signals.ALU_use_op_b_latch;
  assign alu_bus.disable_op_b = control_signals.ALU_disable_op_b;
  assign alu_bus.latch_op_b = control_signals.ALU_latch_op_b;
  assign alu_bus.flags_in = regs.CPSR[31:28];  // N,Z,C,V

  assign bus.read_en = control_signals.memory_read_en;
  assign bus.write_en = control_signals.memory_write_en;

  always_comb begin
    if (control_signals.memory_latch_IR || control_signals.memory_latch_early_IR) begin
      unique case (execution_mode)
        MODE_ARM:   bus.transfer_size = ARM_BUS_SIZE_WORD;
        MODE_THUMB: bus.transfer_size = ARM_BUS_SIZE_HALFWORD;
      endcase
    end else begin
      if (control_signals.memory_byte_transfer) bus.transfer_size = ARM_BUS_SIZE_BYTE;
      else if (control_signals.memory_halfword_transfer) bus.transfer_size = ARM_BUS_SIZE_HALFWORD;
      else bus.transfer_size = ARM_BUS_SIZE_WORD;
    end
  end

  assign multiplier_bus.enable = control_signals.multiplier_enable;
  assign multiplier_bus.opcode = decoder_bus.instr_type == ARM_INSTR_MULTIPLY
    ? decoder_bus.word.arm.mul.opcode
    : gba_cpu_decoder_types_pkg::multiply_opcode_t'(4'd0);

  always_comb begin
    bus.wdata = B_bus;
    if (control_signals.memory_byte_transfer) begin
      bus.wdata = {24'd0, B_bus[7:0]};
    end else if (control_signals.memory_halfword_transfer) begin
      bus.wdata = {16'd0, B_bus[15:0]};
    end
  end

  /// TODO: Debug signal
  (* maybe_unused *)
  logic instr_boundary;

  // assign decoder_bus.IR = IR;

  ALU alu_inst (
      .clk(clk),
      .reset(reset),
      .bus(alu_bus),
      .shifter_bus(shifter_bus)
  );

  GBA_Decoder decoder_inst (
      .clk  (clk),
      .reset(reset),
      .bus  (decoder_bus)
  );

  GBA_Multiplier multiplier_inst (
      .clk  (clk),
      .reset(reset),
      .bus  (multiplier_bus)
  );

  GBA_ControlUnit controlUnit (
      .clk(clk),
      .reset(reset),
      .decoder_bus(decoder_bus),
      .execution_mode(execution_mode),
      .control_signals(control_signals),
      .flush_req(flush_req)
  );

  GBA_BarrelShifter shifter_inst (
      .clk  (clk),
      .reset(reset),
      .bus  (shifter_bus)
  );

  // ======================================================
  // Assign A Bus
  // ======================================================

  // This may get more complicated in the future
  always_comb begin
    unique case (control_signals.A_bus_source)
      A_BUS_SRC_RN: begin
        `LOG_TRACE(("Driving A bus with value from Rn (R%d): %0d", decoder_bus.decoded_regs.Rn,
                 read_reg(regs, cpu_mode, decoder_bus.decoded_regs.Rn)))
        if (control_signals.A_bus_align) begin
          `LOG_TRACE(("Aligning A bus address by masking off lower 2 bits: %0d", read_reg(
                   regs, cpu_mode, decoder_bus.decoded_regs.Rn) & ~32'd3))
          A_bus = (read_reg(regs, cpu_mode, decoder_bus.decoded_regs.Rn)) & ~32'd3;
        end else begin
          A_bus = read_reg(regs, cpu_mode, decoder_bus.decoded_regs.Rn);
        end
      end

      A_BUS_SRC_IMM: begin
        `LOG_TRACE(("Driving A bus with value from imm (%0d)", control_signals.A_bus_imm))
        A_bus = word_t'(control_signals.A_bus_imm);
      end

      A_BUS_SRC_RD: begin
        `LOG_TRACE(("Driving A bus with value from Rd (R%d): %0d", decoder_bus.decoded_regs.Rd,
                 read_reg(regs, cpu_mode, decoder_bus.decoded_regs.Rd)))
        A_bus = read_reg(regs, cpu_mode, decoder_bus.decoded_regs.Rd);
      end

      A_BUS_SRC_RS: begin
        /// TODO pc_rs_add_4 heres
        `LOG_TRACE(("Driving A bus with value from Rs (R%d): %0d", decoder_bus.decoded_regs.Rs,
                 read_reg(regs, cpu_mode, decoder_bus.decoded_regs.Rs)))
        A_bus = read_reg(regs, cpu_mode, decoder_bus.decoded_regs.Rs);
      end

    endcase
  end


  function automatic word_t ror32(word_t x, int unsigned sh);
    ror32 = (x >> sh) | (x << (32 - sh));
  endfunction

  // ======================================================
  // Assign B Bus
  // ======================================================
  always_comb begin
    B_bus = 32'd0;

    unique case (control_signals.B_bus_source)
      B_BUS_SRC_NONE: begin
        B_bus = 32'd0;
      end

      B_BUS_SRC_IMM: begin
        if (control_signals.B_bus_sign_extend) begin
          B_bus = {{8{control_signals.B_bus_imm[23]}}, control_signals.B_bus_imm};
          `LOG_TRACE(("Driving B bus with sign-extended immediate: %0d", B_bus))
        end else begin
          B_bus = {8'b0, control_signals.B_bus_imm};
          `LOG_TRACE(("Driving B bus with zero-extended immediate: %0d", B_bus))
        end
      end

      B_BUS_SRC_READ_DATA: begin
        B_bus = read_data;
        `LOG_TRACE(("Driving B bus with read_data value: %0d", read_data))
      end

      B_BUS_SRC_REG_RM: begin
        `LOG_TRACE(("Driving B bus with value from Rm (R%0d): %0d", decoder_bus.decoded_regs.Rm,
                 read_reg(regs, cpu_mode, decoder_bus.decoded_regs.Rm)))
        B_bus = read_reg(regs, cpu_mode, decoder_bus.decoded_regs.Rm);
      end

      B_BUS_SRC_REG_RS: begin
        B_bus = read_reg(regs, cpu_mode, decoder_bus.decoded_regs.Rs);
      end

      B_BUS_SRC_REG_RD: begin
        B_bus = read_reg(regs, cpu_mode, decoder_bus.decoded_regs.Rd);
      end

      B_BUS_SRC_REG_RN: begin
        `LOG_TRACE(("Driving B bus with value from Rn (R%0d): %0d", decoder_bus.decoded_regs.Rn,
                 read_reg(regs, cpu_mode, decoder_bus.decoded_regs.Rn)))
        B_bus = read_reg(regs, cpu_mode, decoder_bus.decoded_regs.Rn);
      end

      B_BUS_SRC_REG_RP: begin
        `LOG_TRACE(("Driving B bus with value from Rp (R%0d): %0d", control_signals.Rp_imm, read_reg(
                 regs, cpu_mode, control_signals.Rp_imm)))
        B_bus = read_reg(regs, control_signals.force_user_mode ? CPU_MODE_USR : cpu_mode,
                         control_signals.Rp_imm);
      end

      B_BUS_SRC_MULTIPLIER: begin
        B_bus = multiplier_bus.result;
      end

      B_BUS_SRC_CPSR: begin
        B_bus = regs.CPSR;
        `LOG_TRACE(("Driving B bus with value from CPSR: 0x%08x", B_bus))
      end

      B_BUS_SRC_SPSR: begin
        B_bus = read_spsr(regs, cpu_mode);
        `LOG_TRACE(("Driving B bus with value from SPSR: 0x%08x", B_bus))
      end
    endcase
  end

  always_ff @(posedge clk) begin
    `DISPLAY_CONTROL(control_signals)

    instr_boundary <= control_signals.pipeline_advance;
  end

  // ======================================================
  // Memory Module
  // ======================================================
  always_ff @(posedge clk) begin
    if (reset) begin
      IR <= 32'd0;
    end else begin
      `TRACE_CPU

      assert (!(control_signals.memory_write_en && control_signals.memory_read_en))
      else $fatal(1, "Both memory_read_en and memory_write_en asserted!");

      if (control_signals.memory_advance_early_fetched_IR) begin
        IR <= early_fetched_IR;
        `LOG_TRACE(("Advancing early fetched IR to main IR: 0x%08x", early_fetched_IR))
      end

      if (control_signals.memory_read_en) begin
        if (control_signals.memory_latch_IR) begin
          IR <= bus.rdata;
          `LOG_TRACE(("Latching IR with value: 0x%08x", bus.rdata))

        end else if (control_signals.memory_latch_early_IR) begin
          early_fetched_IR <= bus.rdata;
          `LOG_TRACE(("Latching early fetched IR with value: 0x%08x", bus.rdata))

        end else begin
          if (control_signals.memory_byte_transfer) begin
            read_data <= {24'd0, bus.rdata[7:0]};

            if (control_signals.memory_signed_transfer) begin
              read_data <= {{24{bus.rdata[7]}}, bus.rdata[7:0]};

              `LOG_TRACE(("Performing signed byte read, bus.rdata=0x%08x, B_bus[7:0]=0x%02x",
                       bus.rdata, bus.rdata[7:0]))
            end

            `LOG_TRACE(("Performing byte read, bus.rdata=0x%08x, B_bus[7:0]=0x%02x", bus.rdata,
                     bus.rdata[7:0]))
          end else if (control_signals.memory_halfword_transfer) begin

            word_t result;

            result = {16'b0, bus.rdata[15:0]};

            // ARM7TDMI unaligned halfword rotate quirk
            // https://mgba-emu.github.io/gbatek/#mis-aligned-ldrhldrsh-does-or-does-not-do-strange-things
            if (bus.addr[0] == 1'b1) begin
              result = ror32(bus.rdata, 8);
              `LOG_TRACE((
                  "Performing unaligned halfword read with rotate, bus.addr[0]=%b, bus.rdata=0x%08x, rotated result=0x%08x",
                  bus.addr[0], bus.rdata, result))

              if (control_signals.memory_signed_transfer) begin
                result = {{24{result[7]}}, result[7:0]};

                `LOG_TRACE((
                    "Performing signed byte read (due to unaligned halfword), bus.rdata=0x%08x, B_bus[7:0]=0x%02x, result=0x%08x",
                    bus.rdata, bus.rdata[7:0], result))
              end
            end else if (control_signals.memory_signed_transfer) begin
              result = {{16{result[15]}}, result[15:0]};

              `LOG_TRACE((
                  "Performing signed halfword read, sign=%b, bus.rdata=0x%08x, B_bus[15:0]=0x%04x, result=0x%08x",
                  bus.rdata[15], bus.rdata, bus.rdata[15:0], result))
            end else result = {16'd0, result[15:0]};

            `LOG_TRACE(("Performing halfword read, bus.rdata=0x%08x, B_bus[15:0]=0x%04x", bus.rdata,
                     bus.rdata[15:0]))

            read_data <= result;
          end else if (control_signals.memory_signed_transfer) begin
            read_data <= {{16{bus.rdata[15]}}, bus.rdata[15:0]};

            `LOG_TRACE(("Performing signed halfword read, bus.rdata=0x%08x, B_bus[15:0]=0x%04x",
                     bus.rdata, bus.rdata[15:0]))
          end else begin
            `LOG_TRACE(("Performing word read, bus.rdata=0x%08x", bus.rdata))
            read_data <= bus.rdata;

            // Misaligned word-load rotate quirk (ARM7TDMI)
            if (decoder_bus.instr_type == ARM_INSTR_LOAD || decoder_bus.instr_type == ARM_INSTR_SWAP) begin
              logic [1:0] a;
              a = bus.addr[1:0];
              if (a != 2'b00) begin
                `LOG_TRACE(("Misaligned word with a=%b, rotate=%d, prior=%d", a, ror32(
                         bus.rdata, 32'({a, 3'b000})), bus.rdata))
                read_data <= ror32(bus.rdata, 32'({a, 3'b000}));  // (a*8)
              end
            end
          end
        end
      end
    end
  end

  // ======================================================
  // Perform Register Writebacks
  // ======================================================
  always_ff @(posedge clk) begin
    if (reset) begin
      regs.user <= '{default: 32'd0};
    end else begin
      flush_req <= 1'b0;

      if (control_signals.pipeline_advance && flush_req_pending) begin
        `LOG_TRACE(("Pipeline gba, checking for writebacks and flushes"))

        flush_req_pending <= 1'b0;
        flush_req <= 1'b1;
      end

      if ((control_signals.ALU_writeback == ALU_WB_REG_RD && decoder_bus.decoded_regs.Rd == 4'd15) ||
          (control_signals.ALU_writeback == ALU_WB_REG_RN && decoder_bus.decoded_regs.Rn == 4'd15) ||
          (control_signals.ALU_writeback == ALU_WB_REG_RP && control_signals.Rp_imm == 4'd15)) begin

        `LOG_TRACE(("ALU writeback to PC (R15) detected. ALU_writeback=%0d, Rd=%0d, Rn=%0d",
                 control_signals.ALU_writeback, decoder_bus.decoded_regs.Rd,
                 decoder_bus.decoded_regs.Rn))

        if (control_signals.pipeline_advance) begin
          flush_req <= 1'b1;
          `LOG_TRACE(("Requesting pipeline flush due to writeback to PC (R15)"))
        end else begin
          flush_req_pending <= 1'b1;
          `LOG_TRACE(("Setting flush_req_pending to ensure flush on next cycle."))
        end
      end else if (control_signals.incrementer_writeback) begin
        unique case (execution_mode)
          MODE_ARM: begin
            // PC = PC + 4
            `WRITE_REG(regs, cpu_mode, 15, read_reg(regs, cpu_mode, 15) + 32'd4, execution_mode,
                       1'b0)
            `LOG_TRACE(("Incrementing PC to: %0d", read_reg(regs, cpu_mode, 15) + 32'd4))
          end
          MODE_THUMB: begin
            `WRITE_REG(regs, cpu_mode, 15, read_reg(regs, cpu_mode, 15) + 32'd2, execution_mode,
                       1'b0)
            `LOG_TRACE(("Incrementing PC to: %0d", read_reg(regs, cpu_mode, 15) + 32'd2))
          end
        endcase
      end

      `LOG_TRACE(("[CPU] Checking ALU flags writeback. ALU_set_flags=%b, restore_cpsr_from_spsr=%b",
               control_signals.ALU_set_flags, control_signals.restore_cpsr_from_spsr))

      if (control_signals.set_thumb_mode) begin
        regs.CPSR[5] <= B_bus[0];
        `WRITE_REG(regs, cpu_mode, 4'd15, B_bus & ~32'd1, execution_mode, 1'b0)
        flush_req <= 1'b1;
        `LOG_TRACE(("Setting Thumb mode bit in CPSR"))
      end

      if (execution_mode == MODE_ARM && mode_has_spsr(
              cpu_mode
          ) && control_signals.restore_cpsr_from_spsr) begin
        regs.CPSR <= read_spsr(regs, cpu_mode);
        `LOG_TRACE(("Restoring CPSR from SPSR_%0d: 0x%08x", cpu_mode, read_spsr(regs, cpu_mode)))
      end else if (control_signals.ALU_set_flags) begin

        `LOG_TRACE(("Setting flags: N=%b, Z=%b, C=%b, V=%b", alu_bus.flags_out.n, alu_bus.flags_out.z,
                 alu_bus.flags_out.c, alu_bus.flags_out.v))

        regs.CPSR[31] <= alu_bus.flags_out.n;
        regs.CPSR[30] <= alu_bus.flags_out.z;

        if (decoder_bus.instr_type != ARM_INSTR_MULTIPLY) begin
          regs.CPSR[29] <= alu_bus.flags_out.c;
          regs.CPSR[28] <= alu_bus.flags_out.v;
          `LOG_TRACE(("ALU op was %0d, setting C flag to %b and V flag to %b", control_signals.ALU_op,
                   alu_bus.flags_out.c, alu_bus.flags_out.v))
        end else begin
          // For multiply instructions, the C flag is set to destroyed (ARMV4 only -- on ARMV5 and later its ignored)
          regs.CPSR[29] <= 1'd0;
        end

        `LOG_TRACE(("ALU op was %0d, setting C flag to %b", control_signals.ALU_op,
                 alu_bus.flags_out.c))
      end else if (control_signals.mult_set_flags) begin
        regs.CPSR[31] <= multiplier_bus.flags.N;
        regs.CPSR[30] <= multiplier_bus.flags.Z;
        regs.CPSR[29] <= 1'd0;  // C flag is set to destroyed for multiply instructions (ARMv4)

        `LOG_TRACE(("Multiplier set flags, setting N=%b, Z=%b", multiplier_bus.flags.N,
                 multiplier_bus.flags.Z))
      end

      if (control_signals.exception != EXCEPTION_NONE) begin
        `WRITE_SPSR(regs, cpu_mode, regs.CPSR)

        regs.user.r15 <= VECTOR_TABLE[control_signals.exception];

        regs.CPSR[7] <= 1'b1;  // Disable IRQ

        regs.CPSR[4:0] <= update_cpsr_mode(control_signals.exception);

        flush_req <= 1'b1;

        `LOG_TRACE(("Performing CPU exception handling from %0d to %0d", cpu_mode,
                 control_signals.exception))
      end

      unique case (control_signals.ALU_writeback)
        ALU_WB_NONE: ;
        ALU_WB_REG_RD: begin
          `WRITE_REG(regs, cpu_mode, decoder_bus.decoded_regs.Rd, alu_bus.result, execution_mode,
                     !control_signals.force_no_align_pc)
          `LOG_TRACE(("Writing back ALU result %0d to Rd (R%d)", alu_bus.result,
                   decoder_bus.decoded_regs.Rd))
        end
        ALU_WB_REG_RS:
        `WRITE_REG(regs, cpu_mode, decoder_bus.decoded_regs.Rs, alu_bus.result, execution_mode,
                   !control_signals.force_no_align_pc)
        ALU_WB_REG_RN: begin
          `LOG_TRACE(("Writing back ALU result %0d to Rn (R%d)", alu_bus.result,
                   decoder_bus.decoded_regs.Rn))
          `WRITE_REG(regs, control_signals.force_user_mode ? CPU_MODE_USR : cpu_mode,
                     decoder_bus.decoded_regs.Rn, alu_bus.result, execution_mode,
                     !control_signals.force_no_align_pc)
        end
        ALU_WB_REG_RP: begin
          `WRITE_REG(regs, control_signals.force_user_mode ? CPU_MODE_USR : cpu_mode,
                     control_signals.Rp_imm, alu_bus.result, execution_mode,
                     !control_signals.force_no_align_pc)
        end
        ALU_WB_REG_CSPR: begin
          logic [3:0] mask;

          mask = control_signals.status_reg_write_mask;

          // In general the extension bits should never get written to
          // since on ARMv3 they are unused.
          mask[1] = 1'b0;  // x (extension)

          // Restrict writes in User mode
          if (cpu_mode == CPU_MODE_USR) begin
            mask[2] = 1'b0;  // s (status)
            mask[0] = 1'b0;  // c (control)
          end

          regs.CPSR <= apply_status_mask(alu_bus.result, regs.CPSR, mask);

          `LOG_TRACE(("Writing back ALU result %0d to CPSR (masked=%b)", alu_bus.result, mask))
        end
        ALU_WB_REG_SPSR: begin
          `WRITE_SPSR(
              regs, cpu_mode, apply_status_mask(
              alu_bus.result, read_spsr(regs, cpu_mode), control_signals.status_reg_write_mask))
          `LOG_TRACE(("Writing back ALU result %0d to SPSR_%0d", alu_bus.result, cpu_mode))
        end
      endcase
    end
  end

  // ======================================================
  // Address Module
  // ======================================================
  // Calculate address bus value
  always_ff @(posedge clk) begin
    if (reset) begin
    end else begin
      `LOG_TRACE(("[CPU] addr=%0d", bus.addr))

      if (control_signals.set_thumb_mode) begin
        bus.addr <= B_bus & ~32'd1;
        `LOG_TRACE((
            "Setting address bus to new Thumb mode PC value due to set_thumb_mode control signal, B_bus=0x%08x, addr=0x%08x",
            B_bus, bus.addr))
      end else begin
        unique case (control_signals.addr_bus_src)
          ADDR_SRC_NONE: begin
            // bus.addr <= 32'd0;
          end

          ADDR_SRC_ALU: begin
            `LOG_TRACE(("[CPU] Driving address bus with ALU result: %0d", alu_bus.result))
            bus.addr <= alu_bus.result;
          end

          ADDR_SRC_PC: begin
            `LOG_TRACE(("Setting address bus to PC value: 0x%08x", read_reg(regs, cpu_mode, 15)))
            unique case (execution_mode)
              MODE_ARM:   bus.addr <= read_reg(regs, cpu_mode, 15) & ~32'd3;
              MODE_THUMB: bus.addr <= read_reg(regs, cpu_mode, 15) & ~32'd1;
            endcase
          end

          ADDR_SRC_PC_RESTORE: begin
            `LOG_TRACE(("Restoring address bus from PC value: 0x%08x", read_reg(regs, cpu_mode, 15)))
            unique case (execution_mode)
              MODE_ARM:   bus.addr <= read_reg(regs, cpu_mode, 15) - 32'd4 & ~32'd3;
              MODE_THUMB: bus.addr <= read_reg(regs, cpu_mode, 15) - 32'd4 & ~32'd1;
            endcase
          end

          ADDR_SRC_INCR: begin
            unique case (execution_mode)
              MODE_ARM: begin
                bus.addr <= bus.addr + 32'd4;
              end
              MODE_THUMB: begin
                if (control_signals.addr_incr_force_p4) begin
                  bus.addr <= bus.addr + 32'd4;
                  `LOG_TRACE(("Incrementing address bus by 4 due to addr_incr_force_p4: new addr=%0d",
                           bus.addr))
                end else begin
                  bus.addr <= bus.addr + 32'd2;
                  `LOG_TRACE(("Incrementing address bus for Thumb mode: new addr=%0d",
                           bus.addr + 32'd2))
                end
              end
            endcase
          end
        endcase
      end
    end
  end

endmodule : ARM7TMDI
