#include <array>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <optional>
#include <sstream>

#include <gtest/gtest.h>

#include "decode.hpp"
#include "gba.hpp"

namespace fs = std::filesystem;

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

static std::string hex32(uint32_t v) {
    std::ostringstream oss;
    oss << "0x"
        << std::hex << std::uppercase
        << std::setw(8) << std::setfill('0')
        << v;
    return oss.str();
}

static constexpr const char* ANSI_RED = "\x1b[31m";
static constexpr const char* ANSI_GREEN = "\x1b[32m";
static constexpr const char* ANSI_DIM = "\x1b[90m";
static constexpr const char* ANSI_RESET = "\x1b[0m";

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

static std::string format_row_compare(
    const TraceRow& expected,
    const TraceRow& actual,
    bool actual_pc_minus_4 = false) {
    std::ostringstream oss;
    oss << "step " << expected.step_index << "  ";

    for (int i = 0; i < 16; i++) {
        uint32_t ev = expected.r[i];
        uint32_t av = actual.r[i];
        if (actual_pc_minus_4 && i == 15) {
            av -= 4;
        }

        bool same = (ev == av);
        oss << (same ? ANSI_GREEN : ANSI_RED)
            << "r" << std::dec << i << "=" << hex32(av)
            << ANSI_RESET;

        if (i != 15)
            oss << " ";
    }

    bool cpsr_same = (expected.cpsr == actual.cpsr);
    bool spsr_same = (expected.spsr == actual.spsr);

    oss << " "
        << (cpsr_same ? ANSI_GREEN : ANSI_RED)
        << "cpsr=" << hex32(actual.cpsr)
        << ANSI_RESET
        << " "
        << (spsr_same ? ANSI_GREEN : ANSI_RED)
        << "spsr=" << hex32(actual.spsr)
        << ANSI_RESET;

    return oss.str();
}

static void print_debug_mismatch(
    const std::optional<TraceRow>& last_good,
    const TraceRow& expected,
    const TraceRow& actual) {
    std::cout << "\n"
              << ANSI_DIM
              << "================ TRACE DEBUG ================\n"
              << ANSI_RESET;

    if (last_good.has_value()) {
        std::cout << ANSI_DIM << "Last matching:\n"
                  << ANSI_RESET;
        std::cout << "  " << format_row_plain(*last_good, /*pc_minus_4=*/true) << "\n";
    } else {
        std::cout << ANSI_DIM << "Last matching:\n"
                  << ANSI_RESET;
        std::cout << "  <none>\n";
    }

    std::cout << ANSI_DIM << "Expected:\n"
              << ANSI_RESET;
    std::cout << "  " << format_row_plain(expected, /*pc_minus_4=*/false) << "\n";

    std::cout << ANSI_DIM << "Actual:\n"
              << ANSI_RESET;
    std::cout << "  " << format_row_compare(expected, actual, /*actual_pc_minus_4=*/true) << "\n";

    std::cout << ANSI_DIM
              << "Legend: green = match, red = mismatch\n"
              << "=============================================\n\n"
              << ANSI_RESET;
}

TEST(ARM_GBA_Tests, CPUInstrsAll) {
    const fs::path rom_path = fs::path(TEST_DIR) / "arm.gba";
    const fs::path log_path = R"(C:\Users\evanw\vemu\tests\GBA-Logs\logs\arm-log.bin)";

    // testing::internal::CaptureStdout();
    // testing::internal::CaptureStderr();

    GameboyAdvanceHarness harness;
    ASSERT_TRUE(harness.setup(rom_path));

    std::ifstream log(log_path, std::ios::binary);
    ASSERT_TRUE(log) << "Failed to open log file";

    for (int skip = 0; skip < 2; skip++) {
        for (int i = 0; i < 16; i++)
            read_u32_le(log);
        read_u32_le(log); // CPSR
        read_u32_le(log); // SPSR
    }

    size_t step_index = 0;
    std::optional<TraceRow> last_good;

    while (true) {
        if (log.peek() == EOF) {
            break;
        }

        TraceRow expected;
        expected.step_index = step_index;
        for (int i = 0; i < 16; i++) {
            expected.r[i] = read_u32_le(log);
        }
        expected.cpsr = read_u32_le(log);
        expected.spsr = read_u32_le(log);

        ASSERT_TRUE(harness.step()) << "Step failed at " << step_index;

        ArmTraceState actual_state = harness.capture_arm_state();

        TraceRow actual;
        actual.step_index = step_index;
        for (int i = 0; i < 16; i++) {
            actual.r[i] = actual_state.r[i];
        }
        actual.cpsr = actual_state.cpsr;
        actual.spsr = actual_state.spsr;

        bool row_matches = true;

        for (int i = 0; i < 15; i++) {
            if (actual.r[i] != expected.r[i]) {
                row_matches = false;
                break;
            }
        }

        if (row_matches && (actual.r[15] - 4 != expected.r[15])) {
            row_matches = false;
        }
        if (row_matches && actual.cpsr != expected.cpsr) {
            row_matches = false;
        }
        if (row_matches && actual.spsr != expected.spsr) {
            row_matches = false;
        }

        uint32_t pc = actual.r[15];

        // ARM pipeline:
        // PC points 8 bytes ahead → instruction being executed is at PC - 8
        uint32_t instr_addr_exec = pc - 8;
        uint32_t instr_addr_fetch = pc - 4;

        uint32_t instr_exec = read_u32_mem(harness, instr_addr_exec);
        uint32_t instr_fetch = read_u32_mem(harness, instr_addr_fetch);

        auto decoded_exec = DecodeARMInstruction(instr_exec);
        auto decoded_fetch = DecodeARMInstruction(instr_fetch);

        std::cout << ANSI_DIM << "---- Instruction Debug ----\n"
                  << ANSI_RESET;

        std::cout << "PC            = " << hex32(pc) << "\n";
        std::cout << "Exec Addr     = " << hex32(instr_addr_exec)
                  << " Instr=" << hex32(instr_exec)
                  << " Type=" << ToString(decoded_exec) << "\n";

        std::cout << "Fetch Addr    = " << hex32(instr_addr_fetch)
                  << " Instr=" << hex32(instr_fetch)
                  << " Type=" << ToString(decoded_fetch) << "\n";

        std::cout << ANSI_DIM << "----------------------------\n"
                  << ANSI_RESET;

        if (!row_matches) {
            print_debug_mismatch(last_good, expected, actual);
        }

        for (int i = 0; i < 15; i++) {
            EXPECT_EQ(actual.r[i], expected.r[i])
                << "Step " << step_index
                << " r" << i
                << " expected=" << hex32(expected.r[i])
                << " actual=" << hex32(actual.r[i]);
        }

        EXPECT_EQ(actual.r[15] - 4, expected.r[15])
            << "Step " << step_index
            << " r15"
            << " expected=" << hex32(expected.r[15])
            << " actual=" << hex32(actual.r[15] - 4);

        EXPECT_EQ(actual.cpsr, expected.cpsr)
            << "Step " << step_index << " CPSR";

        EXPECT_EQ(actual.spsr, expected.spsr)
            << "Step " << step_index << " SPSR";

        if (::testing::Test::HasFailure()) {
            break;
        }

        last_good = expected;
        step_index++;
    }

    // std::string stdout_output = testing::internal::GetCapturedStdout();
    // std::string stderr_output = testing::internal::GetCapturedStderr();

    std::cout << "Validated " << step_index << " steps\n";
}