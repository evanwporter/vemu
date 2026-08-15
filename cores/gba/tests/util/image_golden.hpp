#pragma once

#include <cstdint>
#include <filesystem>
#include <stdexcept>
#include <vector>

#include <gtest/gtest.h>

#include "common/ppm.hpp"
#include "gba.hpp"
#include "src/ygba/video.h"
#include "util/test_config.hpp"

namespace vemu::gba::test {

    inline constexpr std::size_t GBA_FRAMEBUFFER_SIZE = SCREEN_WIDTH * SCREEN_HEIGHT;
    using GbaFramebuffer = std::vector<uint32_t>;

    inline GbaFramebuffer render_after_frames(GameboyAdvanceHarness& harness, std::size_t frame_count) {
        for (std::size_t frame = 0; frame < frame_count; ++frame) {
            for (int cycle = 0; cycle < CYCLES_FRAME; ++cycle)
                harness.tick();
        }

        GbaFramebuffer framebuffer(GBA_FRAMEBUFFER_SIZE);
        auto* root = harness.get_top().rootp;
        video_render_frame(root->GameboyAdvance__DOT__ppu__DOT__regs.data(), &root->GameboyAdvance__DOT__Palette__DOT__mem[0], &root->GameboyAdvance__DOT__ppu__DOT__VRAM__DOT__mem[0], &root->GameboyAdvance__DOT__OAM__DOT__mem[0], framebuffer.data());
        return framebuffer;
    }

    inline void expect_golden_image(const GbaFramebuffer& actual, const std::filesystem::path& golden_path) {
        const auto actual_path = std::filesystem::path(__FILE__).parent_path() / ".."
            / "golden-actual" / (golden_path.stem().string() + ".actual.ppm");
        std::filesystem::create_directories(actual_path.parent_path());
        vemu::write_ppm(actual, SCREEN_WIDTH, SCREEN_HEIGHT, actual_path, vemu::PixelFormat::ABGR8888);

        if (test_config().update) {
            std::filesystem::create_directories(golden_path.parent_path());
            std::filesystem::copy_file(actual_path, golden_path, std::filesystem::copy_options::overwrite_existing);
        }

        std::size_t width = 0;
        std::size_t height = 0;
        const auto expected = vemu::read_ppm(golden_path, width, height, vemu::PixelFormat::ABGR8888);
        ASSERT_EQ(width, SCREEN_WIDTH);
        ASSERT_EQ(height, SCREEN_HEIGHT);
        ASSERT_EQ(actual.size(), expected.size());

        for (std::size_t i = 0; i < actual.size(); ++i) {
            ASSERT_EQ(actual[i], expected[i])
                << "Pixel mismatch at (" << i % SCREEN_WIDTH << ", " << i / SCREEN_WIDTH
                << "). Actual image: " << actual_path;
        }
    }

} // namespace vemu::gba::test
