`include "gba/util/logger.svh"

import gba_types_pkg::*;
import gba_mmu_types_pkg::*;
import gba_mmu_addresses_pkg::*;

module GBA_MMU (
    input logic clk,  // only used for logging purposes, the MMU itself is purely combinational
    GBA_Bus_if.Slave_side cpu_bus,

    GBA_Bus_if.Master_side bios_bus,
    GBA_Bus_if.Master_side wram_board_bus,
    GBA_Bus_if.Master_side wram_chip_bus,
    GBA_Bus_if.Master_side io_bus,
    GBA_Bus_if.Master_side interrupt_bus,
    GBA_Bus_if.Master_side ppu_io_bus,

    GBA_Bus_if.Master_side palette_bus,
    GBA_Bus_if.Master_side vram_bus,
    GBA_Bus_if.Master_side oam_bus,

    GBA_Bus_if.Master_side gamepak_ws0_bus,
    GBA_Bus_if.Master_side gamepak_ws1_bus,
    GBA_Bus_if.Master_side gamepak_ws2_bus,
    GBA_Bus_if.Master_side gamepak_sram_bus
);

  word_t effective_addr;

  always_comb begin
    effective_addr = cpu_bus.addr;
    unique case (cpu_bus.transfer_size)
      ARM_BUS_SIZE_BYTE: effective_addr = cpu_bus.addr;
      ARM_BUS_SIZE_HALFWORD: effective_addr = {cpu_bus.addr[31:1], 1'b0};
      ARM_BUS_SIZE_WORD: effective_addr = {cpu_bus.addr[31:2], 2'b0};
    endcase
  end

  assign bios_bus.addr = effective_addr;
  assign wram_board_bus.addr = effective_addr;
  assign wram_chip_bus.addr = effective_addr;
  assign io_bus.addr = effective_addr;
  assign interrupt_bus.addr = effective_addr;
  assign ppu_io_bus.addr = effective_addr;
  assign palette_bus.addr = effective_addr;
  assign vram_bus.addr = effective_addr;
  assign oam_bus.addr = effective_addr;
  assign gamepak_ws0_bus.addr = effective_addr;
  assign gamepak_ws1_bus.addr = effective_addr;
  assign gamepak_ws2_bus.addr = effective_addr;
  assign gamepak_sram_bus.addr = effective_addr;

  assign bios_bus.wdata = cpu_bus.wdata;
  assign wram_board_bus.wdata = cpu_bus.wdata;
  assign wram_chip_bus.wdata = cpu_bus.wdata;
  assign io_bus.wdata = cpu_bus.wdata;
  assign interrupt_bus.wdata = cpu_bus.wdata;
  assign ppu_io_bus.wdata = cpu_bus.wdata;
  assign palette_bus.wdata = cpu_bus.wdata;
  assign vram_bus.wdata = cpu_bus.wdata;
  assign oam_bus.wdata = cpu_bus.wdata;
  assign gamepak_ws0_bus.wdata = cpu_bus.wdata;
  assign gamepak_ws1_bus.wdata = cpu_bus.wdata;
  assign gamepak_ws2_bus.wdata = cpu_bus.wdata;
  assign gamepak_sram_bus.wdata = cpu_bus.wdata;

  assign bios_bus.transfer_size = cpu_bus.transfer_size;
  assign wram_board_bus.transfer_size = cpu_bus.transfer_size;
  assign wram_chip_bus.transfer_size = cpu_bus.transfer_size;
  assign io_bus.transfer_size = cpu_bus.transfer_size;
  assign interrupt_bus.transfer_size = cpu_bus.transfer_size;
  assign ppu_io_bus.transfer_size = cpu_bus.transfer_size;
  assign palette_bus.transfer_size = cpu_bus.transfer_size;
  assign vram_bus.transfer_size = cpu_bus.transfer_size;
  assign oam_bus.transfer_size = cpu_bus.transfer_size;
  assign gamepak_ws0_bus.transfer_size = cpu_bus.transfer_size;
  assign gamepak_ws1_bus.transfer_size = cpu_bus.transfer_size;
  assign gamepak_ws2_bus.transfer_size = cpu_bus.transfer_size;
  assign gamepak_sram_bus.transfer_size = cpu_bus.transfer_size;

  wire bios_selected = effective_addr inside {[BIOS_start : BIOS_end]};
  assign bios_bus.read_en  = cpu_bus.read_en && bios_selected;
  assign bios_bus.write_en = cpu_bus.write_en && bios_selected;

  wire wram_board_selected = effective_addr inside {[WRAM_board_start : WRAM_board_end]};
  assign wram_board_bus.read_en  = cpu_bus.read_en && wram_board_selected;
  assign wram_board_bus.write_en = cpu_bus.write_en && wram_board_selected;

  wire wram_chip_selected = effective_addr inside {[WRAM_chip_start : WRAM_chip_end]};
  assign wram_chip_bus.read_en  = cpu_bus.read_en && wram_chip_selected;
  assign wram_chip_bus.write_en = cpu_bus.write_en && wram_chip_selected;

  wire ppu_io_selected = effective_addr inside {[PPU_IO_start : PPU_IO_end]};
  assign ppu_io_bus.read_en  = cpu_bus.read_en && ppu_io_selected;
  assign ppu_io_bus.write_en = cpu_bus.write_en && ppu_io_selected;

  wire interrupt_selected = effective_addr inside {[32'h0400_0200 : 32'h0400_0203]} ||
                            effective_addr inside {[32'h0400_0208 : 32'h0400_020B]};
  assign interrupt_bus.read_en  = cpu_bus.read_en && interrupt_selected;
  assign interrupt_bus.write_en = cpu_bus.write_en && interrupt_selected;

  wire io_selected = effective_addr inside {[IO_start : IO_end]} &&
                     !ppu_io_selected && !interrupt_selected;
  assign io_bus.read_en  = cpu_bus.read_en && io_selected;
  assign io_bus.write_en = cpu_bus.write_en && io_selected;

  wire palette_selected = effective_addr inside {[Palette_start : Palette_end]};
  assign palette_bus.read_en  = cpu_bus.read_en && palette_selected;
  assign palette_bus.write_en = cpu_bus.write_en && palette_selected;

  wire vram_selected = effective_addr inside {[VRAM_start : VRAM_end]};
  assign vram_bus.read_en  = cpu_bus.read_en && vram_selected;
  assign vram_bus.write_en = cpu_bus.write_en && vram_selected;

  wire oam_selected = effective_addr inside {[OAM_start : OAM_end]};
  assign oam_bus.read_en  = cpu_bus.read_en && oam_selected;
  assign oam_bus.write_en = cpu_bus.write_en && oam_selected;

  wire gamepak_ws0_selected = effective_addr inside {[GAMEPAK_WS0_start : GAMEPAK_WS0_end]};
  assign gamepak_ws0_bus.read_en  = cpu_bus.read_en && gamepak_ws0_selected;
  assign gamepak_ws0_bus.write_en = cpu_bus.write_en && gamepak_ws0_selected;

  wire gamepak_ws1_selected = effective_addr inside {[GAMEPAK_WS1_start : GAMEPAK_WS1_end]};
  assign gamepak_ws1_bus.read_en  = cpu_bus.read_en && gamepak_ws1_selected;
  assign gamepak_ws1_bus.write_en = cpu_bus.write_en && gamepak_ws1_selected;

  wire gamepak_ws2_selected = effective_addr inside {[GAMEPAK_WS2_start : GAMEPAK_WS2_end]};
  assign gamepak_ws2_bus.read_en  = cpu_bus.read_en && gamepak_ws2_selected;
  assign gamepak_ws2_bus.write_en = cpu_bus.write_en && gamepak_ws2_selected;

  wire gamepak_sram_selected = effective_addr inside {[GAMEPAK_SRAM_start : GAMEPAK_SRAM_end]};
  assign gamepak_sram_bus.read_en  = cpu_bus.read_en && gamepak_sram_selected;
  assign gamepak_sram_bus.write_en = cpu_bus.write_en && gamepak_sram_selected;

  always_comb begin
    if (bios_selected) begin
      cpu_bus.rdata = bios_bus.rdata;

    end else if (wram_board_selected) begin
      cpu_bus.rdata = wram_board_bus.rdata;

    end else if (wram_chip_selected) begin
      cpu_bus.rdata = wram_chip_bus.rdata;

    end else if (ppu_io_selected) begin
      cpu_bus.rdata = ppu_io_bus.rdata;

    end else if (io_selected) begin
      cpu_bus.rdata = io_bus.rdata;

    end else if (interrupt_selected) begin
      cpu_bus.rdata = interrupt_bus.rdata;

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
      // $warning("Read from unmapped address: %h", effective_addr);
      cpu_bus.rdata = 32'hFF;
    end
  end

  always_ff @(posedge clk) begin
    // READ LOGS
    if (cpu_bus.read_en) begin
      if (bios_selected)
        `LOG_TRACE(("[MMU][READ ] BIOS        addr=%h data=%h", effective_addr, bios_bus.rdata))

      else if (wram_board_selected)
        `LOG_TRACE(
            ("[MMU][READ ] WRAM_BOARD  addr=%h data=%h", effective_addr, wram_board_bus.rdata))

      else if (wram_chip_selected)
        `LOG_TRACE(
            ("[MMU][READ ] WRAM_CHIP   addr=%h data=%h", effective_addr, wram_chip_bus.rdata))

      else if (ppu_io_selected)
        `LOG_TRACE(("[MMU][READ ] PPU_IO      addr=%h data=%h", effective_addr, ppu_io_bus.rdata))

      else if (io_selected)
        `LOG_TRACE(("[MMU][READ ] GENERIC_IO  addr=%h data=%h", effective_addr, io_bus.rdata))

      else if (palette_selected)
        `LOG_TRACE(("[MMU][READ ] PALETTE     addr=%h data=%h", effective_addr, palette_bus.rdata))

      else if (vram_selected)
        `LOG_TRACE(("[MMU][READ ] VRAM        addr=%h data=%h", effective_addr, vram_bus.rdata))

      else if (oam_selected)
        `LOG_TRACE(("[MMU][READ ] OAM         addr=%h data=%h", effective_addr, oam_bus.rdata))

      else if (gamepak_ws0_selected)
        `LOG_TRACE(
            ("[MMU][READ ] GAMEPAK_WS0 addr=%h data=%h", effective_addr, gamepak_ws0_bus.rdata))

      else if (gamepak_ws1_selected)
        `LOG_TRACE(
            ("[MMU][READ ] GAMEPAK_WS1 addr=%h data=%h", effective_addr, gamepak_ws1_bus.rdata))

      else if (gamepak_ws2_selected)
        `LOG_TRACE(
            ("[MMU][READ ] GAMEPAK_WS2 addr=%h data=%h", effective_addr, gamepak_ws2_bus.rdata))

      else if (gamepak_sram_selected)
        `LOG_TRACE(
            ("[MMU][READ ] SRAM        addr=%h data=%h", effective_addr, gamepak_sram_bus.rdata))

      else `LOG_TRACE(("[MMU][READ ] UNKNOWN     addr=%h data=%h", effective_addr, cpu_bus.rdata))
    end

    // WRITE LOGS
    if (cpu_bus.write_en) begin
      if (bios_selected)
        `LOG_TRACE(("[MMU][WRITE] BIOS        addr=%h data=%h", effective_addr, cpu_bus.wdata))

      else if (wram_board_selected)
        `LOG_TRACE(("[MMU][WRITE] WRAM_BOARD  addr=%h data=%h", effective_addr, cpu_bus.wdata))

      else if (wram_chip_selected)
        `LOG_TRACE(("[MMU][WRITE] WRAM_CHIP   addr=%h data=%h", effective_addr, cpu_bus.wdata))

      else if (ppu_io_selected)
        `LOG_TRACE(("[MMU][WRITE] PPU_IO      addr=%h data=%h", effective_addr, cpu_bus.wdata))

      else if (io_selected)
        `LOG_TRACE(("[MMU][WRITE] GENERIC_IO  addr=%h data=%h", effective_addr, cpu_bus.wdata))

      else if (palette_selected)
        `LOG_TRACE(("[MMU][WRITE] PALETTE     addr=%h data=%h", effective_addr, cpu_bus.wdata))

      else if (vram_selected)
        `LOG_TRACE(("[MMU][WRITE] VRAM        addr=%h data=%h", effective_addr, cpu_bus.wdata))

      else if (oam_selected)
        `LOG_TRACE(("[MMU][WRITE] OAM         addr=%h data=%h", effective_addr, cpu_bus.wdata))

      else if (gamepak_ws0_selected)
        `LOG_TRACE(("[MMU][WRITE] GAMEPAK_WS0 addr=%h data=%h", effective_addr, cpu_bus.wdata))

      else if (gamepak_ws1_selected)
        `LOG_TRACE(("[MMU][WRITE] GAMEPAK_WS1 addr=%h data=%h", effective_addr, cpu_bus.wdata))

      else if (gamepak_ws2_selected)
        `LOG_TRACE(("[MMU][WRITE] GAMEPAK_WS2 addr=%h data=%h", effective_addr, cpu_bus.wdata))

      else if (gamepak_sram_selected)
        `LOG_TRACE(("[MMU][WRITE] SRAM        addr=%h data=%h", effective_addr, cpu_bus.wdata))

      else `LOG_TRACE(("[MMU][WRITE] UNKNOWN     addr=%h data=%h", effective_addr, cpu_bus.wdata))
    end
  end

endmodule : GBA_MMU
