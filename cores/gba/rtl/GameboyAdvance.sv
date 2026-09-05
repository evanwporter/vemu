`include "gba/util/logger.svh"

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
  GBA_Bus_if interrupt_bus ();
  GBA_Bus_if ppu_io_bus ();

  // Display memory
  GBA_Bus_if palette_bus ();
  GBA_Bus_if vram_bus ();
  GBA_Bus_if oam_bus ();

  // Game Pak (external)
  GBA_Bus_if gamepak_ws0_bus ();
  GBA_Bus_if gamepak_ws1_bus ();
  GBA_Bus_if gamepak_ws2_bus ();
  GBA_Bus_if gamepak_sram_bus ();

  GBA_Interrupt_if interrupt_req_bus ();

  // TODO: Replace these tie-offs as the corresponding peripherals acquire
  // interrupt outputs.
  assign interrupt_req_bus.vcounter_req = 1'b0;
  assign interrupt_req_bus.timer0_req = 1'b0;
  assign interrupt_req_bus.timer1_req = 1'b0;
  assign interrupt_req_bus.timer2_req = 1'b0;
  assign interrupt_req_bus.timer3_req = 1'b0;
  assign interrupt_req_bus.serial_req = 1'b0;
  assign interrupt_req_bus.dma0_req = 1'b0;
  assign interrupt_req_bus.dma1_req = 1'b0;
  assign interrupt_req_bus.dma2_req = 1'b0;
  assign interrupt_req_bus.dma3_req = 1'b0;
  assign interrupt_req_bus.keypad_req = 1'b0;
  assign interrupt_req_bus.gamepak_req = 1'b0;

  logic irq;

  GBA_InterruptHandler interrupt_controller (
      .clk(clk),
      .reset(reset),
      .interrupt_bus(interrupt_req_bus),
      .irq(irq),
      .bus(interrupt_bus)
  );

  ARM7TMDI cpu_inst (
      .clk(clk),
      .reset(reset),
      .irq(irq),
      .bus(cpu_bus),
      .interrupt_req_bus(interrupt_req_bus)
  );

  GBA_MMU mmu (
      .clk(clk),
      .cpu_bus(cpu_bus),
      .bios_bus(bios_bus),
      .wram_board_bus(wram_board_bus),
      .wram_chip_bus(wram_chip_bus),
      .io_bus(io_bus),
      .interrupt_bus(interrupt_bus),
      .ppu_io_bus(ppu_io_bus),
      .palette_bus(palette_bus),
      .vram_bus(vram_bus),
      .oam_bus(oam_bus),
      .gamepak_ws0_bus(gamepak_ws0_bus),
      .gamepak_ws1_bus(gamepak_ws1_bus),
      .gamepak_ws2_bus(gamepak_ws2_bus),
      .gamepak_sram_bus(gamepak_sram_bus)
  );

  GBA_PPU ppu (
      .clk(clk),
      .reset(reset),
      .vram_bus(vram_bus),
      .ppu_io_bus(ppu_io_bus),
      .interrupt_bus(interrupt_req_bus),
      .palette(Palette.mem)
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
