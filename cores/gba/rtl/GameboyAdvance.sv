import gba_mmu_addresses_pkg::*;

module GameboyAdvance (
    input logic clk,
    input logic reset
);

  GBA_Bus_if cpu_bus ();

  // Internal memory
  GBA_Bus_if bios_bus ();
  GBA_Bus_if wram_board_bus ();
  GBA_Bus_if wram_chip_bus ();
  GBA_Bus_if io_bus ();

  // Display memory
  GBA_Bus_if palette_bus ();
  GBA_Bus_if vram_bus ();
  GBA_Bus_if oam_bus ();

  // Game Pak (external)
  GBA_Bus_if gamepak_ws0_bus ();
  GBA_Bus_if gamepak_ws1_bus ();
  GBA_Bus_if gamepak_ws2_bus ();
  GBA_Bus_if gamepak_sram_bus ();

  ARM7TMDI cpu_inst (
      .clk  (clk),
      .reset(reset),
      .bus  (cpu_bus)
  );

  GBA_MMU mmu (
      .cpu_bus(cpu_bus),
      .bios_bus(bios_bus),
      .wram_board_bus(wram_board_bus),
      .wram_chip_bus(wram_chip_bus),
      .io_bus(io_bus),
      .palette_bus(palette_bus),
      .vram_bus(vram_bus),
      .oam_bus(oam_bus),
      .gamepak_ws0_bus(gamepak_ws0_bus),
      .gamepak_ws1_bus(gamepak_ws1_bus),
      .gamepak_ws2_bus(gamepak_ws2_bus),
      .gamepak_sram_bus(gamepak_sram_bus)
  );

  GBA_Memory #(
      .START_ADDR(BIOS_start),
      .END_ADDR(BIOS_end),
      .SIZE(BIOS_len)
  ) BIOS (
      .clk  (clk),
      .reset(reset),
      .bus  (bios_bus)
  );

  GBA_Memory #(
      .START_ADDR(WRAM_board_start),
      .END_ADDR(WRAM_board_end),
      .SIZE(WRAM_board_len)
  ) WRAM_BOARD (
      .clk  (clk),
      .reset(reset),
      .bus  (wram_board_bus)
  );

  GBA_Memory #(
      .START_ADDR(WRAM_chip_start),
      .END_ADDR(WRAM_chip_end),
      .SIZE(WRAM_chip_len)
  ) WRAM_CHIP (
      .clk  (clk),
      .reset(reset),
      .bus  (wram_chip_bus)
  );

  GBA_Memory #(
      .START_ADDR(IO_start),
      .END_ADDR(IO_end),
      .SIZE(IO_len)
  ) IO (
      .clk  (clk),
      .reset(reset),
      .bus  (io_bus)
  );

  GBA_Memory #(
      .START_ADDR(Palette_start),
      .END_ADDR  (Palette_end),
      .SIZE      (Palette_len)
  ) Palette (
      .clk  (clk),
      .reset(reset),
      .bus  (palette_bus)
  );

  GBA_Memory #(
      .START_ADDR(VRAM_start),
      .END_ADDR  (VRAM_end),
      .SIZE      (VRAM_len)
  ) VRAM (
      .clk  (clk),
      .reset(reset),
      .bus  (vram_bus)
  );

  GBA_Memory #(
      .START_ADDR(OAM_start),
      .END_ADDR  (OAM_end),
      .SIZE      (OAM_len)
  ) OAM (
      .clk  (clk),
      .reset(reset),
      .bus  (oam_bus)
  );

  GBA_Memory #(
      .START_ADDR(GAMEPAK_WS0_start),
      .END_ADDR  (GAMEPAK_WS0_end),
      .SIZE      (GAMEPAK_WS0_len)
  ) GAMEPAK_WS0 (
      .clk  (clk),
      .reset(reset),
      .bus  (gamepak_ws0_bus)
  );

  GBA_Memory #(
      .START_ADDR(GAMEPAK_WS1_start),
      .END_ADDR  (GAMEPAK_WS1_end),
      .SIZE      (GAMEPAK_WS1_len)
  ) GAMEPAK_WS1 (
      .clk  (clk),
      .reset(reset),
      .bus  (gamepak_ws1_bus)
  );

  GBA_Memory #(
      .START_ADDR(GAMEPAK_WS2_start),
      .END_ADDR  (GAMEPAK_WS2_end),
      .SIZE      (GAMEPAK_WS2_len)
  ) GAMEPAK_WS2 (
      .clk  (clk),
      .reset(reset),
      .bus  (gamepak_ws2_bus)
  );

  GBA_Memory #(
      .START_ADDR(GAMEPAK_SRAM_start),
      .END_ADDR  (GAMEPAK_SRAM_end),
      .SIZE      (GAMEPAK_SRAM_len)
  ) GAMEPAK_SRAM (
      .clk  (clk),
      .reset(reset),
      .bus  (gamepak_sram_bus)
  );

endmodule : GameboyAdvance
