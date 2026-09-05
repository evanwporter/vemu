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
  GBA_Interrupt_if interrupt_req_bus ();
  logic irq;

  assign {
    interrupt_req_bus.gamepak_req,
    interrupt_req_bus.keypad_req,
    interrupt_req_bus.dma3_req,
    interrupt_req_bus.dma2_req,
    interrupt_req_bus.dma1_req,
    interrupt_req_bus.dma0_req,
    interrupt_req_bus.serial_req,
    interrupt_req_bus.timer3_req,
    interrupt_req_bus.timer2_req,
    interrupt_req_bus.timer1_req,
    interrupt_req_bus.timer0_req,
    interrupt_req_bus.vcounter_req,
    interrupt_req_bus.hblank_req,
    interrupt_req_bus.vblank_req
  } = interrupt_requests;

  assign interrupt_bus.addr = '0;
  assign interrupt_bus.wdata = '0;
  assign interrupt_bus.read_en = 1'b0;
  assign interrupt_bus.write_en = 1'b0;
  assign interrupt_bus.transfer_size = ARM_BUS_SIZE_BYTE;

  GBA_InterruptHandler interrupt_controller (
      .clk(clk),
      .reset(reset),
      .interrupt_bus(interrupt_req_bus),
      .irq(irq),
      .bus(interrupt_bus)
  );

  ARM7TMDI cpu_inst (
      .clk  (clk),
      .reset(reset),
      .irq  (irq),
      .bus  (bus),
      .interrupt_req_bus(interrupt_req_bus)
  );

  MockMMU mmu_inst (
      .clk(clk),
      .reset(reset),
      .cpu_bus(bus)
  );

endmodule

`endif  // GAMEBOY_SV
