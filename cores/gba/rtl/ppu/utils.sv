package gba_ppu_utils_pkg;

  function automatic [15:0] apply_write16(input [15:0] old, input [31:0] wdata, input [3:0] wstrb,
                                          input int byte_offset);
    logic [15:0] result = old;

    if (wstrb[byte_offset]) result[7:0] = wdata[8*byte_offset+:8];

    if (wstrb[byte_offset+1]) result[15:8] = wdata[8*(byte_offset+1)+:8];

    return result;
  endfunction
endpackage : gba_ppu_utils_pkg
