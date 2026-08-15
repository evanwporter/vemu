#pragma once

#include <array>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <memory>
#include <optional>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

#include <gtest/gtest.h>

#include "gba.hpp"
#include "util/util.hpp"

#include <nba/config.hpp>
#include <nba/core.hpp>
#include <nba/rom/rom.hpp>
#include <nba/src/core.hpp>

namespace vemu::gba::test {

    namespace fs = std::filesystem;

    inline std::vector<u8> ReadFile(const fs::path& path) {
        std::ifstream file(path, std::ios::binary);
        if (!file)
            throw std::runtime_error("Failed to open file: " + path.string());

        file.seekg(0, std::ios::end);
        const size_t size = static_cast<size_t>(file.tellg());
        file.seekg(0, std::ios::beg);

        std::vector<u8> data(size);
        file.read(reinterpret_cast<char*>(data.data()), static_cast<std::streamsize>(size));
        if (!file)
            throw std::runtime_error("Failed to read file: " + path.string());
        return data;
    }

    inline uint32_t read_u32_mem(const GameboyAdvanceHarness& harness, uint32_t address) {
        return static_cast<uint32_t>(harness.read_memory(address))
            | (static_cast<uint32_t>(harness.read_memory(address + 1)) << 8)
            | (static_cast<uint32_t>(harness.read_memory(address + 2)) << 16)
            | (static_cast<uint32_t>(harness.read_memory(address + 3)) << 24);
    }

    inline u32 read_u16_mem(const GameboyAdvanceHarness& harness, uint32_t address) {
        return static_cast<u32>(harness.read_memory(address))
            | (static_cast<u32>(harness.read_memory(address + 1)) << 8);
    }

    struct TraceRow {
        std::array<uint32_t, 16> r { };
        uint32_t cpsr = 0;
        uint32_t spsr = 0;
        size_t step_index = 0;
    };

    inline std::string format_row_plain(const TraceRow& row, bool pc_minus_4 = false) {
        std::ostringstream oss;
        oss << "step " << row.step_index << "  ";
        for (int i = 0; i < 16; ++i) {
            uint32_t value = row.r[i];
            if (pc_minus_4 && i == 15)
                value -= 4;
            oss << "r" << std::dec << i << "=" << hex32(value);
            if (i != 15)
                oss << " ";
        }
        oss << " cpsr=" << hex32(row.cpsr) << " spsr=" << hex32(row.spsr);
        return oss.str();
    }

    inline void print_debug_mismatch(const std::optional<TraceRow>& last_good, const TraceRow& expected, const TraceRow& actual) {
        std::cout << "\n================ TRACE DEBUG ================\n"
                  << "Last matching:\n  "
                  << (last_good ? format_row_plain(*last_good) : "<none>")
                  << "\nExpected:\n  " << format_row_plain(expected)
                  << "\nActual:\n  " << format_row_plain(actual)
                  << "\n=============================================\n\n";
    }

    struct NbaOracle {
        std::shared_ptr<nba::Config> config;
        std::unique_ptr<nba::CoreBase> core;
        nba::core::Core* impl = nullptr;
    };

    inline NbaOracle CreateNbaOracle(const fs::path& rom_path, const std::optional<fs::path>& bios_path = std::nullopt) {
        NbaOracle oracle;
        oracle.config = std::make_shared<nba::Config>();
        oracle.config->skip_bios = true;
        oracle.core = nba::CreateCore(oracle.config);
        oracle.impl = static_cast<nba::core::Core*>(oracle.core.get());

        if (bios_path)
            oracle.core->Attach(ReadFile(*bios_path));

        oracle.core->Attach(nba::ROM(ReadFile(rom_path), nullptr, nullptr));
        oracle.core->Reset();
        return oracle;
    }

    inline TraceRow capture_nba_state(nba::core::Core* core, size_t step_index) {
        TraceRow row { };
        row.step_index = step_index;
        auto& state = core->GetCPU().state;
        row.r = { state.r0, state.r1, state.r2, state.r3, state.r4, state.r5, state.r6, state.r7, state.r8, state.r9, state.r10, state.r11, state.r12, state.r13, state.r14, state.r15 };
        row.cpsr = state.cpsr.v;
        row.spsr = state.spsr[0].v;
        return row;
    }

    inline TraceRow capture_dut_state(GameboyAdvanceHarness& harness, size_t step_index) {
        TraceRow row { };
        row.step_index = step_index;
        const ArmTraceState state = harness.capture_arm_state();
        row.r = state.r;
        row.cpsr = state.cpsr;
        row.spsr = state.spsr;
        return row;
    }

    inline void compare_states(const TraceRow& expected, const TraceRow& actual, const std::optional<TraceRow>& last_good) {
        for (int i = 0; i < 16; ++i) {
            EXPECT_EQ(actual.r[i], expected.r[i])
                << "Step " << expected.step_index << " r" << i
                << " expected=" << hex32(expected.r[i])
                << " actual=" << hex32(actual.r[i]);
        }
        EXPECT_EQ(actual.cpsr, expected.cpsr)
            << "Step " << expected.step_index
            << " CPSR expected=" << hex32(expected.cpsr)
            << " actual=" << hex32(actual.cpsr);

        if (::testing::Test::HasFailure())
            print_debug_mismatch(last_good, expected, actual);
    }

} // namespace vemu::gba::test
