#include <filesystem>

#include <gtest/gtest.h>

#include "gba.hpp"
#include "util/image_golden.hpp"

namespace fs = std::filesystem;
using namespace vemu::gba::test;

TEST(GBAImageTests, Mode3Vertical) {
    GameboyAdvanceHarness harness;
    ASSERT_TRUE(harness.setup(fs::path(TEST_DIR) / "libtonc-examples/bin/mode3_vert.gba"));

    const auto framebuffer = render_after_frames(harness, 5);
    const auto golden = fs::path(__FILE__).parent_path().parent_path() / "golden/mode3_vert.ppm";
    expect_golden_image(framebuffer, golden);
}
