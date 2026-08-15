#pragma once

#include <array>
#include <filesystem>
#include <functional>
#include <memory>
#include <optional>
#include <string>
#include <vector>

#include <gtest/gtest.h>

#include "gba.hpp"

#include <nba/config.hpp>
#include <nba/core.hpp>
#include <nba/rom/rom.hpp>
#include <nba/src/core.hpp>

namespace vemu::gba::test {

    namespace fs = std::filesystem;

    std::vector<u8> ReadFile(const fs::path& path);
    uint32_t read_u32_mem(const GameboyAdvanceHarness& harness, uint32_t address);
    u32 read_u16_mem(const GameboyAdvanceHarness& harness, uint32_t address);

    struct TraceRow {
        std::array<uint32_t, 16> r { };
        uint32_t cpsr = 0;
        uint32_t spsr = 0;
        size_t step_index = 0;
    };

    std::string format_row_plain(const TraceRow& row, bool pc_minus_4 = false);
    void print_debug_mismatch(const std::optional<TraceRow>& last_good, const TraceRow& expected, const TraceRow& actual);

    struct NbaOracle {
        std::shared_ptr<nba::Config> config;
        std::unique_ptr<nba::CoreBase> core;
        nba::core::Core* impl = nullptr;
    };

    NbaOracle CreateNbaOracle(const fs::path& rom_path, const std::optional<fs::path>& bios_path = std::nullopt);
    TraceRow capture_nba_state(nba::core::Core* core, size_t step_index);
    TraceRow capture_dut_state(GameboyAdvanceHarness& harness, size_t step_index);
    void compare_states(const TraceRow& expected, const TraceRow& actual, const std::optional<TraceRow>& last_good);

    struct InstructionTestConfig {
        std::string name; // "arm" or "thumb"
        std::string rom_rel_path; // "gba-tests/arm/arm.gba"
        size_t end_step_index; // 1331 or 791

        // Optional step hook for CPU-specific hacks or display triggers
        std::function<bool(GameboyAdvanceHarness&, size_t step_index)> step_hook;
    };

    void RunCpuInstructionTest(const InstructionTestConfig& config);

} // namespace vemu::gba::test
