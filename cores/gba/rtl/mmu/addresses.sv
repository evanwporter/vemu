import gba_types_pkg::*;

//============================================================
// Game Boy Memory Map (DMG/CGB)
//============================================================

package gba_mmu_addresses_pkg;

  localparam word_t BIOS_start = 32'h00000000;
  localparam word_t BIOS_end = 32'h00003FFF;
  localparam word_t BIOS_len = BIOS_end - BIOS_start + 1;

  localparam word_t WRAM_board_start = 32'h02000000;
  localparam word_t WRAM_board_end = 32'h0203FFFF;
  localparam word_t WRAM_board_len = WRAM_board_end - WRAM_board_start + 1;

  localparam word_t WRAM_chip_start = 32'h03000000;
  localparam word_t WRAM_chip_end = 32'h03007FFF;
  localparam word_t WRAM_chip_len = WRAM_chip_end - WRAM_chip_start + 1;

  localparam word_t IO_start = 32'h04000000;
  localparam word_t IO_end = 32'h040003FF;
  localparam word_t IO_len = IO_end - IO_start + 1;

  // LCD control, status, background, window, mosaic, and blending registers.
  localparam word_t PPU_IO_start = 32'h04000000;
  localparam word_t PPU_IO_end = 32'h04000057;
  localparam word_t PPU_IO_len = PPU_IO_end - PPU_IO_start + 1;

  localparam word_t Palette_start = 32'h05000000;
  localparam word_t Palette_end = 32'h050003FF;
  localparam word_t Palette_len = Palette_end - Palette_start + 1;

  localparam word_t VRAM_start = 32'h06000000;
  localparam word_t VRAM_end = 32'h06017FFF;
  localparam word_t VRAM_len = VRAM_end - VRAM_start + 1;

  localparam word_t OAM_start = 32'h07000000;
  localparam word_t OAM_end = 32'h070003FF;
  localparam word_t OAM_len = OAM_end - OAM_start + 1;

  localparam word_t GAMEPAK_WS0_start = 32'h08000000;
  localparam word_t GAMEPAK_WS0_end = 32'h08FFFFFF;
  localparam word_t GAMEPAK_WS0_len = GAMEPAK_WS0_end - GAMEPAK_WS0_start + 1;

  localparam word_t GAMEPAK_WS1_start = 32'h08000000;
  localparam word_t GAMEPAK_WS1_end = 32'h08FFFFFF;
  localparam word_t GAMEPAK_WS1_len = GAMEPAK_WS1_end - GAMEPAK_WS1_start + 1;

  localparam word_t GAMEPAK_WS2_start = 32'h08000000;
  localparam word_t GAMEPAK_WS2_end = 32'h08FFFFFF;
  localparam word_t GAMEPAK_WS2_len = GAMEPAK_WS2_end - GAMEPAK_WS2_start + 1;

  localparam word_t GAMEPAK_SRAM_start = 32'h08000000;
  localparam word_t GAMEPAK_SRAM_end = 32'h08FFFFFF;
  localparam word_t GAMEPAK_SRAM_len = GAMEPAK_SRAM_end - GAMEPAK_SRAM_start + 1;

endpackage : gba_mmu_addresses_pkg
