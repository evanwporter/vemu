import gb_mmu_addresses_pkg::*;

`include "gb/util/logger.svh"

/// MMU: Memory Mapper Unit
/// Orchestrates memory accesses between SM83, DMA, and peripherals
/// Notably it doesn't have any memory of its own.
module GB_MMU (
    GB_Bus_if.Slave_side cpu_bus,
    GB_DMA_if.MMU_side   dma_bus,

    GB_Bus_if.Master_side ppu_bus,
    GB_Bus_if.Master_side apu_bus,
    GB_Bus_if.Master_side cart_bus,
    GB_Bus_if.Master_side ram_bus,
    GB_Bus_if.Master_side hram_bus,
    GB_Bus_if.Master_side serial_bus,
    GB_Bus_if.Master_side timer_bus,
    GB_Bus_if.Master_side input_bus,
    GB_Bus_if.Master_side dma_wrbus,
    GB_Bus_if.Master_side interrupt_bus
);

  wire [15:0] effective_addr = dma_bus.active ? dma_bus.addr : cpu_bus.addr;

  wire cpu_req_read = cpu_bus.read_en && !dma_bus.active;
  wire cpu_req_write = cpu_bus.write_en && !dma_bus.active;

  wire dma_req_read = dma_bus.read_en && dma_bus.active;
  wire dma_req_write = dma_bus.write_en && dma_bus.active;

  assign ppu_bus.addr = effective_addr;
  assign apu_bus.addr = cpu_bus.addr;
  assign cart_bus.addr = effective_addr;
  assign ram_bus.addr = (effective_addr inside {[Echo_RAM_start : Echo_RAM_end]})
    ? (effective_addr - 16'h2000) // Map Echo RAM to WRAM
      : effective_addr;
  assign hram_bus.addr = cpu_bus.addr;
  assign serial_bus.addr = cpu_bus.addr;
  assign timer_bus.addr = cpu_bus.addr;
  assign input_bus.addr = cpu_bus.addr;
  assign interrupt_bus.addr = cpu_bus.addr;
  assign dma_wrbus.addr = cpu_bus.addr;

  assign ppu_bus.wdata = dma_bus.active ? dma_bus.wdata : cpu_bus.wdata;
  assign apu_bus.wdata = cpu_bus.wdata;
  assign cart_bus.wdata = cpu_bus.wdata;
  assign ram_bus.wdata = cpu_bus.wdata;
  assign hram_bus.wdata = cpu_bus.wdata;
  assign serial_bus.wdata = cpu_bus.wdata;
  assign timer_bus.wdata = cpu_bus.wdata;
  assign input_bus.wdata = cpu_bus.wdata;
  assign interrupt_bus.wdata = cpu_bus.wdata;
  assign dma_wrbus.wdata = cpu_bus.wdata;

  // PPU VRAM: $8000–$9FFF, OAM: $FE00–$FE9F, PPU I/O: $FF40–$FF4B
  wire ppu_selected = (effective_addr inside {[VRAM_start : VRAM_end]})  ||
                      (effective_addr inside {[OAM_start : OAM_end]})   ||
                      (effective_addr inside {[PPU_regs_start : PPU_regs_end]} 
                       & effective_addr != DMA_OAM_addr);
  assign ppu_bus.read_en  = cpu_req_read && ppu_selected;
  assign ppu_bus.write_en = (cpu_req_write || dma_req_write) && ppu_selected;

  // APU I/O: $FF10–$FF3F
  wire apu_selected = cpu_bus.addr inside {[AUDIO_addr_start : AUDIO_addr_end]};
  assign apu_bus.read_en  = cpu_req_read && apu_selected;
  assign apu_bus.write_en = cpu_req_write && apu_selected;

  // ROM: $0000–$7FFF, RAM: $A000–$BFFF
  wire cart_selected = (effective_addr inside {[ROM_start : ROM_end]}) ||
                       (effective_addr inside {[ERAM_start : ERAM_end]}) ||
                       (effective_addr == 16'hFF50);
  assign cart_bus.read_en  = (cpu_req_read || dma_req_read) && cart_selected;
  assign cart_bus.write_en = cpu_req_write && cart_selected;

  // RAM
  wire ram_selected = (effective_addr inside {[WRAM_start : Echo_RAM_end]});
  assign ram_bus.read_en  = (cpu_req_read || dma_req_read) && ram_selected;
  assign ram_bus.write_en = cpu_req_write && ram_selected;

  // HRAM
  wire hram_selected = (cpu_bus.addr inside {[HRAM_start : HRAM_end]});
  assign hram_bus.read_en  = cpu_bus.read_en && hram_selected;
  assign hram_bus.write_en = cpu_bus.write_en && hram_selected;

  // Serial
  wire serial_selected = cpu_bus.addr inside {[SERIAL_addr_start : SERIAL_addr_end]};
  assign serial_bus.read_en  = cpu_req_read && serial_selected;
  assign serial_bus.write_en = cpu_req_write && serial_selected;

  wire timer_selected = cpu_bus.addr inside {[TIMER_addr_start : TIMER_addr_end]};
  assign timer_bus.read_en  = cpu_req_read && timer_selected;
  assign timer_bus.write_en = cpu_req_write && timer_selected;

  wire unused_selected = (cpu_bus.addr inside {[Unusable_start : Unusable_end]});

  wire input_selected = (cpu_bus.addr == JOYPAD_addr_start);
  assign input_bus.read_en  = cpu_req_read && input_selected;
  assign input_bus.write_en = cpu_req_write && input_selected;

  wire interrupt_selected = (cpu_bus.addr == 16'hFF0F) || (cpu_bus.addr == 16'hFFFF);
  assign interrupt_bus.read_en  = cpu_bus.read_en && interrupt_selected;
  assign interrupt_bus.write_en = cpu_bus.write_en && interrupt_selected;

  // DMA
  wire DMA_selected = (cpu_bus.addr == DMA_OAM_addr);
  assign dma_wrbus.read_en  = cpu_bus.read_en && DMA_selected;
  assign dma_wrbus.write_en = cpu_bus.write_en && DMA_selected;

  // Map Read Data
  always_comb begin
    cpu_bus.rdata = 8'hFF;
    dma_bus.rdata = 8'hFF;

    if (dma_bus.active == 1'b1) begin
      if (DMA_selected) begin
        // DMA can read from DMA register
        cpu_bus.rdata = dma_wrbus.rdata;


      end else if (hram_selected) begin
        // When DMA is active, only HRAM can be accessed by the SM83
        cpu_bus.rdata = hram_bus.rdata;
      end

      if (ram_selected) begin
        // DMA can read from RAM
        dma_bus.rdata = ram_bus.rdata;
      end else if (cart_selected) begin
        // DMA can read from Cartridge
        dma_bus.rdata = cart_bus.rdata;
      end

      // DMA is not active
    end else begin
      if (ppu_selected) begin
        cpu_bus.rdata = ppu_bus.rdata;

      end else if (apu_selected) begin
        cpu_bus.rdata = apu_bus.rdata;

      end else if (cart_selected) begin
        cpu_bus.rdata = cart_bus.rdata;

      end else if (ram_selected) begin
        cpu_bus.rdata = ram_bus.rdata;

      end else if (hram_selected) begin
        cpu_bus.rdata = hram_bus.rdata;

      end else if (serial_selected) begin
        cpu_bus.rdata = serial_bus.rdata;

      end else if (timer_selected) begin
        cpu_bus.rdata = timer_bus.rdata;

      end else if (unused_selected) begin
        `LOG_WARN(("[MMU] READ operation performed in unused area (addr=%h)", effective_addr))
        cpu_bus.rdata = 8'hFF;

      end else if (input_selected) begin
        cpu_bus.rdata = input_bus.rdata;

      end else if (interrupt_selected) begin
        cpu_bus.rdata = interrupt_bus.rdata;

      end else if (DMA_selected) begin
        cpu_bus.rdata = dma_wrbus.rdata;

      end else begin
        `LOG_WARN(("[MMU] Unmapped READ addr=%h", effective_addr))
        cpu_bus.rdata = 8'hFF;
        // TODO
      end
    end
  end
endmodule
