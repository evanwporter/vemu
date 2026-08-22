#include <gtest/gtest.h>

#include "gba_differential.hpp"
#include "src/ygba/video.h"

TEST(Libtonc_GBA_Tests, HelloGBA) {
    vemu::gba::test::RunCpuInstructionTest({ .name = "libtonc", .rom_rel_path = "libtonc-examples/bin/hello.gba", .end_step_index = 1'000'000, .step_hook = nullptr });
}

TEST(Libtonc_GBA_Tests, HelloRendersNonBlackPixels) {
    GameboyAdvanceHarness harness;
    ASSERT_TRUE(harness.setup(std::filesystem::path(TEST_DIR) / "libtonc-examples/bin/hello.gba"));

    for (int cycle = 0; cycle < 1'500'000; ++cycle)
        ASSERT_TRUE(harness.tick());

    std::size_t non_black_pixels = 0;
    for (const auto& row : screen_pixels) {
        for (const uint32_t pixel : row)
            non_black_pixels += pixel != 0xff000000;
    }
    EXPECT_GT(non_black_pixels, 0u);
    EXPECT_LT(non_black_pixels, static_cast<std::size_t>(SCREEN_WIDTH * SCREEN_HEIGHT));
}
