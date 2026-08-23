`ifndef GAMEBOY_SV
`define GAMEBOY_SV 

`define LOG_LEVEL_WARN 

// `include "ARM7/CPU.sv"

`include "MockMMU.sv"

module arm_cpu_top (
    input logic clk,
    input logic reset,
    input logic [13:0] interrupt_requests
);

  GBA_Bus_if bus ();
  GBA_Bus_if interrupt_bus ();
  logic irq;

  assign interrupt_bus.addr = '0;
  assign interrupt_bus.wdata = '0;
  assign interrupt_bus.read_en = 1'b0;
  assign interrupt_bus.write_en = 1'b0;
  assign interrupt_bus.transfer_size = ARM_BUS_SIZE_BYTE;

  GBA_InterruptHandler interrupt_controller (
      .clk(clk),
      .reset(reset),
      .interrupt_requests(interrupt_requests),
      .irq(irq),
      .bus(interrupt_bus)
  );

  ARM7TMDI cpu_inst (
      .clk  (clk),
      .reset(reset),
      .irq  (irq),
      .bus  (bus)
  );

  MockMMU mmu_inst (
      .clk(clk),
      .reset(reset),
      .cpu_bus(bus)
  );

endmodule

`endif  // GAMEBOY_SV
