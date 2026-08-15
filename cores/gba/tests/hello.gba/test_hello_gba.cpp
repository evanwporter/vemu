#include <array>
#include <filesystem>
#include <optional>

#include <gtest/gtest.h>

#include "gba.hpp"
#include "util/gba_differential.hpp"

namespace fs = std::filesystem;
using namespace nba; // TODO: don't use this
using namespace vemu;
using namespace vemu::gba;
using namespace vemu::gba::test;

TEST(Thumb_GBA_Tests, HelloMatchesNanoBoyAdvance) {
    const fs::path rom_path = fs::path(TEST_DIR) / "libtonc-examples/bin/hello.gba";
    const fs::path bios_path = fs::path(SOURCE_DIR) / "sim/src/gba_bios.bin";

    GameboyAdvanceHarness harness;
    ASSERT_TRUE(harness.setup(rom_path));

    const auto nba = CreateNbaOracle(rom_path, bios_path);
    ASSERT_NE(nba.impl, nullptr);

    std::optional<TraceRow> last_good;
    size_t step_index = 0;

    auto compare = [&] {
        const TraceRow actual = capture_dut_state(harness, step_index);
        const TraceRow expected = capture_nba_state(nba.impl, step_index);
        compare_states(expected, actual, last_good);
        if (::testing::Test::HasFailure())
            return false;
        last_good = expected;
        ++step_index;
        return true;
    };

    ASSERT_TRUE(compare());
    harness.tick();
    nba.core->Step();
    ASSERT_TRUE(compare());
    harness.tick();
    nba.core->Step();
    harness.get_top().rootp->GameboyAdvance__DOT__cpu_inst__DOT__instr_boundary = 0;
    ASSERT_TRUE(compare());

    constexpr size_t max_instructions = 300'000;
    bool completed = false;

    while (step_index < max_instructions) {
        int max_ticks = 40;
        auto* root = harness.get_top().rootp;
        root->GameboyAdvance__DOT__cpu_inst__DOT__instr_boundary = 0;
        while (root->GameboyAdvance__DOT__cpu_inst__DOT__instr_boundary == 0 && max_ticks-- > 0)
            harness.tick();
        ASSERT_GT(max_ticks, 0) << "DUT timed out at instruction " << step_index;

        nba.core->Step();
        if (root->GameboyAdvance__DOT__cpu_inst__DOT__flush_req) {
            harness.tick();
            harness.tick();
        }

        ASSERT_TRUE(compare()) << "hello.gba diverged at instruction " << step_index;

        // The final `while (1)` in hello.c branches at 0x080002A4.
        if (last_good->r[15] == 0x080002A8) {
            completed = true;
            break;
        }
    }

    ASSERT_TRUE(completed) << "hello.gba did not reach main's terminal loop";

    const auto* nba_palette = nba.core->GetPRAM();
    const auto* nba_vram = nba.core->GetVRAM();
    for (uint32_t i = 0; i < 0x400; ++i)
        EXPECT_EQ(harness.read_memory(0x05000000 + i), nba_palette[i])
            << "Palette mismatch at byte " << i;
    for (uint32_t i = 0; i < 0x18000; ++i)
        EXPECT_EQ(harness.read_memory(0x06000000 + i), nba_vram[i])
            << "VRAM mismatch at byte " << i;
}
