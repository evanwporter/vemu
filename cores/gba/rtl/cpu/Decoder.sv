import gba_types_pkg::*;
import gba_cpu_types_pkg::*;
import gba_cpu_util_pkg::*;
import gba_cpu_decoder_types_pkg::*;

module GBA_Decoder (
    input logic clk,
    input logic reset,
    GBA_Decoder_if.Decoder_side bus
);

  word_t IR;

  always_ff @(posedge clk) begin
    if (reset) begin
      // Reset logic here
      IR <= 32'h0;
    end else begin
      if (bus.pipeline_advance) begin
        IR <= bus.IR;
        $display("[GBA_Decoder] Latched instruction 0x%08x into IR", bus.IR);
      end
    end
  end

  always_comb begin
    bus.condition_pass =
        eval_cond(condition_t'(IR[31:28]), bus.flags.n, bus.flags.z, bus.flags.c, bus.flags.v);

    bus.decoded_regs.Rn = IR[19:16];
    $display("[GBA_Decoder] Extracted Rn = R%0d from IR %b", bus.decoded_regs.Rn, IR[19:16]);
    bus.decoded_regs.Rd = IR[15:12];
    bus.decoded_regs.Rs = IR[11:8];
    bus.decoded_regs.Rm = IR[3:0];

    bus.word.arm = 24'b0;

    bus.instr_type = ARM_INSTR_UNDEFINED;

    $display("[GBA_Decoder] Decoding instruction 0x%08x", IR);

    priority casez (IR)
      /// Branch and Branch Exchange
      32'b????_0001_0010_1111_1111_1111_0001_????: begin
        bus.instr_type = ARM_INSTR_BRANCH_EX;
        bus.decoded_regs.Rn = IR[3:0];
        $display("[GBA_Decoder] Detected BX instruction with IR=0x%08x", IR);
      end

      /// Block Data Transfer
      32'b????_100?_????_????_????_????_????_????: begin
        bus.word.arm.block.P = pre_post_offset_flag_t'(IR[24]);
        bus.word.arm.block.U = IR[23];
        bus.word.arm.block.S = IR[22];
        bus.word.arm.block.W = IR[21];
        bus.word.arm.block.reg_list = IR[15:0];

        if (IR[20] == 1'b1) begin
          bus.instr_type = ARM_INSTR_LDM;
        end else begin
          bus.instr_type = ARM_INSTR_STM;
        end

        $display("[GBA_Decoder] Detected block data transfer instruction with IR=0x%08x", IR);
      end

      /// Branch
      32'b????_1010_????_????_????_????_????_????: begin
        bus.instr_type = ARM_INSTR_BRANCH;
        bus.word.arm.branch.imm24 = IR[23:0];

        // Overwrite Rn and Rd
        bus.decoded_regs.Rn = 4'd15;
        bus.decoded_regs.Rd = 4'd14;

        $display("[GBA_Decoder] Detected B instruction with IR=0x%08x", IR);
      end

      /// Branch with Link
      32'b????_1011_????_????_????_????_????_????: begin
        bus.instr_type = ARM_INSTR_BRANCH_LINK;
        bus.word.arm.branch.imm24 = IR[23:0];

        // Overwrite Rn and Rd
        bus.decoded_regs.Rn = 4'd15;
        bus.decoded_regs.Rd = 4'd14;

        $display("[GBA_Decoder] Detected BL instruction with IR=0x%08x", IR);
      end

      /// Software Interrupt
      32'b????_1111_????_????_????_????_????_????: begin
        // TODO: Decode comments from ARM SWI IR.

        bus.instr_type = ARM_INSTR_SWI;

        // Overwrite Rn and Rd
        bus.decoded_regs.Rn = 4'd15;
        bus.decoded_regs.Rd = 4'd14;

        $display("[GBA_Decoder] Detected SWI instruction with IR=0x%08x", IR);
      end

      /// Single Data Transfer
      32'b????_01??_????_????_????_????_????_????: begin
        bus.word.arm.ls.I  = mem_offset_flag_t'(IR[25]);
        bus.word.arm.ls.P  = pre_post_offset_flag_t'(IR[24]);
        bus.word.arm.ls.U  = IR[23];
        bus.word.arm.ls.B  = bit_length_flag_t'(IR[22]);
        bus.word.arm.ls.wt = IR[21];

        if (IR[20] == 1'b1) begin
          bus.instr_type = ARM_INSTR_LOAD;
        end else begin
          bus.instr_type = ARM_INSTR_STORE;
        end

        if (bus.word.arm.ls.I == ARM_LDR_STR_REGISTER) begin
          bus.word.arm.ls.offset.shifted.shift_amount = IR[11:7];
          bus.word.arm.ls.offset.shifted.shift_type   = shift_type_t'(IR[6:5]);
        end else begin
          bus.word.arm.ls.offset.imm12 = IR[11:0];
        end

        $display("[GBA_Decoder] Detected single data transfer instruction with IR=0x%08x", IR);
      end

      /// Single Data Swap
      32'b????_0001_0???_????_????_0000_1001_????: begin
        $display("[GBA_Decoder] Detected single data swap instruction with IR=0x%08x", IR);
      end

      /// Multiply
      32'b????_0000_????_????_????_????_1001_????: begin
        bus.instr_type = ARM_INSTR_MULTIPLY;
        bus.word.arm.mul.opcode = multiply_opcode_t'(IR[24:21]);

        bus.decoded_regs.Rd = IR[19:16];
        bus.decoded_regs.Rn = IR[15:12];

        bus.word.arm.mul.S = IR[20];

        $display("[GBA_Decoder] Detected multiply instruction with IR=0x%08x", IR);
      end

      // /// Multiply Long
      // 32'b????_0000_1???_????_????_????_1001_????: begin
      //   $display("[GBA_Decoder] Detected multiply long instruction with IR=0x%08x", IR);
      // end

      // Halfword Data Transfer
      32'b????_000?_????_????_????_????_1??1_????: begin
        if (IR[20]) bus.instr_type = ARM_INSTR_LDR_HALF;
        else bus.instr_type = ARM_INSTR_STR_HALF;

        bus.word.arm.ls_half.P = pre_post_offset_flag_t'(IR[24]);

        bus.word.arm.ls_half.U = IR[23];

        bus.word.arm.ls_half.I = IR[22];

        bus.word.arm.ls_half.W = IR[21];

        bus.word.arm.ls_half.imm_offset = {IR[11:8], IR[3:0]};

        bus.word.arm.ls_half.opcode = signed_halfword_flag_t'(IR[6:5]);

        $display(
            "[GBA_Decoder] Detected halfword data transfer register instruction with IR=0x%08x",
            IR);
      end

      /// PSR Transfer MSR
      32'b????_0001_0?00_1111_????_????_????_????: begin
        $display("[GBA_Decoder] Detected MSR instruction with IR=0x%08x", IR);
      end

      /// PSR Transfer MRS
      32'b????_00?1_0?10_????_1111_????_????_????: begin
        $display("[GBA_Decoder] Detected MRS instruction with IR=0x%08x", IR);
      end

      /// Data Processing
      32'b????_00??_????_????_????_????_????_????: begin

        $display("[GBA_Decoder] Detected data processing instruction with IR=0x%08x", IR);
        $fflush();

        // Notable bits
        // 2nd Operand
        // 25 (I): indicates whether its an immediate value or a register value
        //  (1) = immediate, (0) = register
        // 4 (R): Shift by register or immediate
        //   (0) = immediate, (1) = register

        // Forms:
        // I=0 R=0: Register with immediate shift
        // I=0 R=1: Register with register shift
        // I=1: Immediate value with rotate

        if (IR[25] == 1'b1) begin
          // Immediate value with rotate
          bus.word.arm.data_proc_imm.imm8 = IR[7:0];
          bus.word.arm.data_proc_imm.rotate = IR[11:8];
          bus.word.arm.data_proc_imm.set_flags = IR[20];

          bus.word.arm.data_proc_imm.opcode = IR[24:21];
          bus.instr_type = ARM_INSTR_DATAPROC_IMM;

          $display(
              "Decoded data processing immediate instruction with opcode=%0d, set_flags=%0b, imm8=0x%02x, rotate=0x%01x",
              bus.word.arm.data_proc_imm.opcode, bus.word.arm.data_proc_imm.set_flags,
              bus.word.arm.data_proc_imm.imm8, bus.word.arm.data_proc_imm.rotate);
        end else if (IR[4] == 1'b0) begin  // IR[25] == 1'b0 is implied
          // Register with immediate shift
          bus.word.arm.data_proc_reg_imm.shift_amount = IR[11:7];
          bus.word.arm.data_proc_reg_imm.shift_type = shift_type_t'(IR[6:5]);
          bus.word.arm.data_proc_reg_imm.set_flags = IR[20];
          bus.word.arm.data_proc_reg_imm.opcode = IR[24:21];
          bus.instr_type = ARM_INSTR_DATAPROC_REG_IMM;
        end else begin
          // Register with register shift
          bus.word.arm.data_proc_reg_reg.shift_type = shift_type_t'(IR[6:5]);
          bus.word.arm.data_proc_reg_reg.opcode = IR[24:21];
          bus.word.arm.data_proc_reg_reg.set_flags = IR[20];
          bus.instr_type = ARM_INSTR_DATAPROC_REG_REG;
        end
      end

      default: begin
        // TODO error
        $display("[GBA_Decoder] Unrecognized instruction with IR=0x%08x", IR);
      end
    endcase
  end
  // end

endmodule : GBA_Decoder
