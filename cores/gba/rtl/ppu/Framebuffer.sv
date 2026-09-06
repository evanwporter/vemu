import gba_ppu_types_pkg::*;

module GBA_Framebuffer (
    input logic clk,
    input logic reset,
    input logic [8:0] scan_x,
    input logic [8:0] scan_y,
    input pixel_t composed_pixel
);

  (* maybe_unused *)
  pixel_t [239:0][159:0] framebuffer  /*verilator public_flat_rw*/;

  always_ff @(posedge clk) begin
    if (reset) begin
    end else begin
      if (scan_x < 240 && scan_y < 160) begin
        framebuffer[scan_x][scan_y] <= composed_pixel;
      end
    end
  end

endmodule : GBA_Framebuffer
