import gba_ppu_types_pkg::*;
import gba_mmu_addresses_pkg::*;
import gba_ppu_addresses_pkg::*;
import gba_util_pkg::*;

module PPU (
    input wire clk,
    input wire reset,

    GBA_Bus_if.Slave_side ppu_bus
);

  ppu_regs_t ppu_regs;

  // Display memory
  GBA_Bus_if palette_bus ();
  GBA_Bus_if vram_bus ();
  GBA_Bus_if oam_bus ();

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

  assign palette_bus.addr = ppu_bus.addr;
  assign vram_bus.addr = ppu_bus.addr;
  assign oam_bus.addr = ppu_bus.addr;

  assign palette_bus.wdata = ppu_bus.wdata;
  assign vram_bus.wdata = ppu_bus.wdata;
  assign oam_bus.wdata = ppu_bus.wdata;

  wire ppu_regs_selected = ppu_bus.addr inside {[PPU_IO_regs_start : PPU_IO_regs_end]};

  wire palette_selected = ppu_bus.addr inside {[Palette_start : Palette_end]};
  assign palette_bus.read_en  = ppu_bus.read_en && palette_selected;
  assign palette_bus.write_en = ppu_bus.write_en && palette_selected;

  wire vram_selected = ppu_bus.addr inside {[VRAM_start : VRAM_end]};
  assign vram_bus.read_en  = ppu_bus.read_en && vram_selected;
  assign vram_bus.write_en = ppu_bus.write_en && vram_selected;

  wire oam_selected = ppu_bus.addr inside {[OAM_start : OAM_end]};
  assign oam_bus.read_en  = ppu_bus.read_en && oam_selected;
  assign oam_bus.write_en = ppu_bus.write_en && oam_selected;

  always_comb begin
    if (ppu_regs_selected) begin
      case (ppu_bus.addr)
        REG_DISPCNT: ppu_bus.rdata = {ppu_regs.dispstat, ppu_regs.dispcnt};
        REG_DISPSTAT: ppu_bus.rdata = {16'd0, ppu_regs.dispstat};
        default: ppu_bus.rdata = 32'h00000000;  // Unmapped registers return 0
      endcase
    end else if (palette_selected) begin
      ppu_bus.rdata = palette_bus.rdata;
    end else if (vram_selected) begin
      ppu_bus.rdata = vram_bus.rdata;
    end else if (oam_selected) begin
      ppu_bus.rdata = oam_bus.rdata;
    end else begin
      ppu_bus.rdata = 32'h00000000;  // Unmapped addresses return 0
    end
  end

  always_ff @(posedge clk) begin
    if (reset) begin
      ppu_regs.dispcnt  <= '0;
      ppu_regs.dispstat <= '0;
    end else if (ppu_bus.write_en) begin
      if (ppu_regs_selected) begin
        case (ppu_bus.addr)
          REG_DISPCNT: begin
            {ppu_regs.dispstat, ppu_regs.dispcnt} <= apply_write(
                {
                  ppu_regs.dispstat, ppu_regs.dispcnt
                },
                ppu_bus.wdata,
                ppu_bus.transfer_size,
                ppu_bus.addr[1:0]
            );
          end
          REG_DISPSTAT: ppu_regs.dispstat <= ppu_bus.wdata;
          default: ;
          // Ignore writes to unmapped registers
        endcase
      end
    end
  end

endmodule : PPU
