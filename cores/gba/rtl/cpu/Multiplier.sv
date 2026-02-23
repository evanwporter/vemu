import gba_types_pkg::*;

module GBA_Multiplier (
    input logic clk,
    input logic reset,
    GBA_Multiplier_if.Multiplier_side bus
);

  /// Multiplicand
  word_t M;

  /// Multiplier
  word_t S;

  /// TODO: Make three bits
  logic [7:0] cycle;

  always_ff @(posedge clk) begin
    if (reset) begin
      cycle <= 0;
    end else begin
      if (bus.enable) begin
        cycle <= cycle + 1;

        $display("[Multiplier] Cycle %0d: M=%0d, S=%0d, Result=%0d", cycle, M, S, bus.result);

        if (cycle == 0) begin
          $display("[Multiplier] Starting multiplication: M=%0d, S=%0d", bus.A_bus, bus.B_bus);
          M <= bus.A_bus;
          S <= bus.B_bus;
        end
      end
    end
  end

  always_comb begin
    bus.result = 32'd0;
    if (bus.enable && cycle != 0) begin
      bus.result = S[cycle-1] ? M : 32'd0;
    end
  end

endmodule : GBA_Multiplier
