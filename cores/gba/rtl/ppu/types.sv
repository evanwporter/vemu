package gba_ppu_types_pkg;
  typedef enum logic [2:0] {
    BG_MODE_0 = 3'd0,
    BG_MODE_1 = 3'd1,
    BG_MODE_2 = 3'd2,
    BG_MODE_3 = 3'd3,
    BG_MODE_4 = 3'd4,
    BG_MODE_5 = 3'd5,
    BG_MODE_PROHIBITED_6 = 3'd6,
    BG_MODE_PROHIBITED_7 = 3'd7
  } bg_mode_t;

  typedef enum logic {
    DISPLAY_FRAME_0 = 1'b0,
    DISPLAY_FRAME_1 = 1'b1
  } display_frame_t;

  typedef enum logic {
    OBJ_VRAM_MAPPING_2D = 1'b0,
    OBJ_VRAM_MAPPING_1D = 1'b1
  } obj_vram_mapping_t;

  /// DISPCNT at 0x04000000, represented as a 16-bit bus word.
  typedef struct packed {
    logic obj_window_display;
    logic window_1_display;
    logic window_0_display;
    logic obj_display;
    logic bg3_display;
    logic bg2_display;
    logic bg1_display;
    logic bg0_display;
    logic forced_blank;
    obj_vram_mapping_t obj_vram_mapping;
    logic hblank_interval_free;
    display_frame_t display_frame;
    logic cgb_mode;
    bg_mode_t bg_mode;
  } dispcnt_t;

  localparam int DISPCNT_WIDTH = $bits(dispcnt_t);

  typedef enum logic {
    BG_COLOR_16_PALETTES = 1'b0,
    BG_COLOR_256         = 1'b1
  } bg_color_mode_t;

  typedef enum logic [1:0] {
    BG_SCREEN_SIZE_0 = 2'd0,
    BG_SCREEN_SIZE_1 = 2'd1,
    BG_SCREEN_SIZE_2 = 2'd2,
    BG_SCREEN_SIZE_3 = 2'd3
  } bg_screen_size_t;

  typedef enum logic [1:0] {
    COLOR_EFFECT_NONE                = 2'd0,
    COLOR_EFFECT_ALPHA_BLEND         = 2'd1,
    COLOR_EFFECT_BRIGHTNESS_INCREASE = 2'd2,
    COLOR_EFFECT_BRIGHTNESS_DECREASE = 2'd3
  } color_effect_t;

  /// 0x04000004 DISPSTAT.
  typedef struct packed {
    logic [7:0] vcount_setting;
    logic nds_vcount_setting_msb;
    logic dsi_lcd_ready;
    logic vcounter_irq_enable;
    logic hblank_irq_enable;
    logic vblank_irq_enable;
    logic vcounter_flag;
    logic hblank_flag;
    logic vblank_flag;
  } dispstat_t;

  /// 0x04000006 VCOUNT.
  typedef struct packed {
    logic [6:0] reserved_15_9;
    logic nds_current_scanline_msb;
    logic [7:0] current_scanline;
  } vcount_t;

  /// 0x04000008-0x0400000E BG0CNT-BG3CNT.
  typedef struct packed {
    bg_screen_size_t screen_size;
    logic area_overflow;
    logic [4:0] screen_base_block;
    bg_color_mode_t color_mode;
    logic mosaic_enable;
    logic [1:0] reserved_5_4;
    logic [1:0] character_base_block;
    logic [1:0] bg_priority;
  } bg_control_t;

  /// BGxHOFS and BGxVOFS.
  typedef struct packed {
    logic [6:0] reserved_15_9;
    logic [8:0] offset;
  } bg_offset_t;

  /// BG2X/BG2Y and BG3X/BG3Y signed 19.8 fixed-point reference points.
  typedef struct packed {
    logic [3:0] reserved_31_28;
    logic signed [27:0] value;
  } bg_reference_point_t;

  /// BG2PA-D and BG3PA-D signed 7.8 fixed-point affine parameters.
  typedef struct packed {
    logic signed [15:0] value;
  } bg_affine_parameter_t;

  /// WIN0H/WIN1H.
  typedef struct packed {
    logic [7:0] left;
    logic [7:0] right_plus_one;
  } window_horizontal_t;

  /// WIN0V/WIN1V.
  typedef struct packed {
    logic [7:0] top;
    logic [7:0] bottom_plus_one;
  } window_vertical_t;

  typedef struct packed {
    logic [1:0] reserved;
    logic color_effect_enable;
    logic obj_enable;
    logic bg3_enable;
    logic bg2_enable;
    logic bg1_enable;
    logic bg0_enable;
  } window_layer_control_t;

  /// 0x04000048 WININ.
  typedef struct packed {
    window_layer_control_t window_1;
    window_layer_control_t window_0;
  } window_inside_control_t;

  /// 0x0400004A WINOUT.
  typedef struct packed {
    window_layer_control_t obj_window;
    window_layer_control_t outside;
  } window_outside_control_t;

  /// 0x0400004C MOSAIC.
  typedef struct packed {
    logic [15:0] reserved_31_16;
    logic [3:0] obj_vertical_size_minus_one;
    logic [3:0] obj_horizontal_size_minus_one;
    logic [3:0] bg_vertical_size_minus_one;
    logic [3:0] bg_horizontal_size_minus_one;
  } mosaic_t;

  typedef struct packed {
    logic backdrop;
    logic obj;
    logic bg3;
    logic bg2;
    logic bg1;
    logic bg0;
  } color_effect_targets_t;

  /// 0x04000050 BLDCNT.
  typedef struct packed {
    logic [1:0] reserved_15_14;
    color_effect_targets_t second_target;
    color_effect_t effect;
    color_effect_targets_t first_target;
  } blend_control_t;

  /// 0x04000052 BLDALPHA.
  typedef struct packed {
    logic [2:0] reserved_15_13;
    logic [4:0] evb;
    logic [2:0] reserved_7_5;
    logic [4:0] eva;
  } blend_alpha_t;

  /// 0x04000054 BLDY.
  typedef struct packed {
    logic [26:0] reserved_31_5;
    logic [4:0] evy;
  } blend_brightness_t;

  /// Mode 3/5 bitmap pixel and palette entry (RGB555).
  typedef struct packed {
    logic reserved_15;
    logic [4:0] blue;
    logic [4:0] green;
    logic [4:0] red;
  } rgb555_t;

  /// Text-mode BG map entry.
  typedef struct packed {
    logic [3:0] palette_number;
    logic vertical_flip;
    logic horizontal_flip;
    logic [9:0] tile_number;
  } text_bg_map_entry_t;

  /// Rotation/scaling BG map entry.
  typedef struct packed {
    logic [7:0] tile_number;
  } affine_bg_map_entry_t;

  /// Complete byte-addressed LCD I/O register file (0x04000000-0x04000057).
  /// Fields are ordered from highest to lowest address so that bit N*8 maps
  /// directly to register byte offset N.
  typedef struct packed {
    blend_brightness_t bldy;
    blend_alpha_t bldalpha;
    blend_control_t bldcnt;
    mosaic_t mosaic;
    window_outside_control_t winout;
    window_inside_control_t winin;
    window_vertical_t win1v;
    window_vertical_t win0v;
    window_horizontal_t win1h;
    window_horizontal_t win0h;
    bg_reference_point_t bg3y;
    bg_reference_point_t bg3x;
    bg_affine_parameter_t bg3pd;
    bg_affine_parameter_t bg3pc;
    bg_affine_parameter_t bg3pb;
    bg_affine_parameter_t bg3pa;
    bg_reference_point_t bg2y;
    bg_reference_point_t bg2x;
    bg_affine_parameter_t bg2pd;
    bg_affine_parameter_t bg2pc;
    bg_affine_parameter_t bg2pb;
    bg_affine_parameter_t bg2pa;
    bg_offset_t bg3vofs;
    bg_offset_t bg3hofs;
    bg_offset_t bg2vofs;
    bg_offset_t bg2hofs;
    bg_offset_t bg1vofs;
    bg_offset_t bg1hofs;
    bg_offset_t bg0vofs;
    bg_offset_t bg0hofs;
    bg_control_t bg3cnt;
    bg_control_t bg2cnt;
    bg_control_t bg1cnt;
    bg_control_t bg0cnt;
    vcount_t vcount;
    dispstat_t dispstat;
    logic [15:0] reserved_02_03;
    dispcnt_t dispcnt;
  } ppu_regs_t;

  localparam int PPU_REGS_WIDTH = $bits(ppu_regs_t);

endpackage : gba_ppu_types_pkg
