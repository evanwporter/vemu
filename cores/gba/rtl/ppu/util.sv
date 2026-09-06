import gba_ppu_types_pkg::*;
import gba_types_pkg::*;

/// Computes the screen-relative coordinates and tile map address for one text
/// background. 
module BackgroundCalculation (
    input logic [8:0] scan_x,
    input logic [8:0] scan_y,
    input text_bg_regs_t regs,
    /// Tile map entry read from VRAM at tile_map_address.
    input logic [15:0] tile_map_address_value,
    /// Tile byte read from VRAM at tile_address.
    input logic [7:0] tile_address_value,
    /// Palette color read using palette_index.
    input logic [14:0] palette_value,
    output word_t tile_map_address,
    output word_t tile_address,
    output logic [7:0] palette_index,
    output pixel_t pixel
);

  /// Width and height of the background. Each is either 256 or 512 depending
  /// on the screen size setting.
  logic [9:0] bg_width;
  assign bg_width = regs.control.screen_size[0] ? 512 : 256;

  logic [9:0] bg_height;
  assign bg_height = regs.control.screen_size[1] ? 512 : 256;

  /// Background pixel positions relative to the screen; i.e. where screen
  /// coordinates are on the larger background.
  logic [8:0] bg_x;
  assign bg_x = 9'((scan_x + regs.hofs.offset) % bg_width);

  logic [8:0] bg_y;
  assign bg_y = 9'((scan_y + regs.vofs.offset) % bg_height);

  /// 8x8 tile position of the current pixel in the background map.
  logic [5:0] tile_map_x;
  assign tile_map_x = 6'(bg_x >> 3);

  logic [5:0] tile_map_y;
  assign tile_map_y = 6'(bg_y >> 3);

  /// Position inside the 8x8 tile of the current pixel in the background map.
  logic [2:0] pixel_x;
  assign pixel_x = bg_x[2:0];

  logic [2:0] pixel_y;
  assign pixel_y = bg_y[2:0];

  /// Position inside the tile after applying the tile-map flip attributes.
  logic [2:0] tile_pixel_x;
  assign tile_pixel_x = tile_map_address_value[10] ? 3'd7 - pixel_x : pixel_x;

  logic [2:0] tile_pixel_y;
  assign tile_pixel_y = tile_map_address_value[11] ? 3'd7 - pixel_y : pixel_y;

  /// How many screen blocks wide the background is: one or two, depending on
  /// the screen size setting.
  logic [1:0] screenblocks_wide;
  assign screenblocks_wide = regs.control.screen_size[0] ? 2 : 1;

  /// Which screen block within the background contains the current pixel.
  logic [1:0] screenblocks_x;
  assign screenblocks_x = 2'(tile_map_x >> 5);

  logic [1:0] screenblocks_y;
  assign screenblocks_y = 2'(tile_map_y >> 5);

  /// Number of screen blocks from the base point.
  logic [1:0] screenblock_offset;
  assign screenblock_offset = screenblocks_y * screenblocks_wide + screenblocks_x;

  /// The selected screen block, including the background's base block.
  logic [4:0] screenblock_index;
  assign screenblock_index = regs.control.screen_base_block + 5'(screenblock_offset);

  /// Tile-map coordinates within screenblock_index.
  logic [4:0] local_tile_x;
  assign local_tile_x = tile_map_x[4:0];

  logic [4:0] local_tile_y;
  assign local_tile_y = tile_map_y[4:0];

  logic [9:0] tile_map_index;
  assign tile_map_index   = local_tile_y * 10'd32 + 10'(local_tile_x);

  assign tile_map_address = 32'(screenblock_index) * 32'h800 + 32'(tile_map_index) * 32'd2;

  /// Address of the selected tile pixel in character memory.
  logic [6:0] tile_size;
  assign tile_size = regs.control.color_mode == BG_COLOR_256 ? 64 : 32;

  logic [4:0] tile_pixel_offset;
  assign tile_pixel_offset = regs.control.color_mode == BG_COLOR_256 ?
                             5'(tile_pixel_y) * 5'd8 + 5'(tile_pixel_x) :
                             5'(tile_pixel_y) * 5'd4 + 5'(tile_pixel_x >> 1);

  assign tile_address = 32'(regs.control.character_base_block) * 32'h4000 +
                        32'(tile_map_address_value[9:0]) * 32'(tile_size) +
                        32'(tile_pixel_offset);

  /// Palette entry selected by the tile byte and, for 4bpp backgrounds, the
  /// palette-bank field in the tile-map entry.
  assign palette_index = regs.control.color_mode == BG_COLOR_256 ?
                         tile_address_value :
                         {tile_map_address_value[15:12],
                          tile_pixel_x[0] ? tile_address_value[7:4] : tile_address_value[3:0]};

  assign pixel = '{
          transparent: palette_index == 0,
          blue: palette_value[14:10],
          green: palette_value[9:5],
          red: palette_value[4:0]
      };

endmodule : BackgroundCalculation
