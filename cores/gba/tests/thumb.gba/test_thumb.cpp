#include <array>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <optional>
#include <sstream>

#include <gtest/gtest.h>

#include "gba.hpp"
#include "util/decode.hpp"
#include "util/gba_differential.hpp"
#include "util/test_config.hpp"
#include "util/util.hpp"

namespace fs = std::filesystem;
using namespace nba; // TODO: don't use this
using namespace vemu;
using namespace vemu::gba;
using namespace vemu::gba::test;

TEST(Thumb_GBA_Tests, CPUInstrsAll) {
    fs::path rom_path;
    if (test_config().test_dir.has_value()) {
        rom_path = test_config().test_dir.value() / "gba-tests/thumb/thumb.gba";
    } else {
        rom_path = fs::path(TEST_DIR) / "gba-tests/thumb/thumb.gba";
    }

    testing::internal::CaptureStdout();
    testing::internal::CaptureStderr();

    GameboyAdvanceHarness harness({ true, fs::path(__FILE__).parent_path() / "thumb.vcd" });
    ASSERT_TRUE(harness.setup(rom_path)) << "Failed to set up Gameboy Advance harness with ROM: " << rom_path;

    size_t step_index = 0;

    std::optional<TraceRow> last_good;

    const auto nba = CreateNbaOracle(rom_path);
    ASSERT_NE(nba.impl, nullptr) << "Failed to create NBA oracle";

    // Compare initial state after reset.
    {
        TraceRow actual = capture_dut_state(harness, step_index);
        TraceRow expected = capture_nba_state(nba.impl, step_index);

        compare_states(expected, actual, last_good);
        ASSERT_FALSE(::testing::Test::HasFailure()) << "Initial state mismatch after reset";

        last_good = expected;
        step_index++;
    }

    std::cout << "\nCycle 2: Start flush" << std::endl;

    harness.tick();
    nba.core->Step();

    {
        TraceRow actual = capture_dut_state(harness, step_index);
        TraceRow expected = capture_nba_state(nba.impl, step_index);

        compare_states(expected, actual, last_good);
        ASSERT_FALSE(::testing::Test::HasFailure()) << "State mismatch at step " << step_index;

        last_good = expected;
        step_index++;
    }

    std::cout << "\nCycle 3: Start flush and decode" << std::endl;

    // Fetch and Decode
    harness.tick();
    nba.core->Step();

    harness.get_top().rootp->GameboyAdvance__DOT__cpu_inst__DOT__instr_boundary = 0;

    {
        TraceRow actual = capture_dut_state(harness, step_index);
        TraceRow expected = capture_nba_state(nba.impl, step_index);

        compare_states(expected, actual, last_good);

        ASSERT_FALSE(::testing::Test::HasFailure()) << "State mismatch at step " << step_index;

        last_good = expected;
        step_index++;
    }

    std::cout << "\n\nBeginning Execution of First Instruction\n";

    int cycles = 0;
    int instructions_executed = 0;

    while (true) {
        int max_ticks = 40;
        std::cout << "\n===============================================\n";
        std::cout << "Executing instruction " << instructions_executed << std::endl;
        std::cout << "===============================================\n";

        {
            TraceRow actual = capture_dut_state(harness, step_index);

            uint32_t pc = actual.r[15];

            bool thumb_mode = is_thumb_mode(actual.cpsr);

            int instr_size = thumb_mode ? 2 : 4;

            // ARM pipeline:
            // PC points 8 bytes ahead → instruction being executed is at PC - 8
            u32 instr_addr_exec = pc - (2 * instr_size);
            u32 instr_addr_fetch = pc - instr_size;

            u32 instr_exec = thumb_mode
                ? read_u16_mem(harness, instr_addr_exec)
                : read_u32_mem(harness, instr_addr_exec);

            u32 instr_fetch = thumb_mode
                ? read_u16_mem(harness, instr_addr_fetch)
                : read_u32_mem(harness, instr_addr_fetch);

            auto decoded_exec = DecodeARMInstruction(instr_exec);
            auto decoded_fetch = DecodeARMInstruction(instr_fetch);

            CpuMode mode = decode_cpu_mode(actual.cpsr);

            std::cout << "---- Instruction Debug ----\n";
            std::cout << "PC            = " << hex32(pc) << "\n";
            std::cout << "Mode          = " << cpu_mode_to_string(mode) << "\n";
            std::cout << "Exec          = " << exec_mode_to_string(actual.cpsr) << "\n";
            std::cout << "Exec Addr     = " << hex32(instr_addr_exec)
                      << " Instr=" << (thumb_mode ? hex16(instr_exec) : hex32(instr_exec))
                      << " Type=" << ToString(decoded_exec) << "\n";
            std::cout << "Fetch Addr    = " << hex32(instr_addr_fetch)
                      << " Instr=" << (thumb_mode ? hex16(instr_fetch) : hex32(instr_fetch))
                      << " Type=" << ToString(decoded_fetch) << "\n";
            std::cout << "----------------------------\n";

            EXPECT_EQ(instr_exec, nba.impl->GetCPU().GetFetchedOpcode(0))
                << "Step " << step_index
                << " Executing instruction mismatch. Instruction at PC-8 expected=" << hex32(instr_exec)
                << " actual=" << hex32(nba.impl->GetCPU().GetFetchedOpcode(0));

            EXPECT_EQ(instr_fetch, nba.impl->GetCPU().GetFetchedOpcode(1))
                << "Step " << step_index
                << " Fetching instruction mismatch. Instruction at PC-4 expected=" << hex32(instr_fetch)
                << " actual=" << hex32(nba.impl->GetCPU().GetFetchedOpcode(1));

            auto mask_thumb = [&](uint32_t v) {
                return thumb_mode ? (v & 0xFFFF) : v;
            };

            u32 decoder_inst_IR = mask_thumb(harness.get_top().rootp->GameboyAdvance__DOT__cpu_inst__DOT__decoder_inst__DOT__IR);
            u32 cpu_inst_IR = mask_thumb(harness.get_top().rootp->GameboyAdvance__DOT__cpu_inst__DOT__IR);

            EXPECT_EQ(decoder_inst_IR, nba.impl->GetCPU().GetFetchedOpcode(0))
                << "Step " << step_index
                << " Decoded instruction mismatch. Expected instruction at PC-8=" << hex32(nba.impl->GetCPU().GetFetchedOpcode(0))
                << " actual=" << hex32(decoder_inst_IR);

            EXPECT_EQ(cpu_inst_IR, nba.impl->GetCPU().GetFetchedOpcode(1))
                << "Step " << step_index
                << " Fetched instruction mismatch. Expected instruction at PC-4=" << hex32(nba.impl->GetCPU().GetFetchedOpcode(1))
                << " actual=" << hex32(cpu_inst_IR);

            if (::testing::Test::HasFailure()) {
                harness.half_tick();
                break;
            }
        }

        harness.get_top().rootp->GameboyAdvance__DOT__cpu_inst__DOT__instr_boundary = 0;

        while (harness.get_top().rootp->GameboyAdvance__DOT__cpu_inst__DOT__instr_boundary == 0 && max_ticks-- > 0) {
            std::cout << "\nCycle " << (cycles + 4) << ": Execute" << std::endl;
            harness.tick();
            cycles++;
        }

        nba.core->Step();

        instructions_executed++;

        EXPECT_GT(max_ticks, 0)
            << "Timeout in test.";

        if (harness.get_top().rootp->GameboyAdvance__DOT__cpu_inst__DOT__flush_req) {
            std::cout << "\n2 cycles of flush remaining" << std::endl;
            harness.tick();
            std::cout << "\n1 cycles of flush remaining" << std::endl;
            harness.tick();
        }

        {
            if (step_index == 791) {
                // TODO: Implement display
                break;
            }

            TraceRow actual = capture_dut_state(harness, step_index);
            TraceRow expected = capture_nba_state(nba.impl, step_index);
            compare_states(expected, actual, last_good);

            // EXPECT_EQ(harness.get_top().rootp->GameboyAdvance__DOT__cpu_inst__DOT__decoder_inst__DOT__IR, nba.impl->GetCPU().GetFetchedOpcode(0))
            //     << "Step " << step_index
            //     << " Decoded instruction mismatch. Expected instruction at PC-8=" << hex32(nba.impl->GetCPU().GetFetchedOpcode(0))
            //     << " actual=" << hex32(harness.get_top().rootp->GameboyAdvance__DOT__cpu_inst__DOT__decoder_inst__DOT__IR);

            // EXPECT_EQ(harness.get_top().rootp->GameboyAdvance__DOT__cpu_inst__DOT__IR, nba.impl->GetCPU().GetFetchedOpcode(1))
            //     << "Step " << step_index
            //     << " Fetched instruction mismatch. Expected instruction at PC-4=" << hex32(nba.impl->GetCPU().GetFetchedOpcode(1))
            //     << " actual=" << hex32(harness.get_top().rootp->GameboyAdvance__DOT__cpu_inst__DOT__IR);

            if (::testing::Test::HasFailure()) {
                harness.half_tick();
                print_debug_mismatch(last_good, expected, actual);
                break;
            }

            step_index++;
        }
    }

    std::string stdout_output = testing::internal::GetCapturedStdout();
    std::string stderr_output = testing::internal::GetCapturedStderr();

    // std::cout << "\n==== Captured stdout ====\n"
    //           << stdout_output
    //           << "\n==== Captured stderr ====\n"
    //           << stderr_output;

    const fs::path log_path = fs::current_path() / "thumb_trace.log";

    std::ofstream logfile(log_path);
    ASSERT_TRUE(logfile) << "Failed to open thumb_trace.log";

    logfile << "\n==== Captured stdout ====\n"
            << stdout_output
            << "\n==== Captured stderr ====\n"
            << stderr_output;
    logfile.close();

    std::cout << "Wrote logs to " << log_path << "\n";

    std::cout << "Validated " << step_index << " steps\n";
}
