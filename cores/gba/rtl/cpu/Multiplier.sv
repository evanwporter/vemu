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
      if (bus.enable) begin
        cycle <= cycle + 1;

        $display("[Multiplier] Cycle %0d: M=%0d, S=%0d, Result=%0d", cycle, M, S, bus.result);

        unique case (bus.opcode)
          ARM_MUL, ARM_MLA: begin
            if (cycle == 0) begin
              $display("[Multiplier] Starting multiplication: M=%0d, S=%0d", bus.B_bus, bus.A_bus);
              S <= bus.A_bus;
              M <= bus.B_bus;
            end
          end

          ARM_UMULL, ARM_UMLAL: begin
            // TODO long multiplication
            if (cycle == 0) begin
              $display("[Multiplier] Starting long multiplication: M=%0d, S=%0d", bus.B_bus,
                       bus.A_bus);
              S <= bus.A_bus;
              M <= bus.B_bus;
            end

            if (cycle == 1) begin
              accum_low  <= bus.B_bus;
              accum_high <= bus.A_bus;
              $display("[Multiplier] Initial accum_low set to %0d", accum_low);
            end

            if (cycle >= 2) begin
              if (S[0])
                {accum_high, accum_low} <= {accum_high, accum_low} + ({32'd0, M} << (cycle - 2));
              S <= S >> 1;
              $display("[Multiplier] After cycle %0d: accum_high=%0d, accum_low=%0d, S=%0d", cycle,
                       accum_high, accum_low, S);
            end
          end

          default: begin
            // Handle other opcodes or do nothing

          end
        endcase
      end
    end
  end

  always_comb begin
    /// Chunk is built from {S[2i + 1], S[2i], S[2i - 1]} where i = cycle - 1
    logic [2:0] chunk;
    word_t addend;

    chunk = 3'd0;
    addend = 32'd0;

    bus.result = 32'd0;
    if (bus.enable) begin
      unique case (bus.opcode)
        ARM_MUL, ARM_MLA: begin
          if (cycle != 0) begin
            if (cycle == 1) begin
              chunk = {S[1], S[0], 1'b0};
            end else begin
              chunk = {S[2*(cycle-1)+1], S[2*(cycle-1)], S[2*(cycle-1)-1]};
            end

            unique case (chunk)
              3'b000: addend = 32'd0;
              3'b001: addend = M;
              3'b010: addend = M;
              3'b011: addend = (M << 1);
              3'b100: addend = (M << 1);
              3'b101: addend = M;
              3'b110: addend = M;
              3'b111: addend = 32'd0;
            endcase

            if (chunk[2])  // negative 
              bus.result = ~addend + 1;
            else bus.result = addend;
          end
        end

        ARM_UMULL, ARM_UMLAL: begin
          if (cycle == 34) begin
            $display(
                "[Multiplier] Long multiplication complete: Final result = {accum_high, accum_low} = %0d",
                {accum_high, accum_low});
            bus.result = accum_low;
          end

          if (cycle == 35) begin
            $display(
                "[Multiplier] Long multiplication complete: Final result = {accum_high, accum_low} = %0d",
                {accum_high, accum_low});
            bus.result = accum_high;
          end
        end

        default: begin
          // Handle other opcodes or do nothing

        end
      endcase
    end
  end

endmodule : GBA_Multiplier
