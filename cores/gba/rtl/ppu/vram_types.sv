import gba_types_pkg::*;

package gba_ppu_vram_types_pkgs;
  // --- Common Types ---
  typedef logic [3:0] nibble_t;

  // =========================================================================
  // 1. 4bpp Tile (16 Colors / 16 Palettes)
  // Total Size: 32 bytes (256 bits)
  // Packed format: Low nibble = even pixel (X), High nibble = odd pixel (X+1)
  // =========================================================================

  typedef struct packed {
    nibble_t px_odd;   // High nibble: Pixel X+1
    nibble_t px_even;  // Low nibble:  Pixel X
  } gba_4bpp_pixel_pair_t;

  typedef gba_4bpp_pixel_pair_t [3:0] gba_4bpp_row_t;  // 4 pairs = 8 pixels (32 bits)

  typedef struct packed {
    gba_4bpp_row_t [7:0] rows;  // 8 rows x 4 pairs = 32 bytes
  } gba_tile_4bpp_t;


  // =========================================================================
  // 2. 8bpp Tile (256 Colors / Direct Palette)
  // Total Size: 64 bytes (512 bits)
  // Linear format: 1 byte per pixel, left-to-right, top-to-bottom
  // =========================================================================

  typedef byte_t [7:0] gba_8bpp_row_t;  // 8 bytes = 8 pixels (64 bits)

  typedef struct packed {
    gba_8bpp_row_t [7:0] rows;  // 8 rows x 8 pixels = 64 bytes
  } gba_tile_8bpp_t;

  /// Tileset containing 512 4bpp tiles
  typedef gba_tile_4bpp_t [511:0] tileset_4bpp_t;

  /// Tileset containing 256 8bpp tiles
  typedef gba_tile_8bpp_t [255:0] tileset_8bpp_t;

  typedef struct packed {
    /// 4 bits for palette index (0-15)
    logic [3:0] palette_index;

    logic vert_flip;

    logic horizontal_flip;

    /// 10 bits for tile index (0-1023)
    logic [9:0] tile_index;
  } tilemap_entry_t;

  typedef tilemap_entry_t [31:0] tilemap_block_t;

  typedef union {
    tilemap_block_t [7:0] tilemap_blocks;
    tileset_4bpp_t tileset_4bpp;
    tileset_8bpp_t tileset_8bpp;
  } block_t;

  typedef union {
    struct {
      block_t bg_block[3:0];
      block_t obj_block[1:0];
    } mode_0_1_2;

    struct {
      byte_t framebuffer_0[0:80*1024-1];
      byte_t obj[0:16*1024-1];
    } mode_3;

    struct {
      byte_t framebuffer_0[0:40*1024-1];
      byte_t framebuffer_1[0:40*1024-1];
      byte_t obj[0:16*1024-1];
    } mode_4_5;

  } VRAM_t;

endpackage : gba_ppu_vram_types_pkgs
