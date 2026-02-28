`ifndef MMU_SV
`define MMU_SV 

import gba_types_pkg::*;

module MockMMU (
    input logic clk,
    input logic reset,

    GBA_Bus_if.Slave_side cpu_bus
);

  (* maybe_unused *)
  word_t memory[word_t]  /* verilator public_flat_rw */;

  (* maybe_unused *)
  word_t base_addr, opcode  /* verilator public_flat_rw */;

  always_comb begin
    cpu_bus.rdata = 32'd0;

    if (cpu_bus.addr == base_addr) begin
      cpu_bus.rdata = opcode;
      $display("[MMU] Providing opcode %0d for read at base address %0d", opcode, base_addr);
    end else if (cpu_bus.read_en) begin
      if (memory.exists(cpu_bus.addr)) begin
        cpu_bus.rdata = memory[cpu_bus.addr];
        $display("[MMU] Found match for read transaction at addr=%0d, data=%0d", cpu_bus.addr,
                 memory[cpu_bus.addr]);
        $fflush();
      end else begin
        cpu_bus.rdata = cpu_bus.addr;
        $display("[MMU] Providing data=%0d for read transaction at addr=%0d", cpu_bus.rdata,
                 cpu_bus.addr);
        $fflush();
      end
    end
  end

  always_ff @(posedge clk) begin
    if (reset) begin
    end else if (cpu_bus.write_en) begin
      if (memory.exists(cpu_bus.addr)) begin
        $display("[MMU] Overwriting memory at addr=%0d with data=%0d", cpu_bus.addr, cpu_bus.wdata);
      end else begin
        $display("[MMU] Writing data=%0d for write transaction at addr=%0d", cpu_bus.wdata,
                 cpu_bus.addr);
      end
      memory[cpu_bus.addr] = cpu_bus.wdata;
    end
  end
endmodule

`endif  // MMU_SV
