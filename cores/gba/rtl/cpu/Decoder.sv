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

  logic check_cond;

  always_ff @(posedge clk) begin
    if (reset) begin
      // Reset logic here
      IR <= 32'h0;
      execution_mode <= MODE_ARM;
      check_cond <= 1'b0;
    end else begin
      check_cond <= 1'b0;

      if (bus.pipeline_advance) begin
        IR <= bus.IR;
        check_cond <= 1'b1;
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
        if (check_cond) begin
          bus.condition_pass = eval_cond(condition_t'(IR[31:28]), bus.flags.n, bus.flags.z,
                                         bus.flags.c, bus.flags.v);
        end

        bus.decoded_regs.Rn = IR[19:16];
        $display("[GBA_Decoder] Extracted Rn = R%0d from IR %b", bus.decoded_regs.Rn, IR[19:16]);
        bus.decoded_regs.Rd = IR[15:12];
        bus.decoded_regs.Rs = IR[11:8];
        bus.decoded_regs.Rm = IR[3:0];

        $display("[GBA_Decoder] Decoding instruction 0x%08x", IR);

        priority casez (IR)
          // Branch and Branch Exchange
          32'b????_0001_0010_1111_1111_1111_0001_????: begin
            bus.instr_type = ARM_INSTR_BRANCH_EX;
            bus.decoded_regs.Rn = IR[3:0];
            $display("[GBA_Decoder] Detected BX instruction with IR=0x%08x", IR);
          end

          // Block Data Transfer
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

          // Branch
          32'b????_1010_????_????_????_????_????_????: begin
            bus.instr_type = ARM_INSTR_BRANCH;
            bus.word.arm.branch.imm24 = IR[23:0];

            // Overwrite Rn and Rd
            bus.decoded_regs.Rn = 4'd15;
            bus.decoded_regs.Rd = 4'd14;
            bus.decoded_regs.Rs = 4'd2;

            $display("[GBA_Decoder] Detected B instruction with IR=0x%08x", IR);
          end

          // Branch with Link
          32'b????_1011_????_????_????_????_????_????: begin
            bus.instr_type = ARM_INSTR_BRANCH_LINK;
            bus.word.arm.branch.imm24 = IR[23:0];

            // Overwrite Rn and Rd
            bus.decoded_regs.Rn = 4'd15;
            bus.decoded_regs.Rd = 4'd14;

            $display("[GBA_Decoder] Detected BL instruction with IR=0x%08x", IR);
          end

          // Software Interrupt
          32'b????_1111_????_????_????_????_????_????: begin
            // TODO: Decode comments from ARM SWI IR.

            bus.instr_type = ARM_INSTR_SWI;

            // Overwrite Rn and Rd
            bus.decoded_regs.Rn = 4'd15;
            bus.decoded_regs.Rd = 4'd14;

            $display("[GBA_Decoder] Detected SWI instruction with IR=0x%08x", IR);
          end

          // Single Data Transfer
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

          // Single Data Swap
          32'b????_0001_0???_????_????_0000_1001_????: begin
            bus.instr_type = ARM_INSTR_SWAP;
            bus.word.arm.swap.B = bit_length_flag_t'(IR[22]);
            $display("[GBA_Decoder] Detected single data swap instruction with IR=0x%08x", IR);
          end

          // Multiply
          32'b????_0000_????_????_????_????_1001_????: begin
            bus.instr_type = ARM_INSTR_MULTIPLY;
            bus.word.arm.mul.opcode = multiply_opcode_t'(IR[24:21]);

            bus.decoded_regs.Rd = IR[19:16];
            bus.decoded_regs.Rn = IR[15:12];

            bus.word.arm.mul.S = IR[20];

            $display("[GBA_Decoder] Detected multiply instruction with IR=0x%08x", IR);
          end

          // // Multiply Long
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

          // PSR Transfer MRS
          32'b????_0001_0?00_1111_????_????_????_????: begin
            bus.instr_type = ARM_INSTR_MRS;
            bus.word.arm.mrs.psr = psr_transfer_t'(IR[22]);
            $display("[ControlUnit] Detected MRS instruction with IR=0x%08x, accessing %s", IR,
                     psr_transfer_t'(IR[22]) == ARM_PSR_CPSR ? "CPSR" : "SPSR");
            $display("[GBA_Decoder] Detected MRS instruction with IR=0x%08x", IR);
          end

          // PSR Transfer MSR
          32'b????_00?1_0?10_????_1111_????_????_????: begin
            bus.instr_type = ARM_INSTR_MSR;

            bus.word.arm.msr.I = IR[25];

            bus.word.arm.msr.f = IR[19];
            bus.word.arm.msr.s = IR[18];
            bus.word.arm.msr.x = IR[17];
            bus.word.arm.msr.c = IR[16];

            bus.word.arm.msr.rotate = IR[11:8];
            bus.word.arm.msr.imm8 = IR[7:0];

            bus.word.arm.msr.psr = psr_transfer_t'(IR[22]);
            $display("[GBA_Decoder] Detected MSR instruction with IR=0x%08x", IR);
          end

          // Data Processing
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
            bus.instr_type = ARM_INSTR_SWI;

            // Overwrite Rn and Rd
            bus.decoded_regs.Rn = 4'd15;
            bus.decoded_regs.Rd = 4'd14;

            $display("[GBA_Decoder] Detected THUMB SWI instruction with IR=0x%08x", IR_THUMB);
          end

          // Unconditional Branch
          16'b1110_0???_????_????: begin
            bus.instr_type = ARM_INSTR_BRANCH;

            bus.decoded_regs.Rn = 4'd15;
            bus.decoded_regs.Rd = 4'd14;
            bus.decoded_regs.Rs = 4'd1;

            bus.word.arm.branch.imm24 = {{13{IR_THUMB[10]}}, IR_THUMB[10:0]};

            $display("[GBA_Decoder] Detected THUMB B instruction with IR=0x%08x", IR_THUMB);
          end

          // Conditional Branch
          16'b1101_????_????_????: begin
            bus.condition_pass = eval_cond(condition_t'(IR_THUMB[11:8]), bus.flags.n, bus.flags.z,
                                           bus.flags.c, bus.flags.v);

            bus.instr_type = ARM_INSTR_BRANCH;

            bus.decoded_regs.Rn = 4'd15;
            bus.decoded_regs.Rd = 4'd14;
            bus.decoded_regs.Rs = 4'd1;

            bus.word.arm.branch.imm24 = {{16{IR_THUMB[7]}}, IR_THUMB[7:0]};

            $display("[GBA_Decoder] Detected THUMB B<cond> instruction with IR=0x%08x", IR_THUMB);
          end

          // Block Data Transfer
          16'b1100_????_????_????: begin
            // Increment After
            bus.word.arm.block.P = ARM_LDR_STR_POST_OFFSET;
            bus.word.arm.block.U = 1'b1;
            bus.word.arm.block.W = 1'b1;

            bus.word.arm.block.S = 1'b0;

            bus.word.arm.block.reg_list = {8'd0, IR_THUMB[7:0]};

            if (IR_THUMB[7:0] == 8'd0) bus.word.arm.block.force_no_align_pc = 1'b1;

            if (IR_THUMB[11] == 1'b1) begin
              bus.instr_type = ARM_INSTR_LDM;
            end else begin
              bus.instr_type = ARM_INSTR_STM;
            end

            bus.decoded_regs.Rn = 4'(IR_THUMB[10:8]);

            $display("[GBA_Decoder] Detected THUMB LDM/STM instruction with IR=0x%08x", IR_THUMB);
          end

          // Long Branch with Link
          16'b1111_????_????_????: begin
            if (IR_THUMB[11] == 1'b0) begin
              // bus.instr_type = ARM_INSTR_BRANCH_LINK;

              bus.instr_type = ARM_INSTR_THUMB_LONG_BRANCH_LINK_0;

              // Overwrite Rn and Rd
              bus.decoded_regs.Rn = 4'd15;
              bus.decoded_regs.Rd = 4'd14;

              bus.word.arm.branch.imm24 = {{13{IR_THUMB[10]}}, IR_THUMB[10:0]};
              $display("[GBA_Decoder] Detected THUMB BL instruction with IR=0x%08x", IR_THUMB);
            end else begin
              bus.instr_type = ARM_INSTR_THUMB_LONG_BRANCH_LINK_1;

              // Overwrite Rn and Rd
              bus.decoded_regs.Rn = 4'd15;
              bus.decoded_regs.Rd = 4'd14;

              bus.word.arm.branch.imm24 = 24'(IR_THUMB[10:0]);
              $display("[GBA_Decoder] Detected THUMB BL instruction (2nd half) with Imm=0x%06x",
                       24'(IR_THUMB[10:0]));
            end
          end

          // Add Offset to Stack Pointer
          16'b1011_0000_????_????: begin
            bus.instr_type = ARM_INSTR_DATAPROC_IMM;
            // Immediate value with rotate
            bus.word.arm.data_proc_imm.imm8 = 8'(IR_THUMB[6:0]);
            bus.word.arm.data_proc_imm.rotate = 4'd1; // multiplied by 2, so we actually are rotating by 2 (step 4)
            bus.word.arm.data_proc_imm.set_flags = 1'd0;

            bus.word.arm.data_proc_imm.use_lsl = 1'b1;

            bus.word.arm.data_proc_imm.opcode = IR_THUMB[7] ? ALU_OP_SUB : ALU_OP_ADD;

            bus.decoded_regs.Rd = 4'd13;
            bus.decoded_regs.Rn = 4'd13;

            $display("[GBA_Decoder] Detected THUMB ADD SP instruction with IR=0x%08x", IR_THUMB);
          end

          // Push / Pop Registers
          16'b1011_?10?_????_????: begin

            bus.word.arm.block.W = 1'b1;
            bus.word.arm.block.S = 1'b0;

            bus.decoded_regs.Rn = 4'd13;

            bus.word.arm.block.reg_list = {8'd0, IR_THUMB[7:0]};

            if (IR_THUMB[7:0] == 8'd0) bus.word.arm.block.force_no_align_pc = 1'b1;

            if (IR_THUMB[11]) begin
              // POP = LDMIA SP!
              bus.instr_type = ARM_INSTR_LDM;
              bus.word.arm.block.P = ARM_LDR_STR_POST_OFFSET;
              bus.word.arm.block.U = 1'b1;

              // Add PC if requested
              if (IR_THUMB[8]) begin
                bus.word.arm.block.reg_list[15] = 1'b1;  // PC = R15
              end

              $display("[GBA_Decoder] Detected THUMB POP instruction (reg_list=0x%02x, PC=%0d)",
                       IR_THUMB[7:0], IR_THUMB[8]);

            end else begin
              // PUSH = STMDB SP!
              bus.instr_type = ARM_INSTR_STM;
              bus.word.arm.block.P = ARM_LDR_STR_PRE_OFFSET;
              bus.word.arm.block.U = 1'b0;

              // Add LR if requested
              if (IR_THUMB[8]) begin
                bus.word.arm.block.reg_list[14] = 1'b1;  // LR = R14
              end

              $display("[GBA_Decoder] Detected THUMB PUSH instruction (reg_list=0x%02x, LR=%0d)",
                       IR_THUMB[7:0], IR_THUMB[8]);
            end
            $display("[GBA_Decoder] Detected THUMB PUSH/POP instruction with IR=0x%08x", IR_THUMB);
          end

          // Load / Store Halfword
          16'b1000_????_????_????: begin
            if (IR_THUMB[11]) bus.instr_type = ARM_INSTR_LDR_HALF;
            else bus.instr_type = ARM_INSTR_STR_HALF;

            bus.word.arm.ls_half.P = ARM_LDR_STR_PRE_OFFSET;

            bus.word.arm.ls_half.U = 1'b1;  // Add

            bus.word.arm.ls_half.I = 1'b1;

            bus.word.arm.ls_half.W = 1'b0;  // No writeback

            bus.word.arm.ls_half.imm_offset = 8'(IR_THUMB[10:6] << 1);

            bus.word.arm.ls_half.opcode = ARM_LOAD_STORE_HALFWORD;

            bus.decoded_regs.Rn = 4'(IR_THUMB[5:3]);
            bus.decoded_regs.Rd = 4'(IR_THUMB[2:0]);

            $display("[GBA_Decoder] Detected THUMB LDRH/STRH instruction with IR=0x%08x", IR_THUMB);
          end

          // SP Relative Load / Store
          16'b1001_????_????_????: begin

            bus.word.arm.ls.I = ARM_LDR_STR_IMMEDIATE;
            bus.word.arm.ls.P = ARM_LDR_STR_PRE_OFFSET;
            bus.word.arm.ls.U = 1'b1;  // ADD
            bus.word.arm.ls.B = ARM_LDR_STR_WORD;
            bus.word.arm.ls.wt = 1'b0;  // No writeback

            bus.instr_type = IR_THUMB[11] ? ARM_INSTR_LOAD : ARM_INSTR_STORE;

            bus.word.arm.ls.offset.imm12 = 12'(IR_THUMB[7:0] << 2);

            bus.decoded_regs.Rn = 4'd13;  // SP
            bus.decoded_regs.Rd = 4'(IR_THUMB[10:8]);

            $display("[GBA_Decoder] Detected THUMB LDR/STR SP instruction with IR=0x%08x",
                     IR_THUMB);
          end

          // Load Address
          16'b1010_????_????_????: begin
            bus.instr_type = ARM_INSTR_DATAPROC_IMM;
            bus.word.arm.data_proc_imm.opcode = ALU_OP_ADD;
            bus.word.arm.data_proc_imm.set_flags = 1'b0;

            bus.decoded_regs.Rd = 4'(IR_THUMB[10:8]);

            if (IR_THUMB[11]) begin
              bus.decoded_regs.Rn = 4'd13;  // SP
            end else begin
              bus.word.arm.data_proc_imm.align_flag = 1'b1;  // PC-relative loads are word-aligned
              bus.decoded_regs.Rn = 4'd15;  // PC
            end

            bus.word.arm.data_proc_imm.imm8 = IR_THUMB[7:0];
            bus.word.arm.data_proc_imm.rotate = 4'd1;
            bus.word.arm.data_proc_imm.use_lsl = 1'b1;

            $display("[GBA_Decoder] Detected THUMB ADD Rd, PC, #imm instruction with IR=0x%08x",
                     IR_THUMB);
          end

          // Load / Store with Immediate Offset
          16'b011?_????_????_????: begin
            bus.instr_type = IR_THUMB[11] ? ARM_INSTR_LOAD : ARM_INSTR_STORE;
            bus.word.arm.ls.B = IR_THUMB[12] ? ARM_LDR_STR_BYTE : ARM_LDR_STR_WORD;
            bus.word.arm.ls.I = ARM_LDR_STR_IMMEDIATE;
            bus.word.arm.ls.P = ARM_LDR_STR_PRE_OFFSET;
            bus.word.arm.ls.U = 1'b1;  // ADD
            bus.word.arm.ls.wt = 1'b0;  // No writeback

            if (IR_THUMB[12]) bus.word.arm.ls.offset.imm12 = 12'(IR_THUMB[10:6]);
            else bus.word.arm.ls.offset.imm12 = 12'(IR_THUMB[10:6] << 2);

            bus.decoded_regs.Rn = 4'(IR_THUMB[5:3]);
            bus.decoded_regs.Rd = 4'(IR_THUMB[2:0]);

            $display(
                "[GBA_Decoder] Detected THUMB LDR/STR with immediate offset instruction with IR=0x%08x",
                IR_THUMB);
          end

          // Load / Store with Register Offset
          16'b0101_??0?_????_????: begin
            bus.instr_type = IR_THUMB[11] ? ARM_INSTR_LOAD : ARM_INSTR_STORE;
            bus.word.arm.ls.B = IR_THUMB[10] ? ARM_LDR_STR_BYTE : ARM_LDR_STR_WORD;
            bus.word.arm.ls.I = ARM_LDR_STR_REGISTER;
            bus.word.arm.ls.P = ARM_LDR_STR_PRE_OFFSET;
            bus.word.arm.ls.U = 1'b1;  // ADD
            bus.word.arm.ls.wt = 1'b0;  // No writeback

            bus.decoded_regs.Rn = 4'(IR_THUMB[5:3]);
            bus.decoded_regs.Rd = 4'(IR_THUMB[2:0]);
            bus.decoded_regs.Rm = 4'(IR_THUMB[10:6]);

            $display(
                "[GBA_Decoder] Detected THUMB LDR/STR with register offset instruction with IR=0x%08x",
                IR_THUMB);
          end

          // Load / Store Sign-Extended Byte / Halfword
          16'b0101_??1?_????_????: begin

            bus.word.arm.ls_half.P = ARM_LDR_STR_PRE_OFFSET;

            bus.word.arm.ls_half.U = 1'b1;  // Add

            bus.word.arm.ls_half.I = 1'b0;  // Use Register Offset

            bus.word.arm.ls_half.W = 1'b0;  // No writeback

            bus.word.arm.ls_half.imm_offset = 8'(IR_THUMB[10:6] << 1);

            if (IR_THUMB[11:10] == 2'd0) begin
              bus.instr_type = ARM_INSTR_STR_HALF;
              bus.word.arm.ls_half.opcode = ARM_LOAD_STORE_HALFWORD;
            end else if (IR_THUMB[11:10] == 2'd1) begin
              bus.instr_type = ARM_INSTR_LDR_HALF;
              bus.word.arm.ls_half.opcode = ARM_LOAD_SIGNED_BYTE;
            end else if (IR_THUMB[11:10] == 2'd2) begin
              bus.instr_type = ARM_INSTR_LDR_HALF;
              bus.instr_type = ARM_INSTR_LDR_HALF;
              bus.word.arm.ls_half.opcode = ARM_LOAD_STORE_HALFWORD;
            end else begin
              bus.instr_type = ARM_INSTR_LDR_HALF;
              bus.word.arm.ls_half.opcode = ARM_LOAD_SIGNED_HALFWORD;
            end

            bus.decoded_regs.Rm = 4'(IR_THUMB[8:6]);  // Offset register
            bus.decoded_regs.Rn = 4'(IR_THUMB[5:3]);
            bus.decoded_regs.Rd = 4'(IR_THUMB[2:0]);

            $display(
                "[GBA_Decoder] Detected THUMB STRH/LDSB/LDRSB/LDRSH instruction with IR=0x%08x",
                IR_THUMB);
          end

          // PC Relative Load
          16'b0100_1???_????_????: begin
            $display("[GBA_Decoder] Detected THUMB PC-relative load instruction with IR=0x%08x",
                     IR_THUMB);

            bus.word.arm.ls.I = ARM_LDR_STR_IMMEDIATE;
            bus.word.arm.ls.P = ARM_LDR_STR_PRE_OFFSET;
            bus.word.arm.ls.U = 1'b1;  // ADD
            bus.word.arm.ls.B = ARM_LDR_STR_WORD;
            bus.word.arm.ls.wt = 1'b0;  // No writeback
            bus.word.arm.ls.align_flag = 1'b1;  // PC-relative loads are word-aligned

            bus.instr_type = ARM_INSTR_LOAD;

            bus.word.arm.ls.offset.imm12 = 12'(IR_THUMB[7:0] << 2);

            bus.decoded_regs.Rn = 4'd15;  // PC
            bus.decoded_regs.Rd = 4'(IR_THUMB[10:8]);
          end

          // Hi Register Operations / Branch Exchange
          // TODO: PC add 4?
          16'b0100_01??_????_????: begin
            unique case (IR_THUMB[9:8])
              2'd0: begin
                $display("[GBA_Decoder] Detected THUMB ADD Rd, Hs instruction with IR=0x%08x",
                         IR_THUMB);
                bus.instr_type = ARM_INSTR_DATAPROC_REG_IMM;

                bus.word.arm.data_proc_reg_imm.opcode = ALU_OP_ADD;

                bus.word.arm.data_proc_reg_imm.shift_type = SHIFT_LSL;
                bus.word.arm.data_proc_reg_imm.shift_amount = 0;

                // bus.word.arm.data_proc_reg_imm.pc_add_4 = 1'b1;

                bus.decoded_regs.Rd = {IR_THUMB[7], IR_THUMB[2:0]};
                bus.decoded_regs.Rn = {IR_THUMB[7], IR_THUMB[2:0]};
                bus.decoded_regs.Rm = {IR_THUMB[6], IR_THUMB[5:3]};

                bus.word.arm.data_proc_reg_imm.set_flags = 1'b0;
              end

              2'd1: begin
                $display("[GBA_Decoder] Detected THUMB CMP Rd, Hs instruction with IR=0x%08x",
                         IR_THUMB);
                bus.instr_type = ARM_INSTR_DATAPROC_REG_IMM;

                bus.word.arm.data_proc_reg_imm.opcode = ALU_OP_CMP;

                bus.word.arm.data_proc_reg_imm.shift_type = SHIFT_LSL;
                bus.word.arm.data_proc_reg_imm.shift_amount = 0;

                bus.decoded_regs.Rn = {IR_THUMB[7], IR_THUMB[2:0]};
                bus.decoded_regs.Rm = {IR_THUMB[6], IR_THUMB[5:3]};

                bus.word.arm.data_proc_reg_imm.set_flags = 1'b1;
              end

              2'd2: begin
                // TODO: Nop if R8 == R8
                $display("[GBA_Decoder] Detected THUMB MOV Rd, Hs instruction with IR=0x%08x",
                         IR_THUMB);
                bus.instr_type = ARM_INSTR_DATAPROC_REG_IMM;

                bus.word.arm.data_proc_reg_imm.opcode = ALU_OP_MOV;

                bus.word.arm.data_proc_reg_imm.shift_type = SHIFT_LSL;
                bus.word.arm.data_proc_reg_imm.shift_amount = 0;

                bus.decoded_regs.Rd = {IR_THUMB[7], IR_THUMB[2:0]};
                bus.decoded_regs.Rn = {IR_THUMB[7], IR_THUMB[2:0]};
                bus.decoded_regs.Rm = {IR_THUMB[6], IR_THUMB[5:3]};

                bus.word.arm.data_proc_reg_imm.set_flags = 1'b0;
              end

              2'd3: begin
                $display(
                    "[GBA_Decoder] Detected THUMB BX instruction with Hs as operand instruction with IR=0x%08x",
                    IR_THUMB);

                if (IR_THUMB[7] == 1'b0) begin
                  bus.instr_type = ARM_INSTR_BRANCH_EX;
                end else begin
                  // TODO
                  bus.instr_type = ARM_INSTR_BRANCH_EX;

                  $display(
                      "[GBA_Decoder] Detected THUMB BLX instruction with Hs as operand instruction with IR=0x%08x, but BLX is not yet implemented, treating as BX for now",
                      IR_THUMB);
                end

                // For BX Rn (ARM) == Rs (THUMB)
                bus.decoded_regs.Rn = {IR_THUMB[6], IR_THUMB[5:3]};
                // bus.word.arm.data_proc_reg_reg.opcode = ALU_OP_BX;
                // bus.instr_type = ARM_INSTR_DATAPROC_REG_REG;
              end
            endcase

            $display(
                "[GBA_Decoder] Detected THUMB Hi register operation or branch exchange instruction with IR=0x%08x",
                IR_THUMB);
          end

          // ALU Operations
          // Rd = Rd op Rs
          // Rs: 5-3
          // Rd: 2-0
          16'b0100_00??_????_????: begin
            $display("[GBA_Decoder] Detected THUMB ALU operation instruction with IR=0x%08x",
                     IR_THUMB);

            unique case (IR_THUMB[9:6])
              4'h0, 4'h1, 4'h5, 4'h6, 4'h8, 4'hA, 4'hB, 4'hC, 4'hE, 4'hF: begin
                $display("[GBA_Decoder] Detected THUMB AND instruction with IR=0x%08x", IR_THUMB);
                bus.word.arm.data_proc_reg_imm.opcode = decoder_util_pkg::THUMB_ALU_LUT[IR_THUMB[9:6]];

                bus.instr_type = ARM_INSTR_DATAPROC_REG_IMM;

                bus.decoded_regs.Rd = 4'(IR_THUMB[2:0]);
                bus.decoded_regs.Rn = 4'(IR_THUMB[2:0]);
                bus.decoded_regs.Rm = 4'(IR_THUMB[5:3]);

                bus.word.arm.data_proc_reg_imm.shift_type = SHIFT_LSL;
                bus.word.arm.data_proc_reg_imm.shift_amount = 0;

                bus.word.arm.data_proc_reg_imm.set_flags = 1'b1;
              end

              4'h2, 4'h3, 4'h4, 4'h7: begin
                $display("[GBA_Decoder] Detected THUMB LSL/LSR/ASR/ROR instruction with IR=0x%08x",
                         IR_THUMB);
                bus.word.arm.data_proc_reg_reg.opcode = ALU_OP_MOV;
                bus.instr_type = ARM_INSTR_DATAPROC_REG_REG;

                bus.word.arm.data_proc_reg_reg.shift_type = decoder_util_pkg::THUMB_SHIFT_LUT[IR_THUMB[9:6]];
                bus.decoded_regs.Rd = 4'(IR_THUMB[2:0]);
                bus.decoded_regs.Rm = 4'(IR_THUMB[2:0]);  // Rd
                bus.decoded_regs.Rs = 4'(IR_THUMB[5:3]);

                bus.word.arm.data_proc_reg_reg.set_flags = 1'b1;
              end

              4'h9: begin
                $display("[GBA_Decoder] Detected THUMB NEG instruction with IR=0x%08x", IR_THUMB);
                bus.word.arm.data_proc_imm.opcode = ALU_OP_SUB_REVERSED;
                bus.instr_type = ARM_INSTR_DATAPROC_IMM;

                bus.decoded_regs.Rd = 4'(IR_THUMB[2:0]);
                bus.decoded_regs.Rn = 4'(IR_THUMB[5:3]);
                bus.word.arm.data_proc_imm.imm8 = 8'd0;

                bus.word.arm.data_proc_imm.rotate = 0;

                bus.word.arm.data_proc_imm.set_flags = 1'b1;
              end

              4'hD: begin
                $display("[GBA_Decoder] Detected THUMB MUL instruction with IR=0x%08x", IR_THUMB);
                bus.instr_type = ARM_INSTR_MULTIPLY;
                bus.word.arm.mul.opcode = ARM_MUL;

                bus.decoded_regs.Rd = 4'(IR_THUMB[2:0]);
                bus.decoded_regs.Rs = 4'(IR_THUMB[2:0]);
                bus.decoded_regs.Rm = 4'(IR_THUMB[5:3]);

                bus.word.arm.mul.S = 1'b1;
              end
            endcase
          end

          // Move / Compare / Add / Subtract Immediate
          16'b001?_????_????_????: begin
            $display(
                "[GBA_Decoder] Detected THUMB move/compare/add/subtract immediate instruction with IR=0x%08x",
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
                $display("[GBA_Decoder] Detected THUMB MOV immediate instruction with IR=0x%08x",
                         IR_THUMB);
                bus.word.arm.data_proc_imm.opcode = ALU_OP_MOV;
                bus.instr_type = ARM_INSTR_DATAPROC_IMM;
              end
              2'b01: begin
                $display(
                    "[GBA_Decoder] Detected THUMB CMP instruction with register operand with IR=0x%08x",
                    IR_THUMB);
                bus.word.arm.data_proc_imm.opcode = ALU_OP_CMP;
                bus.instr_type = ARM_INSTR_DATAPROC_IMM;
              end
              2'b10: begin
                $display("[GBA_Decoder] Detected THUMB add immediate instruction with IR=0x%08x",
                         IR_THUMB);
                bus.word.arm.data_proc_imm.opcode = ALU_OP_ADD;
                bus.instr_type = ARM_INSTR_DATAPROC_IMM;
              end
              2'b11: begin
                $display(
                    "[GBA_Decoder] Detected THUMB subtract immediate instruction with IR=0x%08x",
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
                    "[GBA_Decoder] Detected THUMB add instruction with register operand with IR=0x%08x",
                    IR_THUMB);
                bus.word.arm.data_proc_reg_imm.opcode = ALU_OP_ADD;
                bus.instr_type = ARM_INSTR_DATAPROC_REG_IMM;

                bus.word.arm.data_proc_reg_imm.shift_type = SHIFT_LSL;
                bus.word.arm.data_proc_reg_imm.shift_amount = 0;

                bus.word.arm.data_proc_reg_imm.set_flags = 1'b1;
              end
              2'b01: begin
                $display(
                    "[GBA_Decoder] Detected THUMB subtract instruction with register operand with IR=0x%08x",
                    IR_THUMB);
                bus.word.arm.data_proc_reg_imm.opcode = ALU_OP_SUB;
                bus.instr_type = ARM_INSTR_DATAPROC_REG_IMM;

                bus.word.arm.data_proc_reg_imm.shift_type = SHIFT_LSL;
                bus.word.arm.data_proc_reg_imm.shift_amount = 0;

                bus.word.arm.data_proc_reg_imm.set_flags = 1'b1;
              end
              2'b10: begin
                $display(
                    "[GBA_Decoder] Detected THUMB add instruction with immediate operand with IR=0x%08x",
                    IR_THUMB);
                bus.word.arm.data_proc_imm.opcode = ALU_OP_ADD;
                bus.instr_type = ARM_INSTR_DATAPROC_IMM;
                bus.word.arm.data_proc_imm.rotate = 0;

                bus.word.arm.data_proc_imm.set_flags = 1'b1;
                bus.word.arm.data_proc_imm.imm8 = 8'(IR_THUMB[8:6]);
              end
              2'b11: begin
                $display(
                    "[GBA_Decoder] Detected THUMB subtract instruction with immediate operand with IR=0x%08x",
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
            $display(
                "[GBA_Decoder] Detected THUMB move shifted register instruction with IR=0x%08x",
                IR_THUMB);
            bus.instr_type = ARM_INSTR_DATAPROC_REG_IMM;

            bus.word.arm.data_proc_reg_imm.opcode = ALU_OP_MOV;
            bus.word.arm.data_proc_reg_imm.set_flags = 1'b1;

            bus.word.arm.data_proc_reg_imm.shift_type = shift_type_t'(IR_THUMB[12:11]);
            bus.word.arm.data_proc_reg_imm.shift_amount = IR_THUMB[10:6];

            bus.decoded_regs.Rm = 4'(IR_THUMB[5:3]);

            bus.decoded_regs.Rn = 4'(IR_THUMB[5:3]);
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
