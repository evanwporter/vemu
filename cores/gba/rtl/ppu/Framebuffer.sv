import gba_ppu_types_pkg::*;
import gba_ppu_constants_pkg::*;

`include "gb/util/logger.svh"

module Framebuffer (
    input logic clk,
    input logic reset,
    input logic pixel_transfer_en, // PPU mode 3 active

    // FIFO interface
    FIFO_if.Framebuffer_side fifo_bus,
    FIFO_if.Framebuffer_side obj_fifo_bus,

    RenderingControl_if.Framebuffer_side control_bus,

    input ppu_regs_t regs,

    /// Flush the framebuffer
    input logic flush,

    /// Signals when a line is done being drawn
    output logic line_done,

    /// Signals when a full frame is done being drawn
    output logic frame_done
);

  localparam int NUM_PIXELS = GBA_SCREEN_WIDTH * GBA_SCREEN_HEIGHT;

  logic [7:0] x_screen;
  logic [7:0] y_screen;

  assign control_bus.pixel_x = x_screen;

  wire [14:0] write_addr = 15'((y_screen * GBA_SCREEN_WIDTH) + x_screen);

  (* maybe_unused *)
  color_t buffer[NUM_PIXELS];

  (* maybe_unused *)
  color_t obj_buffer[NUM_PIXELS];

  /// Number of pixels to discard at start of each scanline
  /// Typically: `SCX % 8`
  logic [2:0] discard_count;

  /// Should we consume a pixel from the FIFO this cycle?
  wire pixel_consume = pixel_transfer_en && !fifo_bus.empty && !control_bus.stall;

  assign fifo_bus.read_en = pixel_consume;

  assign obj_fifo_bus.read_en = pixel_consume && !obj_fifo_bus.empty;

  // Helper function to map 2-bit color + 8-bit palette to a 2-bit shade
  function automatic color_t map_palette(logic [1:0] color_idx, logic [7:0] palette);
    unique case (color_idx)
      2'd0: return color_t'(palette[1:0]);
      2'd1: return color_t'(palette[3:2]);
      2'd2: return color_t'(palette[5:4]);
      2'd3: return color_t'(palette[7:6]);
    endcase
  endfunction

  color_id_t bg_color_id;
  assign bg_color_id = regs.LCDC[0] ? fifo_bus.read_data.color : COLOR_ID_0;

  color_id_t obj_color_id;
  assign obj_color_id = regs.LCDC[1] ? obj_fifo_bus.read_data.color : COLOR_ID_0;

  color_t bg_pixel;
  color_t obj_pixel;

  assign obj_pixel = map_palette(
      obj_color_id, obj_fifo_bus.read_data.dmg_palette ? regs.OBP1 : regs.OBP0
  );
  assign bg_pixel = map_palette(bg_color_id, regs.BGP);

  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      x_screen <= 8'd0;
      y_screen <= 8'd0;
      frame_done <= 1'b0;
      discard_count <= 3'd0;
      line_done <= 1'b0;

    end else if (flush) begin
      x_screen <= 8'd0;

      /// Effectively: `SCX % 8`
      discard_count <= regs.SCX[2:0];

      line_done <= 1'b0;

    end else begin

      frame_done <= 1'b0;
      line_done  <= 1'b0;

      // Only draw visible area (160x144) when FIFO has pixels
      if (pixel_consume) begin

        if (discard_count != 3'd0) begin
          // Discard pixel
          discard_count <= discard_count - 1'b1;
        end else begin

          // Store pixel in framebuffer
          // The read_data is always the top pixel in the FIFO
          if (!obj_fifo_bus.empty  &&
              obj_color_id != 2'd0 &&
              (obj_fifo_bus.read_data.bg_prio == 1'b0 ||
               bg_color_id == 2'd0)) begin
            // If the OBJ queue has a pixel and its not transparent we use it
            buffer[write_addr] <= obj_pixel;
          end else begin
            // Background/Window uses BGP
            buffer[write_addr] <= bg_pixel;
          end

          if (x_screen == (GBA_SCREEN_WIDTH - 8'd1)) begin
            // End of scanline
            x_screen  <= 8'd0;
            y_screen  <= y_screen + 8'd1;

            line_done <= 1'b1;

            `LOG_TRACE(("[PPU] [FB] Completed scanline %0d", y_screen))

            if (y_screen == GBA_SCREEN_HEIGHT - 1) begin
              // End of frame
              frame_done <= 1'b1;
              y_screen   <= 8'd0;

              `LOG_TRACE(("[PPU] [FB] Frame complete!"))
            end
          end else begin
            // Next pixel
            x_screen <= x_screen + 8'd1;
          end
        end
      end
    end
  end

endmodule
