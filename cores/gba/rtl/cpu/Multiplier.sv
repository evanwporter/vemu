import gba_types_pkg::*;
import gba_cpu_decoder_types_pkg::*;

module GBA_Multiplier (
    input logic clk,
    input logic reset,
    GBA_Multiplier_if.Multiplier_side bus
);

  word_t accum_high;
  word_t accum_low;

  /// Multiplicand
  word_t M;

  /// Multiplier
  word_t S;

  /// TODO: Make three bits
  logic [7:0] cycle;

  // During the shift the first (cycle - 1) bits of M will be chopped off
  // We need to collect these bits and add it to upper_result

  // 0 0 0 0 | 1 0 0 1
  // Shift 2
  // 0 0 1 0 | 0 1 0 0

  // So we collect M[31:(cycle - 1)] and add it to upper_result

  // 0 - 31:31
  // 1 - 31:30
  // 2 - 31:29
  // 3 - 31:28

  // TODO reset cycle counter and regs
  always_ff @(posedge clk) begin
    if (reset) begin
      cycle <= 0;
    end else begin
      cycle <= 0;
      accum_high <= 0;
      accum_low <= 0;

      if (bus.enable) begin
        cycle <= cycle + 1;

        $display("[Multiplier] Cycle %0d: M=%0d, S=%0d, Result=%0d", cycle, M, S, bus.result);

        unique case (bus.opcode)
          ARM_MUL, ARM_MLA: begin
            if (cycle == 0) begin
              $display("[Multiplier] Starting multiplication: M=%0d, S=%0d", bus.B_bus, bus.A_bus);
              {accum_high, accum_low} <= bus.A_bus * bus.B_bus;
            end
          end

          ARM_UMULL, ARM_UMLAL: begin
          end

          default: begin
            // Handle other opcodes or do nothing

          end
        endcase
      end else cycle <= 0;
    end
  end

  always_comb begin
    bus.result = 0;
    if (bus.enable) begin
      if (cycle == 1) begin
        bus.result = accum_low + bus.A_bus;
        $display("[Multiplier] Cycle 1: M=%0d, S=%0d, Accum Low=%0d", M, S, accum_low);
      end
    end
  end

endmodule : GBA_Multiplier
