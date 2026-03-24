import gba_mmu_addresses_pkg::*;

module GBA_MMU (
    GBA_Bus_if.Slave_side cpu_bus,

    GBA_Bus_if.Master_side bios_bus,
    GBA_Bus_if.Master_side wram_board_bus,
    GBA_Bus_if.Master_side wram_chip_bus,
    GBA_Bus_if.Master_side io_bus,

    GBA_Bus_if.Master_side palette_bus,
    GBA_Bus_if.Master_side vram_bus,
    GBA_Bus_if.Master_side oam_bus,

    GBA_Bus_if.Master_side gamepak_ws0_bus,
    GBA_Bus_if.Master_side gamepak_ws1_bus,
    GBA_Bus_if.Master_side gamepak_ws2_bus,
    GBA_Bus_if.Master_side gamepak_sram_bus
);

  assign bios_bus.addr = cpu_bus.addr;
  assign wram_board_bus.addr = cpu_bus.addr;
  assign wram_chip_bus.addr = cpu_bus.addr;
  assign io_bus.addr = cpu_bus.addr;
  assign palette_bus.addr = cpu_bus.addr;
  assign vram_bus.addr = cpu_bus.addr;
  assign oam_bus.addr = cpu_bus.addr;
  assign gamepak_ws0_bus.addr = cpu_bus.addr;
  assign gamepak_ws1_bus.addr = cpu_bus.addr;
  assign gamepak_ws2_bus.addr = cpu_bus.addr;
  assign gamepak_sram_bus.addr = cpu_bus.addr;

  assign bios_bus.wdata = cpu_bus.wdata;
  assign wram_board_bus.wdata = cpu_bus.wdata;
  assign wram_chip_bus.wdata = cpu_bus.wdata;
  assign io_bus.wdata = cpu_bus.wdata;
  assign palette_bus.wdata = cpu_bus.wdata;
  assign vram_bus.wdata = cpu_bus.wdata;
  assign oam_bus.wdata = cpu_bus.wdata;
  assign gamepak_ws0_bus.wdata = cpu_bus.wdata;
  assign gamepak_ws1_bus.wdata = cpu_bus.wdata;
  assign gamepak_ws2_bus.wdata = cpu_bus.wdata;
  assign gamepak_sram_bus.wdata = cpu_bus.wdata;

  wire bios_selected = cpu_bus.addr inside {[BIOS_start : BIOS_end]};
  assign bios_bus.read_en  = cpu_bus.read_en && bios_selected;
  assign bios_bus.write_en = cpu_bus.write_en && bios_selected;

  wire wram_board_selected = cpu_bus.addr inside {[WRAM_board_start : WRAM_board_end]};
  assign wram_board_bus.read_en  = cpu_bus.read_en && wram_board_selected;
  assign wram_board_bus.write_en = cpu_bus.write_en && wram_board_selected;

  wire wram_chip_selected = cpu_bus.addr inside {[WRAM_chip_start : WRAM_chip_end]};
  assign wram_chip_bus.read_en  = cpu_bus.read_en && wram_chip_selected;
  assign wram_chip_bus.write_en = cpu_bus.write_en && wram_chip_selected;

  wire io_selected = cpu_bus.addr inside {[IO_start : IO_end]};
  assign io_bus.read_en  = cpu_bus.read_en && io_selected;
  assign io_bus.write_en = cpu_bus.write_en && io_selected;

  wire palette_selected = cpu_bus.addr inside {[Palette_start : Palette_end]};
  assign palette_bus.read_en  = cpu_bus.read_en && palette_selected;
  assign palette_bus.write_en = cpu_bus.write_en && palette_selected;

  wire vram_selected = cpu_bus.addr inside {[VRAM_start : VRAM_end]};
  assign vram_bus.read_en  = cpu_bus.read_en && vram_selected;
  assign vram_bus.write_en = cpu_bus.write_en && vram_selected;

  wire oam_selected = cpu_bus.addr inside {[OAM_start : OAM_end]};
  assign oam_bus.read_en  = cpu_bus.read_en && oam_selected;
  assign oam_bus.write_en = cpu_bus.write_en && oam_selected;

  wire gamepak_ws0_selected = cpu_bus.addr inside {[GAMEPAK_WS0_start : GAMEPAK_WS0_end]};
  assign gamepak_ws0_bus.read_en  = cpu_bus.read_en && gamepak_ws0_selected;
  assign gamepak_ws0_bus.write_en = cpu_bus.write_en && gamepak_ws0_selected;

  wire gamepak_ws1_selected = cpu_bus.addr inside {[GAMEPAK_WS1_start : GAMEPAK_WS1_end]};
  assign gamepak_ws1_bus.read_en  = cpu_bus.read_en && gamepak_ws1_selected;
  assign gamepak_ws1_bus.write_en = cpu_bus.write_en && gamepak_ws1_selected;

  wire gamepak_ws2_selected = cpu_bus.addr inside {[GAMEPAK_WS2_start : GAMEPAK_WS2_end]};
  assign gamepak_ws2_bus.read_en  = cpu_bus.read_en && gamepak_ws2_selected;
  assign gamepak_ws2_bus.write_en = cpu_bus.write_en && gamepak_ws2_selected;

  wire gamepak_sram_selected = cpu_bus.addr inside {[GAMEPAK_SRAM_start : GAMEPAK_SRAM_end]};
  assign gamepak_sram_bus.read_en  = cpu_bus.read_en && gamepak_sram_selected;
  assign gamepak_sram_bus.write_en = cpu_bus.write_en && gamepak_sram_selected;

  always_comb begin
    if (bios_selected) begin
      cpu_bus.rdata = bios_bus.rdata;

    end else if (wram_board_selected) begin
      cpu_bus.rdata = wram_board_bus.rdata;

    end else if (wram_chip_selected) begin
      cpu_bus.rdata = wram_chip_bus.rdata;

    end else if (io_selected) begin
      cpu_bus.rdata = io_bus.rdata;

    end else if (palette_selected) begin
      cpu_bus.rdata = palette_bus.rdata;

    end else if (vram_selected) begin
      cpu_bus.rdata = vram_bus.rdata;

    end else if (oam_selected) begin
      cpu_bus.rdata = oam_bus.rdata;

    end else if (gamepak_ws0_selected) begin
      cpu_bus.rdata = gamepak_ws0_bus.rdata;

    end else if (gamepak_ws1_selected) begin
      cpu_bus.rdata = gamepak_ws1_bus.rdata;

    end else if (gamepak_ws2_selected) begin
      cpu_bus.rdata = gamepak_ws2_bus.rdata;

    end else if (gamepak_sram_selected) begin
      cpu_bus.rdata = gamepak_sram_bus.rdata;

    end else begin
      $warning("Read from unmapped address: %h", cpu_bus.addr);
      cpu_bus.rdata = 32'hFF;
    end
  end

endmodule : GBA_MMU
