import gba_mmu_types_pkg::*;
import gba_types_pkg::*;

package gba_util_pkg;
  function automatic word_t apply_write(input word_t old, input word_t wdata,
                                        input bus_transfer_size_t size, input logic [1:0] addr_lsb,
                                        input word_t mask = 32'hFFFF_FFFF);
    word_t result = old;

    unique case (size)

      ARM_BUS_SIZE_BYTE: begin
        logic [6:0] shift = addr_lsb << 3;  // addr_lsb * 8
        result[shift+:8] = wdata[7:0];
      end

      ARM_BUS_SIZE_HALFWORD: begin
        logic [4:0] shift = addr_lsb[1] << 4;  // addr_lsb[1] * 16
        result[shift+:16] = wdata[15:0];
      end

      ARM_BUS_SIZE_WORD: begin
        result = wdata;
      end

    endcase

    return result;
  endfunction
endpackage : gba_util_pkg
