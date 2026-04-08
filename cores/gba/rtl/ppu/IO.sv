import gba_ppu_types_pkg::*;
import gba_mmu_addresses_pkg::*;
import gba_ppu_addresses_pkg::*;
import gba_util_pkg::*;

module GBA_PPU_IO_Regs (
    input clk,
    input reset,
    GBA_Bus_if.Slave_side bus
);

  ppu_regs_t regs;

  always_ff @(posedge clk) begin
    if (reset) begin
      regs.dispcnt  <= '0;
      regs.dispstat <= '0;
    end else if (bus.write_en) begin
      unique case (bus.addr)

        REG_DISPCNT: begin
          {regs.dispstat, regs.dispcnt} <= apply_write(
              {
                regs.dispstat, regs.dispcnt
              },
              bus.wdata,
              bus.transfer_size,
              bus.addr[1:0],
              {
                DISPSTAT_MASK, DISPCNT_MASK
              }
          );
        end

        REG_DISPSTAT: begin
          regs.dispstat <= 16'(apply_write(
              {
                regs.dispstat, regs.dispcnt
              },
              bus.wdata,
              bus.transfer_size,
              bus.addr[1:0],
              {
                16'd0, DISPSTAT_MASK
              }
          ));
        end

      endcase
    end
  end

  always_comb begin
    unique case (bus.addr)
      REG_DISPCNT:  bus.rdata = {regs.dispstat, regs.dispcnt};
      REG_DISPSTAT: bus.rdata = {16'd0, regs.dispstat};
      default:      bus.rdata = 32'h0;
    endcase
  end

endmodule
