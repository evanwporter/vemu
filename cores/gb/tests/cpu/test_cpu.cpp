#include <filesystem>
#include <fstream>
#include <gtest/gtest.h>
#include <nlohmann/json.hpp>

#include <Vcpu_top.h>
#include <Vcpu_top_GB_Bus_if.h>
#include <Vcpu_top___024root.h>
#include <verilated.h>

#include "test_cpu.hpp"

using namespace std;
namespace fs = std::filesystem;
using json = nlohmann::json;

using u8 = uint8_t;
using u16 = uint16_t;

static const fs::path kTestDir = fs::path(TEST_DIR) / "GameboyCPUTests/v2";
static const fs::path kCBTestDir = fs::path(TEST_DIR) / "GameboyCPUTests/v2/cb";

static inline u16 get_u16(u8 hi, u8 lo) {
    return static_cast<u16>((hi << 8) | lo);
}

static inline void set_u16(u8& hi, u8& lo, u16 val) {
    hi = static_cast<u8>(val >> 8);
    lo = static_cast<u8>(val & 0xFF);
}

static inline u8 read_u8(const json& j) {
    if (j.is_string()) {
        return static_cast<u8>(std::stoul(j.get<std::string>(), nullptr, 16));
    }
    return j.get<u8>();
}

static inline u16 read_u16(const json& j) {
    if (j.is_string()) {
        return static_cast<u16>(std::stoul(j.get<std::string>(), nullptr, 16));
    }
    return j.get<u16>();
}

static void dump_gd_trace(Vcpu_top& top, std::ostream& os) {
    static int line_count = 0;

    auto& regs = top.rootp->cpu_top__DOT__cpu_inst__DOT__regs;
    auto& mem = top.rootp->cpu_top__DOT__mmu_inst__DOT__memory;

    u8 A = regs.__PVT__a;
    u8 F = regs.__PVT__flags;
    u8 B = regs.__PVT__b;
    u8 C = regs.__PVT__c;
    u8 D = regs.__PVT__d;
    u8 E = regs.__PVT__e;
    u8 H = regs.__PVT__h;
    u8 L = regs.__PVT__l;

    u16 PC = (regs.__PVT__pch << 8) | regs.__PVT__pcl;
    u16 SP = (regs.__PVT__sph << 8) | regs.__PVT__spl;

    u8 IR = regs.__PVT__IR;

    u8 pcm0 = mem[PC - 1];
    u8 pcm1 = mem[PC];
    u8 pcm2 = mem[PC + 1];
    u8 pcm3 = mem[PC + 2];

    // Ensure hex, uppercase, zero-padded
    os << std::uppercase << std::hex << std::setfill('0');

    // clang-format off
    os << "A:"  << std::setw(2) << static_cast<int>(A)
       << " F:" << std::setw(2) << static_cast<int>(F)
       << " B:" << std::setw(2) << static_cast<int>(B)
       << " C:" << std::setw(2) << static_cast<int>(C)
       << " D:" << std::setw(2) << static_cast<int>(D)
       << " E:" << std::setw(2) << static_cast<int>(E)
       << " H:" << std::setw(2) << static_cast<int>(H)
       << " L:" << std::setw(2) << static_cast<int>(L)
       << " SP:" << std::setw(4) << static_cast<int>(SP)
       << " PC:" << std::setw(4) << static_cast<int>(PC - 1)
       << " PCMEM:"
       << std::setw(2) << static_cast<int>(pcm0) << ","
       << std::setw(2) << static_cast<int>(pcm1) << ","
       << std::setw(2) << static_cast<int>(pcm2) << ","
       << std::setw(2) << static_cast<int>(pcm3)
       << "\n";
    // clang-format on

    if (++line_count >= 100) {
        os.flush();
        line_count = 0;
    }
}

static void tick(Vcpu_top& top, VerilatedContext& ctx) {
    top.clk = 0;
    top.eval();
    ctx.timeInc(5);

    top.clk = 1;
    top.eval();
    ctx.timeInc(5);
}

static void apply_ram(Vcpu_top& gb, VerilatedContext& ctx, const json& ramList) {
    for (const auto& pair : ramList) {
        u16 addr = read_u16(pair[0]);
        u8 val = read_u8(pair[1]);
        auto& mem = gb.rootp->cpu_top__DOT__mmu_inst__DOT__memory;
        mem[addr] = val;
    }
}

static void verify_ram(Vcpu_top& gb, VerilatedContext& ctx, const json& ramList, const std::string& test_name) {
    for (const auto& pair : ramList) {
        u16 addr = read_u16(pair[0]);
        u8 expected = read_u8(pair[1]);
        auto& mem = gb.rootp->cpu_top__DOT__mmu_inst__DOT__memory;
        u8 actual = mem[addr];
        ASSERT_EQ(actual, expected)
            << "RAM mismatch at 0x" << std::hex << addr
            << " during test \"" << test_name << "\"";
    }
}

static void apply_initial_state(Vcpu_top& gb, VerilatedContext& ctx, const json& init) {
    auto* regs = &gb.rootp->cpu_top__DOT__cpu_inst__DOT__regs;

    if (init.contains("a"))
        regs->__PVT__a = read_u8(init["a"]);
    if (init.contains("b"))
        regs->__PVT__b = read_u8(init["b"]);
    if (init.contains("c"))
        regs->__PVT__c = read_u8(init["c"]);
    if (init.contains("d"))
        regs->__PVT__d = read_u8(init["d"]);
    if (init.contains("e"))
        regs->__PVT__e = read_u8(init["e"]);
    if (init.contains("f"))
        regs->__PVT__flags = read_u8(init["f"]);
    if (init.contains("h"))
        regs->__PVT__h = read_u8(init["h"]);
    if (init.contains("l"))
        regs->__PVT__l = read_u8(init["l"]);
    if (init.contains("sp")) {
        u16 sp = read_u16(init["sp"]);
        set_u16(regs->__PVT__sph, regs->__PVT__spl, sp);
    }
    if (init.contains("pc")) {
        u16 pc = read_u16(init["pc"]) - 1;
        set_u16(regs->__PVT__pch, regs->__PVT__pcl, pc);
    }

    apply_ram(gb, ctx, init["ram"]);
}

static void verify_registers(const Vcpu_top& top, const json& expected, const std::string& test_name) {
    auto* regs = &top.rootp->cpu_top__DOT__cpu_inst__DOT__regs;

    EXPECT_EQ(regs->__PVT__a, read_u8(expected["a"])) << "Test: " << test_name;
    EXPECT_EQ(regs->__PVT__b, read_u8(expected["b"])) << "Test: " << test_name;
    EXPECT_EQ(regs->__PVT__c, read_u8(expected["c"])) << "Test: " << test_name;
    EXPECT_EQ(regs->__PVT__d, read_u8(expected["d"])) << "Test: " << test_name;
    EXPECT_EQ(regs->__PVT__e, read_u8(expected["e"])) << "Test: " << test_name;
    EXPECT_EQ(regs->__PVT__flags, read_u8(expected["f"])) << "Test: " << test_name;
    EXPECT_EQ(regs->__PVT__h, read_u8(expected["h"])) << "Test: " << test_name;
    EXPECT_EQ(regs->__PVT__l, read_u8(expected["l"])) << "Test: " << test_name;
    EXPECT_EQ(get_u16(regs->__PVT__sph, regs->__PVT__spl), read_u16(expected["sp"]))
        << "Test: " << test_name;
    EXPECT_EQ(get_u16(regs->__PVT__pch, regs->__PVT__pcl), read_u16(expected["pc"]))
        << "Test: " << test_name;
}

static void run_single_file(const fs::path& path) {

    std::ifstream f(path);
    ASSERT_TRUE(f.is_open()) << "Failed to open test file: " << path;

    json testFile;
    f >> testFile;
    ASSERT_TRUE(testFile.is_array());

    for (const auto& testCase : testFile) {
        static const fs::path trace_log_path = fs::current_path() / "trace.log";

        std::ofstream trace(trace_log_path, std::ios::trunc);
        if (!trace.is_open()) {
            std::cerr << "[Error] Unable to open trace.log\n";
            return;
        }

        VerilatedContext ctx;
        ctx.debug(0);
        ctx.time(0);

        Vcpu_top top(&ctx);

        top.reset = 1;
        for (int i = 0; i < 4; ++i)
            tick(top, ctx);
        top.reset = 0;

        apply_initial_state(top, ctx, testCase["initial"]);

        dump_gd_trace(top, trace);

        for (int t = 0; t < 4; ++t)
            tick(top, ctx);

        int max_ticks = 100;
        while (top.rootp->cpu_top__DOT__cpu_inst__DOT__instr_boundary == 0 && max_ticks-- > 0) {
            tick(top, ctx);
        }

        dump_gd_trace(top, trace);

        top.rootp->cpu_top__DOT__cpu_inst__DOT__instr_boundary = 0;

        while (top.rootp->cpu_top__DOT__cpu_inst__DOT__instr_boundary == 0 && max_ticks-- > 0) {
            tick(top, ctx);
        }

        dump_gd_trace(top, trace);

        ASSERT_GT(max_ticks, 0) << "Timed out waiting for instruction to finish";

        const std::string test_name = testCase["name"].get<std::string>();

        verify_registers(top, testCase["final"], test_name);
        verify_ram(top, ctx, testCase["final"]["ram"], test_name);

        if (::testing::Test::HasFailure()) {
            break;
        }
    }
}

void run_gameboy_cpu_test_file(std::string_view filename) {
    run_single_file(kTestDir / filename);
}

void run_gameboy_cb_cpu_test_file(std::string_view filename) {
    run_single_file(kCBTestDir / filename);
}
