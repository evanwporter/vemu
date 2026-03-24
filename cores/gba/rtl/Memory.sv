import gba_types_pkg::*;

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
      mem[index] <= bus.wdata[7:0];
    end
  end

  // Read
  always_comb begin
    bus.rdata = 32'hFFFFFFFF;
    if (bus.read_en && selected) begin
      bus.rdata = {24'h0, mem[index]};
    end
  end

endmodule
