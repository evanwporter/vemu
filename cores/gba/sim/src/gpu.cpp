#include "gpu.hpp"

namespace {

    u32 rgb555_to_rgb888(u16 pixel) {
        const u32 red = pixel & 0x1F;
        const u32 green = (pixel >> 5) & 0x1F;
        const u32 blue = (pixel >> 10) & 0x1F;
        return 0xFF000000 | ((blue << 3 | blue >> 2) << 16) | ((green << 3 | green >> 2) << 8) | (red << 3 | red >> 2);
    }

} // namespace

void render_ppu_frame(GameboyAdvanceHarness& gba, u32 framebuffer[160][240]) {
    const auto& rtl_framebuffer = gba.get_top().rootp->GameboyAdvance__DOT__ppu__DOT__framebuffer__DOT__framebuffer;

    for (int y = 0; y < 160; ++y) {
        for (int x = 0; x < 240; ++x) {
            const int pixel_index = x * 160 + y;
            const u16 pixel = rtl_framebuffer[pixel_index / 2] >> ((pixel_index % 2) * 16);
            framebuffer[y][x] = rgb555_to_rgb888(pixel);
        }
    }
}
