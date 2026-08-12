import gba_mmu_addresses_pkg::*;
import gba_mmu_types_pkg::*;
import gba_ppu_types_pkg::*;

module GBA_PPU (
    input logic clk,
    input logic reset,
    GBA_Bus_if.Slave_side vram_bus,
    GBA_Bus_if.Slave_side ppu_io_bus
);

  ppu_regs_t regs;

  GBA_Memory #(
      .START_ADDR(VRAM_start),
      .END_ADDR  (VRAM_end),
      .SIZE      (VRAM_len)
  ) VRAM (
      .clk  (clk),
      .reset(reset),
      .bus  (vram_bus)
  );

  int unsigned io_index;
  assign io_index = ppu_io_bus.addr - PPU_IO_start;

  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      regs <= '0;
    end else if (ppu_io_bus.write_en) begin
      unique case (ppu_io_bus.transfer_size)
        ARM_BUS_SIZE_BYTE: write_io_byte(io_index, ppu_io_bus.wdata[7:0]);
        ARM_BUS_SIZE_HALFWORD: begin
          write_io_byte(io_index, ppu_io_bus.wdata[7:0]);
          write_io_byte(io_index + 1, ppu_io_bus.wdata[15:8]);
        end
        ARM_BUS_SIZE_WORD: begin
          write_io_byte(io_index, ppu_io_bus.wdata[7:0]);
          write_io_byte(io_index + 1, ppu_io_bus.wdata[15:8]);
          write_io_byte(io_index + 2, ppu_io_bus.wdata[23:16]);
          write_io_byte(io_index + 3, ppu_io_bus.wdata[31:24]);
        end
      endcase
    end
  end

  task automatic write_io_byte(input int unsigned index, input logic [7:0] value);
    if (index < PPU_IO_len) begin
      unique case (index)
        // DISPCNT bit 3 is writable only by BIOS opcodes.
        0: regs[index*8+:8] <= {value[7:4], regs[index*8+3], value[2:0]};

        // DISPSTAT bits 0-2 are status; bits 6-7 are unused on GBA.
        4: regs[index*8+:8] <= {regs[index*8+6+:2], value[5:3], regs[index*8+:3]};

        // VCOUNT is read-only.
        6, 7: ;
        1, 2, 3, 5: regs[index*8+:8] <= value;
      endcase
    end
  endtask

  always_comb begin
    ppu_io_bus.rdata = 32'hFFFF_FFFF;
    if (ppu_io_bus.read_en) begin
      ppu_io_bus.rdata[7:0]   = io_index < PPU_IO_len ? regs[io_index*8+:8] : 8'hFF;
      ppu_io_bus.rdata[15:8]  = io_index + 1 < PPU_IO_len ? regs[(io_index+1)*8+:8] : 8'hFF;
      ppu_io_bus.rdata[23:16] = io_index + 2 < PPU_IO_len ? regs[(io_index+2)*8+:8] : 8'hFF;
      ppu_io_bus.rdata[31:24] = io_index + 3 < PPU_IO_len ? regs[(io_index+3)*8+:8] : 8'hFF;
    end
  end

endmodule : GBA_PPU
