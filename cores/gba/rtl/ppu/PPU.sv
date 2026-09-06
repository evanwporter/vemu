import gba_mmu_addresses_pkg::*;
import gba_types_pkg::*;
import gba_mmu_types_pkg::*;
import gba_ppu_types_pkg::*;

module GBA_PPU (
    input logic clk,
    input logic reset,
    GBA_Bus_if.Slave_side vram_bus,
    GBA_Bus_if.Slave_side ppu_io_bus,
    GBA_Interrupt_if.PPU_side interrupt_bus,
    input logic [7:0] palette[Palette_len]
);

  // Keep the bus-facing register bytes in hardware address order. `regs` is
  // the decoded, background-grouped view used by the renderer.
  logic [PPU_IO_len*8-1:0] regs_raw;
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
      regs_raw <= '0;
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
      case (index)
        // DISPCNT bit 3 is writable only by BIOS opcodes.
        0: regs_raw[index*8+:8] <= {value[7:4], regs_raw[index*8+3], value[2:0]};

        // DISPSTAT bits 0-2 are status; bits 6-7 are unused on GBA.
        4: regs_raw[index*8+:8] <= {regs_raw[index*8+6+:2], value[5:3], regs_raw[index*8+:3]};

        // VCOUNT is read-only.
        6, 7: ;
        1, 2, 3, 5: regs_raw[index*8+:8] <= value;

        // The rest of the LCD register file is currently stored without
        // register-specific masking. Valid writes must not trip the unique
        // case assertion merely because their behavior is not modeled yet.
        default: regs_raw[index*8+:8] <= value;
      endcase
    end
  endtask

  always_comb begin
    ppu_io_bus.rdata = 32'hFFFF_FFFF;
    if (ppu_io_bus.read_en) begin
      ppu_io_bus.rdata[7:0]   = io_index < PPU_IO_len ? regs_raw[io_index*8+:8] : 8'hFF;
      ppu_io_bus.rdata[15:8]  = io_index + 1 < PPU_IO_len ? regs_raw[(io_index+1)*8+:8] : 8'hFF;
      ppu_io_bus.rdata[23:16] = io_index + 2 < PPU_IO_len ? regs_raw[(io_index+2)*8+:8] : 8'hFF;
      ppu_io_bus.rdata[31:24] = io_index + 3 < PPU_IO_len ? regs_raw[(io_index+3)*8+:8] : 8'hFF;
    end
  end

  always_comb begin
    regs                             = '0;

    regs.display.dispcnt             = regs_raw[16'h00*8+:16];
    regs.display.reserved_02_03      = regs_raw[16'h02*8+:16];
    regs.display.dispstat            = regs_raw[16'h04*8+:16];
    regs.display.vcount              = regs_raw[16'h06*8+:16];

    regs.background.bg0.control      = regs_raw[16'h08*8+:16];
    regs.background.bg1.control      = regs_raw[16'h0A*8+:16];
    regs.background.bg2.text.control = regs_raw[16'h0C*8+:16];
    regs.background.bg3.text.control = regs_raw[16'h0E*8+:16];
    regs.background.bg0.hofs         = regs_raw[16'h10*8+:16];
    regs.background.bg0.vofs         = regs_raw[16'h12*8+:16];
    regs.background.bg1.hofs         = regs_raw[16'h14*8+:16];
    regs.background.bg1.vofs         = regs_raw[16'h16*8+:16];
    regs.background.bg2.text.hofs    = regs_raw[16'h18*8+:16];
    regs.background.bg2.text.vofs    = regs_raw[16'h1A*8+:16];
    regs.background.bg3.text.hofs    = regs_raw[16'h1C*8+:16];
    regs.background.bg3.text.vofs    = regs_raw[16'h1E*8+:16];
    regs.background.bg2.pa           = regs_raw[16'h20*8+:16];
    regs.background.bg2.pb           = regs_raw[16'h22*8+:16];
    regs.background.bg2.pc           = regs_raw[16'h24*8+:16];
    regs.background.bg2.pd           = regs_raw[16'h26*8+:16];
    regs.background.bg2.x            = regs_raw[16'h28*8+:32];
    regs.background.bg2.y            = regs_raw[16'h2C*8+:32];
    regs.background.bg3.pa           = regs_raw[16'h30*8+:16];
    regs.background.bg3.pb           = regs_raw[16'h32*8+:16];
    regs.background.bg3.pc           = regs_raw[16'h34*8+:16];
    regs.background.bg3.pd           = regs_raw[16'h36*8+:16];
    regs.background.bg3.x            = regs_raw[16'h38*8+:32];
    regs.background.bg3.y            = regs_raw[16'h3C*8+:32];

    regs.win0h                       = regs_raw[16'h40*8+:16];
    regs.win1h                       = regs_raw[16'h42*8+:16];
    regs.win0v                       = regs_raw[16'h44*8+:16];
    regs.win1v                       = regs_raw[16'h46*8+:16];
    regs.winin                       = regs_raw[16'h48*8+:16];
    regs.winout                      = regs_raw[16'h4A*8+:16];
    regs.mosaic                      = regs_raw[16'h4C*8+:32];
    regs.bldcnt                      = regs_raw[16'h50*8+:16];
    regs.bldalpha                    = regs_raw[16'h52*8+:16];
    regs.bldy                        = regs_raw[16'h54*8+:32];
  end

  /// Vertical Scan Coordinate. Iterates from 0 to 227.
  logic [8:0] scan_y;

  /// Horizontal Scan Coordinate. Iterates from 0 to 307.
  logic [8:0] scan_x;

  /// There are 4 cycles per pixel pushed to the framebuffer
  logic [1:0] cycle;

  //-------------------------------
  // Scanline Increment
  //-------------------------------
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      scan_y <= 0;
      scan_x <= 0;
    end else begin
      if (cycle == 3) begin
        if (scan_y == 227 && scan_x == 307) begin
          scan_y <= 0;
          scan_x <= 0;
        end else if (scan_x == 307) begin
          scan_y <= scan_y + 1;
          scan_x <= 0;
        end else begin
          scan_x <= scan_x + 1;
        end
      end
    end
  end

  //-------------------------------
  // Cycle Increment
  //-------------------------------
  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      cycle <= 0;
    end else begin
      cycle <= cycle + 1;
    end
  end


  //-------------------------------
  // Interrupt Logic
  //-------------------------------
  assign interrupt_bus.vblank_req = (scan_y == 160 && scan_x == 0 && cycle == 0);
  assign interrupt_bus.hblank_req = (scan_x == 240 && cycle == 0);


  //-------------------------------
  // Mode 0
  //-------------------------------
  pixel_t bg_line[4][240];
  pixel_t bg_pixel[4];
  logic [15:0] bg_tile_map_address_value[4];
  logic [7:0] bg_tile_address_value[4];
  logic [7:0] bg_palette_index[4];
  logic [14:0] bg_palette_value[4];
  word_t bg_tile_map_address[4];
  word_t bg_tile_address[4];
  text_bg_regs_t bg_regs[4];

  always_comb begin
    bg_regs[0] = regs.background.bg0;
    bg_regs[1] = regs.background.bg1;
    bg_regs[2] = regs.background.bg2.text;
    bg_regs[3] = regs.background.bg3.text;
  end

  genvar bg;
  generate
    for (bg = 0; bg < 4; bg++) begin : generate_bg

      assign bg_tile_map_address_value[bg] = {
        VRAM.mem[bg_tile_map_address[bg]+1], VRAM.mem[bg_tile_map_address[bg]]
      };

      assign bg_tile_address_value[bg] = VRAM.mem[bg_tile_address[bg]];

      assign bg_palette_value[bg] = {
        palette[bg_palette_index[bg]*2+1][6:0], palette[bg_palette_index[bg]*2]
      };

      BackgroundCalculation background_calculation (
          .scan_x(scan_x),
          .scan_y(scan_y),
          .regs(bg_regs[bg]),
          .tile_map_address_value(bg_tile_map_address_value[bg]),
          .tile_address_value(bg_tile_address_value[bg]),
          .palette_value(bg_palette_value[bg]),
          .tile_map_address(bg_tile_map_address[bg]),
          .tile_address(bg_tile_address[bg]),
          .palette_index(bg_palette_index[bg]),
          .pixel(bg_pixel[bg])
      );
    end : generate_bg
  endgenerate

  always_ff @(posedge clk) begin
    if (regs.display.dispcnt.bg_mode == BG_MODE_0 && scan_x < 240 && scan_y < 160) begin
      if (regs.display.dispcnt.bg0_display) bg_line[0][scan_x[7:0]] <= bg_pixel[0];
      if (regs.display.dispcnt.bg1_display) bg_line[1][scan_x[7:0]] <= bg_pixel[1];
      if (regs.display.dispcnt.bg2_display) bg_line[2][scan_x[7:0]] <= bg_pixel[2];
      if (regs.display.dispcnt.bg3_display) bg_line[3][scan_x[7:0]] <= bg_pixel[3];
    end
  end

  pixel_t composed_pixel;

  Compositor compositor (
      .bg_pixel(bg_pixel),
      .bg_regs(bg_regs),
      .dispcnt(regs.display.dispcnt),
      .composed_pixel(composed_pixel)
  );

  GBA_Framebuffer framebuffer (
      .clk(clk),
      .reset(reset),
      .scan_x(scan_x),
      .scan_y(scan_y),
      .composed_pixel(composed_pixel)
  );
endmodule : GBA_PPU
