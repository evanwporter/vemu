import gba_control_types_pkg::*;
import gba_cpu_types_pkg::*;
import gba_cpu_decoder_types_pkg::*;

package control_util_pkg;

  // TODO: Think about setting incrementer_writeback here as well, 
  // since every time we fetch an instruction, we want to increment 
  // the PC for the next instruction.
  function automatic control_t fetch_next_instr();
    control_t s = '0;

    s.memory_read_en  = 1'b1;
    s.memory_latch_IR = 1'b1;

    return s;
  endfunction : fetch_next_instr

  function automatic control_t calc_ls_address(logic U, logic P, logic W, logic is_imm,
                                               logic [11:0] imm);

    control_t s = '0;

    // Update the address bus to use the output of the ALU, which 
    // will is the effective address for the memory access
    s.addr_bus_src = ADDR_SRC_ALU;

    // Subtract (0) or add (1) the offset to the base register depending 
    // on the U bit in the instruction.
    s.ALU_op = U ? ALU_OP_ADD : ALU_OP_SUB;

    $display("[ControlUnit] ALU operation for address calculation is %s",
             s.ALU_op == ALU_OP_ADD ? "ADD" : "SUB");

    // If its pre offset we add/subtract the offset to the base register before the memory access
    if (P == ARM_LDR_STR_PRE_OFFSET) begin
      if (W == 1'b1) begin
        // Updating the base register with the offset is enabled so we 
        // latch operand b for the writeback in the next cycle
        s.ALU_latch_op_b = 1'b1;
      end
    end else begin
      // Post offset, so we don't add/subtract operand b
      // before its used to update the address bus
      s.ALU_disable_op_b = 1'b1;

      // We also make sure to latch operand b so that we can 
      // use it for the writeback in the next cycle
      s.ALU_latch_op_b   = 1'b1;
    end

    return s;
  endfunction : calc_ls_address

endpackage : control_util_pkg
