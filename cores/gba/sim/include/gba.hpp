#pragma once

#include <VGameboyAdvance.h>
#include <VGameboyAdvance___024root.h>
#include <array>
#include <memory>
#include <optional>
#include <utility>
#include <verilated.h>

#include <filesystem>
#include <fstream>

#include "types.hpp"

#include <verilated_vcd_c.h>

struct ArmTraceState {
    std::array<u32, 16> r {}; // r0-r15
    u32 cpsr = 0;
    u32 spsr = 0;
};

class GameboyAdvanceHarness {
private:
    struct ARM7TMDI {
    private:
        VGameboyAdvance_cpu_regs_t__struct__0& cpu_regs;

    public:
        ARM7TMDI(VGameboyAdvance& top) :
            cpu_regs(top.rootp->GameboyAdvance__DOT__cpu_inst__DOT__regs) { }

        // u8& get_A() { return cpu_regs.__PVT__a; }
        // u8& get_F() { return cpu_regs.__PVT__flags; }
        // u8& get_B() { return cpu_regs.__PVT__b; }
        // u8& get_C() { return cpu_regs.__PVT__c; }
        // u8& get_D() { return cpu_regs.__PVT__d; }
        // u8& get_E() { return cpu_regs.__PVT__e; }
        // u8& get_H() { return cpu_regs.__PVT__h; }
        // u8& get_L() { return cpu_regs.__PVT__l; }
        // u8& get_W() { return cpu_regs.__PVT__w; }
        // u8& get_Z() { return cpu_regs.__PVT__z; }
        // u16 get_SP() { return (static_cast<u16>(cpu_regs.__PVT__sph) << 8) | cpu_regs.__PVT__spl; }
        // u16 get_PC() { return static_cast<u16>(cpu_regs.__PVT__pch) << 8 | cpu_regs.__PVT__pcl; }

        // u8 get_opcode() { return cpu_regs.__PVT__IR; }
    };

public:
    enum class LogLevel {
        None,
        Error,
        Warn,
        Info,
        Trace,
    };

    struct Options {
        bool skip_boot_rom = false;
        bool waveform = false;
        LogLevel log_level = LogLevel::None;
        std::filesystem::path wave_path = "wave.vcd";

        Options() = default;

        // Preserve the existing test-harness construction style. Supplying a
        // waveform path explicitly means waveform generation is requested.
        Options(bool skip_boot_rom, std::filesystem::path wave_path) :
            skip_boot_rom(skip_boot_rom),
            waveform(true),
            wave_path(std::move(wave_path)) { }
    };

    GameboyAdvanceHarness() :
        options() {
        options.skip_boot_rom = true;
    };

    GameboyAdvanceHarness(Options options) :
        options(options) { }

    std::optional<ARM7TMDI> cpu;

    /// Sets up the Gameboy with the given ROM.
    bool setup(const std::filesystem::path& rom_path);

    /// Advances the simulation by one tick (clock).
    bool tick();

    bool half_tick();

    /// Advance the simulation by one SM83 instruction.
    bool step();

    /// Runs the Gameboy until completion.
    bool run();

    /// Reads a byte from the Gameboy's memory.
    u8 read_memory(u32 addr) const;

    /// Return true if we are at the beginning of an instruction.
    bool began_instruction() const;

    ArmTraceState capture_arm_state() const;

    /// API is subject to change
    VGameboyAdvance& get_top() {
        return *top;
    }

private:
    VerilatedContext ctx;
    std::unique_ptr<VerilatedVcdC> tfp;

    std::unique_ptr<VGameboyAdvance> top;

    u64 cycles = 0;

    /// Loads a ROM into the Gameboy's memory.
    bool load_rom(const std::filesystem::path& filename);

    void set_initial_state();

    Options options;

    // Trace log file that we output to if enabled.
    std::ofstream trace;

    void load_bios(const std::filesystem::path& filename);
};
