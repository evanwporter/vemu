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

  /// TODO: I don't think its neccesary to latch.
  /// It would be if the mode changed before the pipeline advances.
  execution_mode_t execution_mode;

  wire [15:0] IR_THUMB = IR[15:0];

  always_ff @(posedge clk) begin
    if (reset) begin
      // Reset logic here
      IR <= 32'h0;
      execution_mode <= MODE_ARM;
    end else begin
      if (bus.pipeline_advance) begin
        IR <= bus.IR;
        execution_mode <= bus.execution_mode;
        $display("[GBA_Decoder] Latched instruction 0x%08x into IR", bus.IR);
      end
    end
  end

  always_comb begin
    bus.instr_type = ARM_INSTR_UNDEFINED;
    bus.condition_pass = 1'b1;
    bus.decoded_regs = '0;
    bus.word = 24'b0;

    unique case (execution_mode)
      MODE_ARM: begin
        bus.condition_pass =
            eval_cond(condition_t'(IR[31:28]), bus.flags.n, bus.flags.z, bus.flags.c, bus.flags.v);

        bus.decoded_regs.Rn = IR[19:16];
        $display("[GBA_Decoder] Extracted Rn = R%0d from IR %b", bus.decoded_regs.Rn, IR[19:16]);
        bus.decoded_regs.Rd = IR[15:12];
        bus.decoded_regs.Rs = IR[11:8];
        bus.decoded_regs.Rm = IR[3:0];

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

              bus.word.arm.data_proc_imm.opcode = alu_op_t'(IR[24:21]);
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
              bus.word.arm.data_proc_reg_imm.opcode = alu_op_t'(IR[24:21]);
              bus.instr_type = ARM_INSTR_DATAPROC_REG_IMM;
            end else begin
              // Register with register shift
              bus.word.arm.data_proc_reg_reg.shift_type = shift_type_t'(IR[6:5]);
              bus.word.arm.data_proc_reg_reg.opcode = alu_op_t'(IR[24:21]);
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

      MODE_THUMB: begin
        $display("[GBA_Decoder] Decoding THUMB instruction 0x%04x", IR_THUMB);

        bus.decoded_regs.Rn = 4'(IR_THUMB[8:6]);
        $display("[GBA_Decoder] Extracted Rn = R%0d from IR %b", bus.decoded_regs.Rn,
                 IR_THUMB[15:12]);
        bus.decoded_regs.Rd = 4'(IR_THUMB[2:0]);
        bus.decoded_regs.Rs = 4'(IR_THUMB[5:3]);

        priority casez (IR_THUMB)

          // Software Interrupt
          16'b1101_1111_????_????: begin
            $display("[Decoder] Detected THUMB SWI instruction with IR=0x%08x", IR_THUMB);
          end

          // Unconditional Branch
          16'b1110_0???_????_????: begin
            $display("[Decoder] Detected THUMB B instruction with IR=0x%08x", IR_THUMB);
          end

          // Conditional Branch
          16'b1101_????_????_????: begin
            $display("[Decoder] Detected THUMB B<cond> instruction with IR=0x%08x", IR_THUMB);
          end

          // Multiple Load / Store
          16'b1100_????_????_????: begin
            $display("[Decoder] Detected THUMB LDM/STM instruction with IR=0x%08x", IR_THUMB);
          end

          // Long Branch with Link
          16'b1111_????_????_????: begin
            $display("[Decoder] Detected THUMB BL instruction with IR=0x%08x", IR_THUMB);
          end

          // Add Offset to Stack Pointer
          16'b1011_0000_????_????: begin
            $display("[Decoder] Detected THUMB ADD SP instruction with IR=0x%08x", IR_THUMB);
          end

          // Push / Pop Registers
          16'b1011_?10?_????_????: begin
            $display("[Decoder] Detected THUMB PUSH/POP instruction with IR=0x%08x", IR_THUMB);
          end

          // Load / Store Halfword
          16'b1000_????_????_????: begin
            $display("[Decoder] Detected THUMB LDRH/STRH instruction with IR=0x%08x", IR_THUMB);
          end

          // SP Relative Load / Store
          16'b1001_????_????_????: begin
            $display("[Decoder] Detected THUMB LDR/STR SP instruction with IR=0x%08x", IR_THUMB);
          end

          // Load Address
          16'b1010_????_????_????: begin
            $display("[Decoder] Detected THUMB ADD Rd, PC, #imm instruction with IR=0x%08x",
                     IR_THUMB);
          end

          // Load / Store with Immediate Offset
          16'b011?_????_????_????: begin
            $display(
                "[Decoder] Detected THUMB LDR/STR with immediate offset instruction with IR=0x%08x",
                IR_THUMB);
          end

          // Load / Store with Register Offset
          16'b0101_??0?_????_????: begin
            $display(
                "[Decoder] Detected THUMB LDR/STR with register offset instruction with IR=0x%08x",
                IR_THUMB);
          end

          // Load / Store Sign-Extended Byte / Halfword
          16'b0101_??1?_????_????: begin
            $display("[Decoder] Detected THUMB LDRSB/LDRSH instruction with IR=0x%08x", IR_THUMB);
          end

          // PC Relative Load
          16'b0100_1???_????_????: begin
            $display("[Decoder] Detected THUMB PC-relative load instruction with IR=0x%08x",
                     IR_THUMB);
          end

          // Hi Register Operations / Branch Exchange
          16'b0100_01??_????_????: begin
            $display(
                "[Decoder] Detected THUMB Hi register operation or branch exchange instruction with IR=0x%08x",
                IR_THUMB);
          end

          // ALU Operations
          16'b0100_00??_????_????: begin
            $display("[Decoder] Detected THUMB ALU operation instruction with IR=0x%08x", IR_THUMB);
          end

          // Move / Compare / Add / Subtract Immediate
          16'b001?_????_????_????: begin
            $display(
                "[Decoder] Detected THUMB move/compare/add/subtract immediate instruction with IR=0x%08x",
                IR_THUMB);

            // Performs
            // Rd = Rd op imm8

            // Need to be manually overwritten to match up with ALU unit
            bus.decoded_regs.Rn = 4'(IR_THUMB[10:8]);
            bus.decoded_regs.Rd = 4'(IR_THUMB[10:8]);

            bus.word.arm.data_proc_imm.rotate = 0;
            bus.word.arm.data_proc_imm.set_flags = 1'b1;
            bus.word.arm.data_proc_imm.imm8 = IR_THUMB[7:0];

            unique case (IR_THUMB[12:11])
              2'b00: begin
                $display("[Decoder] Detected THUMB MOV immediate instruction with IR=0x%08x",
                         IR_THUMB);
                bus.word.arm.data_proc_imm.opcode = ALU_OP_MOV;
                bus.instr_type = ARM_INSTR_DATAPROC_IMM;
              end
              2'b01: begin
                $display(
                    "[Decoder] Detected THUMB CMP instruction with register operand with IR=0x%08x",
                    IR_THUMB);
                bus.word.arm.data_proc_imm.opcode = ALU_OP_CMP;
                bus.instr_type = ARM_INSTR_DATAPROC_IMM;
              end
              2'b10: begin
                $display("[Decoder] Detected THUMB add immediate instruction with IR=0x%08x",
                         IR_THUMB);
                bus.word.arm.data_proc_imm.opcode = ALU_OP_ADD;
                bus.instr_type = ARM_INSTR_DATAPROC_IMM;
              end
              2'b11: begin
                $display("[Decoder] Detected THUMB subtract immediate instruction with IR=0x%08x",
                         IR_THUMB);
                bus.word.arm.data_proc_imm.opcode = ALU_OP_SUB;
                bus.instr_type = ARM_INSTR_DATAPROC_IMM;
              end
            endcase
          end

          // Add / Subtract
          16'b0001_1???_????_????: begin
            // Need to be manually overwritten to match up with ALU unit
            bus.decoded_regs.Rn = 4'(IR_THUMB[5:3]);
            bus.decoded_regs.Rm = 4'(IR_THUMB[8:6]);

            // TODO Bit 10: (0) = register operand, (1) = immediate operand
            //      Bit 9: (0) = add, (1) = subtract
            //      We can use this to simplify the logic
            unique case (IR_THUMB[10:9])
              2'b00: begin
                $display(
                    "[Decoder] Detected THUMB add instruction with register operand with IR=0x%08x",
                    IR_THUMB);
                bus.word.arm.data_proc_reg_imm.opcode = ALU_OP_ADD;
                bus.instr_type = ARM_INSTR_DATAPROC_REG_IMM;

                bus.word.arm.data_proc_reg_imm.shift_type = SHIFT_LSL;
                bus.word.arm.data_proc_reg_imm.shift_amount = 0;

                bus.word.arm.data_proc_reg_imm.set_flags = 1'b1;
              end
              2'b01: begin
                $display(
                    "[Decoder] Detected THUMB subtract instruction with register operand with IR=0x%08x",
                    IR_THUMB);
                bus.word.arm.data_proc_reg_imm.opcode = ALU_OP_SUB;
                bus.instr_type = ARM_INSTR_DATAPROC_REG_IMM;

                bus.word.arm.data_proc_reg_imm.shift_type = SHIFT_LSL;
                bus.word.arm.data_proc_reg_imm.shift_amount = 0;

                bus.word.arm.data_proc_reg_imm.set_flags = 1'b1;
              end
              2'b10: begin
                $display(
                    "[Decoder] Detected THUMB add instruction with immediate operand with IR=0x%08x",
                    IR_THUMB);
                bus.word.arm.data_proc_imm.opcode = ALU_OP_ADD;
                bus.instr_type = ARM_INSTR_DATAPROC_IMM;
                bus.word.arm.data_proc_imm.rotate = 0;

                bus.word.arm.data_proc_imm.set_flags = 1'b1;
                bus.word.arm.data_proc_imm.imm8 = 8'(IR_THUMB[8:6]);
              end
              2'b11: begin
                $display(
                    "[Decoder] Detected THUMB subtract instruction with immediate operand with IR=0x%08x",
                    IR_THUMB);
                bus.word.arm.data_proc_imm.opcode = ALU_OP_SUB;
                bus.instr_type = ARM_INSTR_DATAPROC_IMM;
                bus.word.arm.data_proc_imm.rotate = 0;

                bus.word.arm.data_proc_imm.set_flags = 1'b1;
                bus.word.arm.data_proc_imm.imm8 = 8'(IR_THUMB[8:6]);
              end
            endcase
          end

          // Move Shifted Register
          16'b000?_????_????_????: begin
            $display("[Decoder] Detected THUMB move shifted register instruction with IR=0x%08x",
                     IR_THUMB);
            bus.instr_type = ARM_INSTR_DATAPROC_REG_IMM;

            bus.word.arm.data_proc_reg_imm.opcode = ALU_OP_MOV;
            bus.word.arm.data_proc_reg_imm.set_flags = 1'b1;

            bus.word.arm.data_proc_reg_imm.shift_type = shift_type_t'(IR_THUMB[12:11]);
            bus.word.arm.data_proc_reg_imm.shift_amount = IR_THUMB[10:6];

            bus.decoded_regs.Rn = 4'd0;
          end

          default: begin
            // TODO error
            $display("[GBA_Decoder] Unrecognized instruction with IR=0x%08x", IR_THUMB);
          end
        endcase
      end
    endcase
  end

endmodule : GBA_Decoder
