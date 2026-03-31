import gba_types_pkg::*;
import gba_cpu_decoder_types_pkg::*;

module GBA_Multiplier (
    input logic clk,
    input logic reset,
    GBA_Multiplier_if.Multiplier_side bus
);
  word_t upper_result;
  word_t lower_result;

  logic signed [31:0] s_upper_result;
  logic signed [31:0] s_lower_result;

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
              {upper_result, lower_result} <= bus.A_bus * bus.B_bus;
            end
          end

          ARM_UMULL, ARM_UMLAL: begin
            if (cycle == 0) begin
              $display("[Multiplier] Starting unsigned multiplication: M=%0d, S=%0d", bus.B_bus,
                       bus.A_bus);
              {upper_result, lower_result} <= bus.A_bus * bus.B_bus;
            end else if (cycle == 1) begin
              accum_high <= bus.A_bus;
              accum_low <= bus.B_bus;

              {upper_result, lower_result} <= {upper_result, lower_result} + {bus.A_bus, bus.B_bus};

              $display("[Multiplier] Cycle 1: M=%0d, S=%0d, Accum Low=%0d", M, S, accum_low);
            end
          end

          ARM_SMULL, ARM_SMLAL: begin
            if (cycle == 0) begin
              $display("[Multiplier] Starting signed multiplication: A=%0d, B=%0d",
                       $signed(bus.A_bus), $signed(bus.B_bus));

              {s_upper_result, s_lower_result} <= $signed(bus.A_bus) * $signed(bus.B_bus);
            end else if (cycle == 1) begin
              accum_high <= bus.A_bus;
              accum_low  <= bus.B_bus;

              {s_upper_result, s_lower_result} = {s_upper_result, s_lower_result} +
                  $signed({bus.A_bus, bus.B_bus});
            end
          end

          default: begin

          end
        endcase
      end else cycle <= 0;
    end
  end

  always_comb begin
    bus.result = 0;
    bus.flags  = 0;
    if (bus.enable) begin
      unique case (bus.opcode)
        ARM_MUL, ARM_MLA: begin
          if (cycle == 1) begin
            bus.result = lower_result + bus.A_bus;

            $display("[Multiplier] Cycle 1: M=%0d, S=%0d, Lower Result=%0d", M, S, lower_result);
          end
        end

        ARM_UMULL, ARM_UMLAL: begin
          if (cycle == 2) begin
            bus.result = lower_result;

            $display("[Multiplier] Cycle 2: M=%0d, S=%0d, Lower Result=%0d", M, S, lower_result);
          end else if (cycle == 3) begin
            bus.result  = upper_result;

            bus.flags.N = upper_result[31];
            bus.flags.Z = ({upper_result, lower_result} == 0);

            $display("[Multiplier] Cycle 3: M=%0d, S=%0d, Upper Result=%0d", M, S, upper_result);
          end
        end

        ARM_SMULL, ARM_SMLAL: begin
          if (cycle == 2) begin
            bus.result = s_lower_result;

            $display("[Multiplier] Cycle 2: M=%0d, S=%0d, Lower Result=%0d", M, S, s_lower_result);
          end else if (cycle == 3) begin
            bus.result  = s_upper_result;

            bus.flags.N = s_upper_result[31];
            bus.flags.Z = ({s_upper_result, s_lower_result} == 0);

            $display("[Multiplier] Cycle 3: M=%0d, S=%0d, Upper Result=%0d", M, S, s_upper_result);
          end
        end

        default: ;
      endcase
    end
  end

endmodule : GBA_Multiplier
