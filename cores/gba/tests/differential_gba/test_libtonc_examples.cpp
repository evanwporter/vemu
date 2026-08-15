#include <gtest/gtest.h>

#include "gba_differential.hpp"

TEST(Libtonc_GBA_Tests, HelloGBA) {
    vemu::gba::test::RunCpuInstructionTest({ .name = "libtonc", .rom_rel_path = "libtonc-examples/bin/hello.gba", .end_step_index = 1'000'000, .step_hook = nullptr });
}
