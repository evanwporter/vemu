import gba_types_pkg::*;

//============================================================
// GBA LCD I/O Register Map (0x04000000 range)
//============================================================

package gba_ppu_addresses_pkg;

  // Base
  localparam addr_t PPU_IO_BASE = 32'h04000000;

  //============================================================
  // Display Control / Status
  //============================================================
  localparam addr_t REG_DISPCNT = 32'h04000000;
  localparam addr_t REG_GREENSWP = 32'h04000002;
  localparam addr_t REG_DISPSTAT = 32'h04000004;
  localparam addr_t REG_VCOUNT = 32'h04000006;

  //============================================================
  // Background Control
  //============================================================
  localparam addr_t REG_BG0CNT = 32'h04000008;
  localparam addr_t REG_BG1CNT = 32'h0400000A;
  localparam addr_t REG_BG2CNT = 32'h0400000C;
  localparam addr_t REG_BG3CNT = 32'h0400000E;

  //============================================================
  // Background Scrolling
  //============================================================
  localparam addr_t REG_BG0HOFS = 32'h04000010;
  localparam addr_t REG_BG0VOFS = 32'h04000012;

  localparam addr_t REG_BG1HOFS = 32'h04000014;
  localparam addr_t REG_BG1VOFS = 32'h04000016;

  localparam addr_t REG_BG2HOFS = 32'h04000018;
  localparam addr_t REG_BG2VOFS = 32'h0400001A;

  localparam addr_t REG_BG3HOFS = 32'h0400001C;
  localparam addr_t REG_BG3VOFS = 32'h0400001E;

  //============================================================
  // BG2 Affine (Rotation/Scaling)
  //============================================================
  localparam addr_t REG_BG2PA = 32'h04000020;
  localparam addr_t REG_BG2PB = 32'h04000022;
  localparam addr_t REG_BG2PC = 32'h04000024;
  localparam addr_t REG_BG2PD = 32'h04000026;

  localparam addr_t REG_BG2X = 32'h04000028;  // 32-bit
  localparam addr_t REG_BG2Y = 32'h0400002C;  // 32-bit

  //============================================================
  // BG3 Affine (Rotation/Scaling)
  //============================================================
  localparam addr_t REG_BG3PA = 32'h04000030;
  localparam addr_t REG_BG3PB = 32'h04000032;
  localparam addr_t REG_BG3PC = 32'h04000034;
  localparam addr_t REG_BG3PD = 32'h04000036;

  localparam addr_t REG_BG3X = 32'h04000038;  // 32-bit
  localparam addr_t REG_BG3Y = 32'h0400003C;  // 32-bit

  //============================================================
  // Windowing
  //============================================================
  localparam addr_t REG_WIN0H = 32'h04000040;
  localparam addr_t REG_WIN1H = 32'h04000042;
  localparam addr_t REG_WIN0V = 32'h04000044;
  localparam addr_t REG_WIN1V = 32'h04000046;

  localparam addr_t REG_WININ = 32'h04000048;
  localparam addr_t REG_WINOUT = 32'h0400004A;

  //============================================================
  // Effects
  //============================================================
  localparam addr_t REG_MOSAIC = 32'h0400004C;

  // 0x0400004E unused

  localparam addr_t REG_BLDCNT = 32'h04000050;
  localparam addr_t REG_BLDALPHA = 32'h04000052;
  localparam addr_t REG_BLDY = 32'h04000054;

  // 0x04000056 unused

endpackage : gba_ppu_addresses_pkg
