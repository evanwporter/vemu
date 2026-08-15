#include <gtest/gtest.h>

#include "gba_differential.hpp"

TEST(Jsmolka_GBA_Tests, ARM_GBA) {
    vemu::gba::test::RunCpuInstructionTest({ .name = "arm", .rom_rel_path = "gba-tests/arm/arm.gba", .end_step_index = 1331, .step_hook = [](GameboyAdvanceHarness& harness, size_t step_index) {
                                                if (step_index == 862) {
                                                    harness.get_top().rootp->GameboyAdvance__DOT__cpu_inst__DOT__regs.__PVT__common.__PVT__r2 = 436207618;
                                                }
                                                return false;
                                            } });
}

TEST(Jsmolka_GBA_Tests, Thumb_GBA) {
    vemu::gba::test::RunCpuInstructionTest({ .name = "thumb", .rom_rel_path = "gba-tests/thumb/thumb.gba", .end_step_index = 791, .step_hook = nullptr });
}
