import gba_types_pkg::*;

package gba_ppu_types_pkg;

  /// https://gbadev.net/tonc/video.html#sec-vid-regs
  /// https://problemkaputt.de/gbatek-lcd-i-o-display-control.htm
  typedef struct packed {
    logic winobj;
    logic win1;    // bit 14
    logic win0;    // bit 13

    logic obj;  // bit 12
    logic bg3;  // bit 11
    logic bg2;  // bit 10
    logic bg1;  // bit 9
    logic bg0;  // bit 8

    logic blank;  // bit 7
    logic obj_1d;  // bit 6
    logic oam_hblank;  // bit 5

    /// Display Page Select
    logic page;

    /// CGB Mode
    /// Denotes whether the system is in GBA or CGB mode.
    /// 0=GBA, 1=CGB
    logic gb;  // bit 3

    logic [2:0] mode;  // bits 2-0
  } dispcnt_t;

  /// https://gbadev.net/tonc/video.html#sec-vid-regs
  /// https://problemkaputt.de/gbatek-lcd-i-o-interrupts-and-status.htm
  typedef struct packed {
    logic [7:0] vcount_setting;  // bits 15-8  (LYC / VCount trigger)

    logic lyc_msb;  // bit 7 (DS/NDS extension, usually unused on GBA)
    logic unused6;  // bit 6 (unused on GBA)

    logic vcounter_irq;  // bit 5 (VcI)
    logic hblank_irq;    // bit 4 (HbI)
    logic vblank_irq;    // bit 3 (VbI)

    logic vcounter_flag;  // bit 2 (VcS) read-only
    logic hblank_flag;    // bit 1 (HbS) read-only
    logic vblank_flag;    // bit 0 (VbS) read-only
  } dispstat_t;

  typedef struct {
    /// LCD Control
    dispcnt_t dispcnt;

    /// LCD Status
    dispstat_t dispstat;
  } ppu_regs_t;

  localparam half_t DISPCNT_MASK = 16'b1111111111111111;
  localparam half_t DISPSTAT_MASK = 32'b1111111100111000;

endpackage : gba_ppu_types_pkg
