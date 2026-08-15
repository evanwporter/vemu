// ./build/debug/gb/tests/test_gb.exe --gtest_filter=PPU* --update
//
// You can display the generated PPM files using the util/display_ppm tool.

#include <cstddef>
#define SDL_MAIN_HANDLED

#include <cstdint>
#include <filesystem>

#include <gtest/gtest.h>

#include <verilated.h>

#include "digits.hpp"
#include "gpu.hpp"
#include "types.hpp"
#include "util/ppm.hpp"
#include "util/test_config.hpp"
#include "util/util.hpp"

#include "Vppu_top.h"
#include "Vppu_top___024root.h"

#include <fstream>

namespace fs = std::filesystem;

constexpr uint8_t LCDC_BG_ON = 0b00000001;
constexpr uint8_t LCDC_BG_TILE_MAP_9C00 = 0b00001000;
constexpr uint8_t LCDC_TILE_DATA_8000 = 0b00010000;
constexpr uint8_t LCDC_LCD_ON = 0b10000000;
constexpr uint8_t LCDC_WINDOW_ENABLE = 0b00100000;
constexpr uint8_t LCDC_WINDOW_TILE_MAP_9C00 = 0b01000000;

inline void tick(Vppu_top& top, VerilatedContext& ctx) {
    top.clk = 0;
    top.eval();
    ctx.timeInc(5);

    top.clk = 1;
    top.eval();
    ctx.timeInc(5);
}

inline static void run_ppu_frame(
    Vppu_top& top,
    VerilatedContext& ctx,
    const std::function<void(ppu_regs_t&, uint8_t)>& on_scanline,
    GPU& gpu) {
    uint8_t last_ly = 0xFF;

    while (!top.rootp->ppu_top__DOT__ppu__DOT__frame_done) {
        tick(top, ctx);

        auto& regs = top.rootp->ppu_top__DOT__ppu__DOT__regs;
        uint8_t ly = regs.__PVT__LY;

        if (ly != last_ly) {
            on_scanline(regs, ly);

            gpu.draw_scanline(ly);
            last_ly = ly;
        }
    }
}

void dont_init_oam(oam_t& oam) { };

inline void set_default_dmg_palettes(ppu_regs_t& regs) {
    regs.__PVT__BGP = 0xE4;
    regs.__PVT__OBP0 = 0xE4;
    regs.__PVT__OBP1 = 0xE4;
}

struct PPUFrameTestCase {
    std::string name;
    std::function<void(vram_t& vram)> init_vram;
    std::function<void(oam_t& oam)> init_oam =
        [](oam_t&) { };
    std::function<void(ppu_regs_t& ppu_regs)> init_regs =
        [](ppu_regs_t& regs) { };
    std::function<void(ppu_regs_t& regs, uint8_t ly)> on_scanline =
        [](ppu_regs_t&, uint8_t) { };
};

class PPUFrameTest
    : public ::testing::TestWithParam<PPUFrameTestCase> { };

TEST_P(PPUFrameTest, RendersCorrectFrame) {
    const auto& param = GetParam();

    VerilatedContext ctx;
    ctx.debug(0);
    ctx.time(0);

    Vppu_top top(&ctx);

    top.reset = 1;
    for (int i = 0; i < 4; ++i)
        tick(top, ctx);

    top.reset = 0;

    vram_t& vram = top.rootp->ppu_top__DOT__ppu__DOT__VRAM;
    for (int i = 0; i < 8192; ++i)
        vram[i] = 0;

    param.init_vram(vram);

    oam_t& oam = top.rootp->ppu_top__DOT__ppu__DOT__OAM;
    for (int i = 0; i < 160; ++i)
        oam[i] = 0;

    param.init_oam(oam);

    ppu_regs_t& regs = top.rootp->ppu_top__DOT__ppu__DOT__regs;
    set_default_dmg_palettes(regs);
    param.init_regs(regs);

    GPU gpu(
        vram,
        regs.__PVT__LY,
        regs.__PVT__LYC,
        regs.__PVT__SCX,
        regs.__PVT__SCY,
        regs.__PVT__WX,
        regs.__PVT__WY,
        regs.__PVT__LCDC,
        top.rootp->ppu_top__DOT__ppu__DOT__framebuffer_inst__DOT__buffer,
        test_config().gui);

    gpu.setup();

    run_ppu_frame(top, ctx, param.on_scanline, gpu);

    uint32_t fb[FB_SIZE];

    for (int i = 0; i < FB_SIZE; ++i)
        fb[i] = gb_color(top.rootp->ppu_top__DOT__ppu__DOT__framebuffer_inst__DOT__buffer[i]);

    gpu.render_snapshot();

    while (gpu.poll_events())
        ;

    gpu.exit();

    const fs::path golden = std::filesystem::path(__FILE__).parent_path().parent_path() / "golden" / (param.name + ".ppm");

    if (test_config().update) {
        fs::create_directories(golden.parent_path());
        write_ppm(fb, golden);
        GTEST_SKIP() << "Golden image updated: " << golden;
    }

    std::size_t w, h;
    const auto golden_pixels = read_ppm(golden, w, h);

    ASSERT_EQ(w, GB_WIDTH);
    ASSERT_EQ(h, GB_HEIGHT);

    for (std::size_t i = 0; i < FB_SIZE; ++i) {
        ASSERT_EQ(fb[i], golden_pixels[i])
            << "Pixel mismatch at index " << i;
    }
}

auto init_numbers_vram = [](vram_t& vram) {
    for (int i = 0; i < 16; ++i)
        write_numbered_tile(vram, i, i);

    for (int ty = 0; ty < 32; ++ty) {
        for (int tx = 0; tx < 32; ++tx) {
            uint8_t tile = tx % 16;
            vram[0x1800 + ty * 32 + tx] = tile; // 9800
            vram[0x1C00 + ty * 32 + tx] = tile; // 9C00
        }
    }
};

PPUFrameTestCase bg_basic {
    "bg_basic",
    init_numbers_vram
};

PPUFrameTestCase bg_scrolled {
    "bg_scrolled",
    init_numbers_vram,
    dont_init_oam,
    [](ppu_regs_t& regs) {
        regs.__PVT__SCX = 5;
        regs.__PVT__SCY = 11;
    },
};

PPUFrameTestCase bg_map_9c00 {
    "bg_map_9c00",
    init_numbers_vram,
    dont_init_oam,
    [](ppu_regs_t& regs) {
        regs.__PVT__LCDC |= (1 << 3); // BG map = 9C00
    },
};

PPUFrameTestCase bg_signed {
    "bg_signed",
    [](vram_t& vram) {
        init_numbers_vram(vram);

        for (int i = 0; i < 16; ++i)
            write_numbered_tile(vram, 0x1000 / 16 + i, i);
    },
    dont_init_oam,
    [](ppu_regs_t& regs) {
        regs.__PVT__LCDC &= ~(1 << 4);
    },
};

inline void write_solid_tile(vram_t& vram, int tile, uint8_t color = 0) {
    for (int r = 0; r < 8; ++r) {
        vram[tile * 16 + r * 2 + 0] = (color & 1) ? 0xFF : 0x00;
        vram[tile * 16 + r * 2 + 1] = (color & 2) ? 0xFF : 0x00;
    }
}

inline void write_numbered_tiles(vram_t& vram, int first, int count) {
    for (int i = 0; i < count; ++i)
        write_numbered_tile(vram, first + i, i);
}

inline void fill_tile_map(
    vram_t& vram,
    int base,
    const std::function<uint8_t(int x, int y)>& f) {
    for (int y = 0; y < 32; ++y)
        for (int x = 0; x < 32; ++x)
            vram[base + y * 32 + x] = f(x, y);
}

inline void write_signed_numbered_tile(
    vram_t& vram,
    int8_t tile_index,
    int value) {
    constexpr int TILE_8800 = 0x1000;
    int addr = TILE_8800 + tile_index * 16;
    write_numbered_tile(vram, addr / 16, value);
}

inline void init_checkerboard_bg(vram_t& vram, int tile = 0) {
    // Checkerboard tile
    for (int r = 0; r < 8; ++r) {
        vram[tile * 16 + r * 2 + 0] = (r & 1) ? 0xAA : 0x55;
        vram[tile * 16 + r * 2 + 1] = 0x00;
    }

    // Fill BG map with checkerboard tile
    fill_tile_map(vram, 0x1800, [tile](int, int) {
        return tile;
    });
}

PPUFrameTestCase window_basic {
    "window_basic",
    [](vram_t& vram) {
        write_numbered_tiles(vram, 0, 16);

        fill_tile_map(vram, 0x1800, [](int, int) { return 0; });
        fill_tile_map(vram, 0x1800, [](int x, int y) {
            return (x + y) & 0xF;
        });
    },
    dont_init_oam,
    [](ppu_regs_t& regs) {
        regs.__PVT__WX = 7;
        regs.__PVT__WY = 0;
        regs.__PVT__LCDC = LCDC_LCD_ON | LCDC_BG_ON | LCDC_TILE_DATA_8000 | (1 << 5);
    },
};

PPUFrameTestCase window_on_then_off {
    "window_on_then_off",
    [](vram_t& vram) {
        write_solid_tile(vram, 0);
        write_numbered_tiles(vram, 1, 16);

        fill_tile_map(vram, 0x1800, [](int, int) { return 0; });
        fill_tile_map(vram, 0x1C00, [](int x, int y) {
            return 1 + ((x + y) & 0xF);
        });
    },
    dont_init_oam,
    [](ppu_regs_t& regs) {
        regs.__PVT__WX = 7;
        regs.__PVT__WY = 32;
        regs.__PVT__LCDC = LCDC_LCD_ON | LCDC_BG_ON | LCDC_TILE_DATA_8000 | (1 << 6);
    },
    [](ppu_regs_t& regs, uint8_t ly) {
        if (ly == 32)
            regs.__PVT__LCDC |= (1 << 5);
        if (ly == 64)
            regs.__PVT__LCDC &= ~(1 << 5);
    }
};

PPUFrameTestCase window_hide_show_signed_tiles {
    "window_hide_show_signed_tiles",
    [](vram_t& vram) {
        init_checkerboard_bg(vram);

        // Unsigned window tiles
        write_numbered_tiles(vram, 1, 8);

        // Signed window tiles
        for (int i = 0; i < 8; ++i)
            write_signed_numbered_tile(vram, int8_t(0xA1 + i), i);

        fill_tile_map(vram, 0x1C00, [](int x, int y) {
            return (y < 4) ? 1 + (x & 7) : 0xA1 + (x & 7);
        });
    },
    dont_init_oam,
    [](ppu_regs_t& regs) {
        regs.__PVT__WX = 96;
        regs.__PVT__WY = 16;
        regs.__PVT__LCDC = LCDC_LCD_ON | LCDC_BG_ON | LCDC_WINDOW_ENABLE | LCDC_WINDOW_TILE_MAP_9C00;
    },
    [](ppu_regs_t& regs, uint8_t ly) {
        if (ly == 0)
            regs.__PVT__LCDC |= (1 << 4);
        if (ly == 64)
            regs.__PVT__LCDC &= ~(1 << 4);
        if (ly == 80)
            regs.__PVT__WX = 200;
        if (ly == 104)
            regs.__PVT__WX = 96;
    }
};

PPUFrameTestCase sprite_basic {
    .name = "sprite_single_number",

    .init_vram = [](vram_t& vram) {
        write_numbered_tile(vram, 0, 1);

        write_numbered_tile(vram, 1, 2);

        constexpr int TILE = 2;
        constexpr int BASE = TILE * 16;

        for (int row = 0; row < 8; row++) {
            vram[BASE + row * 2 + 0] = 0b10101010; // low bits
            vram[BASE + row * 2 + 1] = 0b01010101; // high bits
        }

        const int bg_map = 0x1800; // 0x9800 - 0x8000

        for (int y = 0; y < 32; y++) {
            for (int x = 0; x < 32; x++) {
                vram[bg_map + y * 32 + x] = ((x ^ y) & 1) ? 1 : 0;
            }
        } },

    .init_oam = [](oam_t& oam) {
        // Sprite 0
        // OAM format:
        // [0] Y + 16
        // [1] X + 8
        // [2] tile index
        // [3] attributes

        oam[0 + 4] = 16; // Y
        oam[1 + 4] = 8; // X
        oam[2 + 4] = 2; // tile index
        oam[3 + 4] = 0x00; // no flags
    },

    .init_regs = [](ppu_regs_t& regs) {
        regs.__PVT__SCX = 0;
        regs.__PVT__SCY = 0;

        regs.__PVT__LCDC = 0x80 | // LCD ON
            0x01 | // BG ON
            0x02 | // OBJ ON
            0x00 | // OBJ 8x8
            0x10; // tile data @ 8000
    }
};

inline void place_sprite(
    oam_t& oam,
    int sprite_idx,
    int x,
    int y,
    uint8_t tile,
    uint8_t flags = 0) {
    const int base = sprite_idx * 4;
    oam[base + 0] = y + 16; // OAM stores Y+16
    oam[base + 1] = x + 8; // OAM stores X+8
    oam[base + 2] = tile;
    oam[base + 3] = flags;
}

PPUFrameTestCase sprite_11_on_line {
    .name = "sprite_11_on_line",

    .init_vram = [](vram_t& vram) {
        // Background checkerboard
        init_checkerboard_bg(vram, 0);

        // Sprite tiles: numbers 0–10
        for (int i = 0; i < 11; ++i)
            write_numbered_tile(vram, 1 + i, i); },

    .init_oam = [](oam_t& oam) {
        constexpr int Y = 48; // all sprites on same scanline
        constexpr int X_START = 8;

        for (int i = 0; i < 11; ++i) {
            place_sprite(
                oam,
                i,
                X_START + i * 10, // non-overlapping
                Y,
                1 + i // tile index
            );
        } },

    .init_regs = [](ppu_regs_t& regs) { regs.__PVT__LCDC = LCDC_LCD_ON | LCDC_BG_ON | 0x02 | // OBJ enable
                                            0x00 | // OBJ 8x8
                                            LCDC_TILE_DATA_8000; }
};

PPUFrameTestCase sprite_flip_xy {
    .name = "sprite_flip_xy",

    .init_vram = [](vram_t& vram) {
        init_checkerboard_bg(vram, 0);

        write_numbered_tile(vram, 1, 5); },

    .init_oam = [](oam_t& oam) {
        constexpr int Y = 64;

        // Normal
        place_sprite(oam, 0, 24, Y, 1, 0x00);

        // X flip
        place_sprite(oam, 1, 40, Y, 1, 0x20);

        // Y flip
        place_sprite(oam, 2, 56, Y, 1, 0x40);

        // X + Y flip
        place_sprite(oam, 3, 72, Y, 1, 0x60); },

    .init_regs = [](ppu_regs_t& regs) { regs.__PVT__LCDC = LCDC_LCD_ON | LCDC_BG_ON | 0x02 | // OBJ enable
                                            0x00 | // OBJ 8x8
                                            LCDC_TILE_DATA_8000; }
};

PPUFrameTestCase sprite_8x16_stack_01 {
    .name = "sprite_8x16_stack_01",

    .init_vram = [](vram_t& vram) {
        init_checkerboard_bg(vram, 0);
        write_numbered_tile(vram, 1, 0);
        write_numbered_tile(vram, 2, 1);
        fill_tile_map(vram, 0x1800, [](int, int) { return 0; }); },

    .init_oam = [](oam_t& oam) { place_sprite(
                                     oam,
                                     0,
                                     40,
                                     40,
                                     1); },

    .init_regs = [](ppu_regs_t& regs) {
        regs.__PVT__SCX = 0;
        regs.__PVT__SCY = 0;

        regs.__PVT__LCDC = LCDC_LCD_ON | LCDC_BG_ON | 0x02 | 
            0x04 | LCDC_TILE_DATA_8000; }
};

PPUFrameTestCase sprite_left_edge_with_scx_discard {
    .name = "sprite_left_edge_with_scx_discard",

    .init_vram = [](vram_t& vram) {
        // BG: solid color 0 so sprite is obvious
        init_checkerboard_bg(vram, 0);
        fill_tile_map(vram, 0x1800, [](int, int){ return 0; });

        // Sprite tile 1: solid color 3 (non-transparent)
        write_solid_tile(vram, 1, 3); },

    .init_oam = [](oam_t& oam) {
        // Sprite at screen x = 0, y = 40
        // place_sprite takes screen coords
        place_sprite(oam, 0, 0, 40, 1, 0x00); },

    .init_regs = [](ppu_regs_t& regs) {
        regs.__PVT__SCX = 5;   // discard_count = 5
        regs.__PVT__SCY = 0;

        regs.__PVT__LCDC = LCDC_LCD_ON | LCDC_BG_ON | 0x02 | 0x00 | LCDC_TILE_DATA_8000; }
};

PPUFrameTestCase dmg_acid2_left_eye {
    .name = "dmg_acid2_left_eye",

    .init_vram = [](vram_t& vram) {
        // BG tile 0: solid color 1 (non-zero!)
        write_solid_tile(vram, 0, 1);

        // Fill BG map with tile 0
        fill_tile_map(vram, 0x1800, [](int, int) { return 0; });

        // OBJ tile: solid color 3
        write_solid_tile(vram, 1, 3); },

    .init_oam = [](oam_t& oam) {
        // Left eye sprite at X=56, Y=40
        // priority bit set (bit 7)
        place_sprite(oam, 0, 56, 40, 1, 0x80); },

    .init_regs = [](ppu_regs_t& regs) {
        regs.__PVT__SCX = 0;
        regs.__PVT__SCY = 32;

        regs.__PVT__WX = 88;   // window off to the right
        regs.__PVT__WY = 40;

        regs.__PVT__LCDC =
            LCDC_LCD_ON |
            LCDC_BG_ON |
            0x02 |              // OBJ enable
            LCDC_TILE_DATA_8000 |
            LCDC_WINDOW_ENABLE; }
};

template <typename T>
inline void load_binary_file(
    const std::filesystem::path& path,
    T dst,
    std::size_t expected_size) {
    ASSERT_TRUE(std::filesystem::exists(path))
        << "File not found: " << path;

    std::ifstream f(path, std::ios::binary);
    ASSERT_TRUE(f.good()) << "Failed to open " << path;

    // Read into the buffer using indexing (works for VlUnpacked and std::array)
    std::vector<uint8_t> tmp(expected_size);
    f.read(reinterpret_cast<char*>(tmp.data()), expected_size);
    ASSERT_EQ(static_cast<std::size_t>(f.gcount()), expected_size)
        << "File size mismatch for " << path;

    for (std::size_t i = 0; i < expected_size; ++i)
        dst[i] = tmp[i];
}

auto init_vram_from_file = [](const std::string& filename) {
    return [filename](vram_t& vram) {
        const auto path = std::filesystem::path(__FILE__).parent_path() / "artifacts" / filename;

        load_binary_file(path, vram, 0x2000);
    };
};

auto init_oam_from_file = [](const std::string& filename) {
    return [filename](oam_t& oam) {
        const auto path = std::filesystem::path(__FILE__).parent_path() / "artifacts" / filename;

        load_binary_file(path, oam, 0xA0);
    };
};

INSTANTIATE_TEST_SUITE_P(
    PPUTests,
    PPUFrameTest,
    ::testing::Values(
        bg_basic,
        bg_scrolled,
        bg_map_9c00,
        bg_signed,
        window_basic,
        window_on_then_off,
        window_hide_show_signed_tiles,
        sprite_basic,
        sprite_11_on_line,
        sprite_flip_xy,
        sprite_8x16_stack_01,
        sprite_left_edge_with_scx_discard),
    [](const ::testing::TestParamInfo<PPUFrameTestCase>& info) {
        return info.param.name;
    });
