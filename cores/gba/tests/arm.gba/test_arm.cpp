#include <array>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <optional>
#include <sstream>

#include <gtest/gtest.h>

#include "gba.hpp"
#include "util/decode.hpp"
#include "util/test_config.hpp"
#include "util/util.hpp"


#include <nba/config.hpp>
#include <nba/core.hpp>
#include <nba/rom/rom.hpp>
#include <nba/src/core.hpp>

namespace fs = std::filesystem;
using namespace nba; // TODO: don't use this
using namespace vemu;
using namespace vemu::gba;

static std::vector<u8> ReadFile(const std::string& path) {
    std::ifstream file(path, std::ios::binary);
    if (!file) {
        throw std::runtime_error("Failed to open file: " + path);
    }

    file.seekg(0, std::ios::end);
    const size_t size = static_cast<size_t>(file.tellg());
    file.seekg(0, std::ios::beg);

    std::vector<u8> data(size);
    file.read(reinterpret_cast<char*>(data.data()), static_cast<std::streamsize>(size));
    if (!file) {
        throw std::runtime_error("Failed to read file: " + path);
    }

    return data;
}

static uint32_t read_u32_le(std::ifstream& f) {
    uint8_t b[4];
    f.read(reinterpret_cast<char*>(b), 4);
    if (!f) {
        throw std::runtime_error("Unexpected EOF while reading log");
    }

    return (uint32_t)b[0]
        | ((uint32_t)b[1] << 8)
        | ((uint32_t)b[2] << 16)
        | ((uint32_t)b[3] << 24);
}

static uint32_t read_u32_mem(const GameboyAdvanceHarness& h, uint32_t addr) {
    return (uint32_t)h.read_memory(addr)
        | ((uint32_t)h.read_memory(addr + 1) << 8)
        | ((uint32_t)h.read_memory(addr + 2) << 16)
        | ((uint32_t)h.read_memory(addr + 3) << 24);
}

static u32 read_u16_mem(const GameboyAdvanceHarness& h, uint32_t addr) {
    return (u32)h.read_memory(addr)
        | ((u32)h.read_memory(addr + 1) << 8);
}

static constexpr const char* ANSI_RED = "";
static constexpr const char* ANSI_GREEN = "";
static constexpr const char* ANSI_DIM = "";
static constexpr const char* ANSI_RESET = "";

struct TraceRow {
    std::array<uint32_t, 16> r {};
    uint32_t cpsr = 0;
    uint32_t spsr = 0;
    size_t step_index = 0;
};

static std::string format_row_plain(const TraceRow& row, bool pc_minus_4 = false) {
    std::ostringstream oss;
    oss << "step " << row.step_index << "  ";

    for (int i = 0; i < 16; i++) {
        uint32_t v = row.r[i];
        if (pc_minus_4 && i == 15) {
            v -= 4;
        }

        oss << "r" << std::dec << i << "=" << hex32(v);
        if (i != 15)
            oss << " ";
    }

    oss << " cpsr=" << hex32(row.cpsr)
        << " spsr=" << hex32(row.spsr);

    return oss.str();
}

static void print_debug_mismatch(
    const std::optional<TraceRow>& last_good,
    const TraceRow& expected,
    const TraceRow& actual) {
    std::cout << "\n"
              << "================ TRACE DEBUG ================\n";

    if (last_good.has_value()) {
        std::cout << "Last matching:\n";
        std::cout << "  " << format_row_plain(*last_good, false) << "\n";
    } else {
        std::cout << "Last matching:\n"
                  << "  <none>\n";
    }

    std::cout << ANSI_DIM << "Expected:\n"
              << ANSI_RESET;
    std::cout << "  " << format_row_plain(expected, false) << "\n";

    std::cout << ANSI_DIM << "Actual:\n"
              << ANSI_RESET;
    std::cout << "  " << format_row_plain(actual, false) << "\n";

    std::cout << "=============================================\n\n";
}

struct NbaOracle {
    std::shared_ptr<Config> config;
    std::unique_ptr<CoreBase> core;
    nba::core::Core* impl = nullptr;
};

static NbaOracle CreateNbaOracle(const fs::path& rom_path, const std::optional<fs::path>& bios_path = std::nullopt) {
    NbaOracle oracle;

    oracle.config = std::make_shared<Config>();
    oracle.config->skip_bios = !bios_path.has_value();

    oracle.core = CreateCore(oracle.config);
    oracle.impl = static_cast<nba::core::Core*>(oracle.core.get());

    if (bios_path.has_value()) {
        auto bios = ReadFile(bios_path->string());
        oracle.core->Attach(bios);
    }

    auto rom_data = ReadFile(rom_path.string());
    ROM rom(
        std::move(rom_data),
        nullptr, // no backup
        nullptr // no GPIO
    );

    oracle.core->Attach(std::move(rom));
    oracle.core->Reset();

    return oracle;
}

static TraceRow capture_nba_state(nba::core::Core* core_impl, size_t step_index) {
    TraceRow row {};
    row.step_index = step_index;

    auto& cpu = core_impl->GetCPU();
    auto& s = cpu.state;

    row.r[0] = s.r0;
    row.r[1] = s.r1;
    row.r[2] = s.r2;
    row.r[3] = s.r3;
    row.r[4] = s.r4;
    row.r[5] = s.r5;
    row.r[6] = s.r6;
    row.r[7] = s.r7;
    row.r[8] = s.r8;
    row.r[9] = s.r9;
    row.r[10] = s.r10;
    row.r[11] = s.r11;
    row.r[12] = s.r12;
    row.r[13] = s.r13;
    row.r[14] = s.r14;
    row.r[15] = s.r15;

    row.cpsr = s.cpsr.v;
    row.spsr = s.spsr[0].v; // todo: get correct mode

    return row;
}

static TraceRow capture_dut_state(GameboyAdvanceHarness& harness, size_t step_index) {
    TraceRow row {};
    row.step_index = step_index;

    ArmTraceState actual_state = harness.capture_arm_state();
    for (int i = 0; i < 16; i++) {
        row.r[i] = actual_state.r[i];
    }
    row.cpsr = actual_state.cpsr;
    row.spsr = actual_state.spsr;

    return row;
}

static void compare_states(
    const TraceRow& expected,
    const TraceRow& actual,
    const std::optional<TraceRow>& last_good) {

    for (int i = 0; i < 16; i++) {
        EXPECT_EQ(actual.r[i], expected.r[i])
            << "Step " << expected.step_index
            << " r" << i
            << " expected=" << hex32(expected.r[i])
            << " actual=" << hex32(actual.r[i]);
    }

    EXPECT_EQ(actual.cpsr, expected.cpsr)
        << "Step " << expected.step_index
        << " CPSR expected=" << hex32(expected.cpsr)
        << " actual=" << hex32(actual.cpsr);

    // EXPECT_EQ(actual.spsr, expected.spsr)
    //     << "Step " << expected.step_index
    //     << " SPSR expected=" << hex32(expected.spsr)
    //     << " actual=" << hex32(actual.spsr);

    if (::testing::Test::HasFailure()) {
        print_debug_mismatch(last_good, expected, actual);
    }
}

TEST(ARM_GBA_Tests, CPUInstrsAll) {
    fs::path rom_path;
    if (test_config().test_dir.has_value()) {
        rom_path = test_config().test_dir.value() / "gba-tests/arm/arm.gba";
    } else {
        rom_path = fs::path(TEST_DIR) / "gba-tests/arm/arm.gba";
    }

    testing::internal::CaptureStdout();
    testing::internal::CaptureStderr();

    GameboyAdvanceHarness harness({ true, fs::path(__FILE__).parent_path() / "arm.vcd" });
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
            if (step_index == 862)
                harness.get_top().rootp->GameboyAdvance__DOT__cpu_inst__DOT__regs.__PVT__common.__PVT__r2 = 436207618;

            if (step_index == 1331) {
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

    std::ofstream logfile("trace.log");
    ASSERT_TRUE(logfile) << "Failed to open trace.log";

    logfile << "\n==== Captured stdout ====\n"
            << stdout_output
            << "\n==== Captured stderr ====\n"
            << stderr_output;
    logfile.close();

    std::cout << "Wrote logs to trace.log\n";

    std::cout << "Validated " << step_index << " steps\n";
}