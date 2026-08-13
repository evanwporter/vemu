`include "gba/util/logger.svh"

import gba_types_pkg::*;
import gba_mmu_types_pkg::*;

module GBA_Memory #(
    parameter word_t START_ADDR = 32'h00000000,
    parameter word_t END_ADDR = 32'h00000000,
    parameter word_t SIZE = 100
) (
    input logic clk,
    input logic reset,
    GBA_Bus_if.Slave_side bus
);

  logic [7:0] mem[SIZE];

  // Address decode
  wire selected = (bus.addr - START_ADDR) <= (END_ADDR - START_ADDR);

  localparam int CLOG2 = $clog2(SIZE);

  // Address to index
  logic [CLOG2-1:0] index;

  assign index = CLOG2'(bus.addr - START_ADDR);

  // Write
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      // TODO
    end else if (bus.write_en && selected) begin
      `LOG_TRACE(("[Memory] Write to address %08X: %08X (index %0d), size:%0d", bus.addr, bus.wdata,
               index, bus.transfer_size))
      unique case (bus.transfer_size)
        ARM_BUS_SIZE_BYTE: begin
          mem[index] <= bus.wdata[7:0];
        end

        ARM_BUS_SIZE_HALFWORD: begin
          mem[index+0] <= bus.wdata[7:0];
          mem[index+1] <= bus.wdata[15:8];
        end

        ARM_BUS_SIZE_WORD: begin
          mem[index+0] <= bus.wdata[7:0];
          mem[index+1] <= bus.wdata[15:8];
          mem[index+2] <= bus.wdata[23:16];
          mem[index+3] <= bus.wdata[31:24];
        end
      endcase
    end
  end

  // Read
  always_comb begin
    bus.rdata = 32'hFFFF_FFFF;
    if (bus.read_en && selected) begin
      bus.rdata = {mem[index+3], mem[index+2], mem[index+1], mem[index+0]};
    end
  end

endmodule
