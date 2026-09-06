import gba_mmu_addresses_pkg::*;
import gba_types_pkg::*;
import gba_mmu_types_pkg::*;
import gba_ppu_types_pkg::*;

module Compositor (
    input pixel_t bg_pixel[4],
    input text_bg_regs_t bg_regs[4],
    input dispcnt_t dispcnt,
    output pixel_t composed_pixel
);

  logic [3:0] bg_enable;
  logic [1:0] best_priority;
  logic found_pixel;

  always_comb begin
    bg_enable[0] = dispcnt.bg0_display;
    bg_enable[1] = dispcnt.bg1_display;
    bg_enable[2] = dispcnt.bg2_display;
    bg_enable[3] = dispcnt.bg3_display;
  end

  always_comb begin
    composed_pixel = '{default: '0, transparent: 1'b1};
    best_priority  = 2'd3;
    found_pixel    = 1'b0;

    // Lower-numbered BG wins equal-priority ties.
    // Since we iterate BG3 -> BG0 and allow <=,
    // BG0 overwrites BG1, BG1 overwrites BG2, etc.
    for (int i = 3; i >= 0; i--) begin
      if (bg_enable[i] && !bg_pixel[i].transparent) begin
        if (!found_pixel || bg_regs[i].control.bg_priority <= best_priority) begin
          composed_pixel = bg_pixel[i];
          best_priority  = bg_regs[i].control.bg_priority;
          found_pixel    = 1'b1;
        end
      end
    end
  end

endmodule : Compositor
