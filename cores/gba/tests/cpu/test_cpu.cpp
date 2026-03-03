#include <filesystem>
#include <fstream>
#include <gtest/gtest.h>
#include <nlohmann/json.hpp>

#include <Varm_cpu_top.h>
#include <Varm_cpu_top_GBA_Bus_if.h>
#include <Varm_cpu_top___024root.h>
#include <verilated.h>

#include "util/test_config.hpp"
#include "util/util.hpp"

#include "json_parser.hpp"

using namespace std;
namespace fs = std::filesystem;
using json = nlohmann::json;

using u8 = uint8_t;
using u16 = uint16_t;

static const fs::path kTestDir = fs::path(TEST_DIR) / "GameboyAdvanceCPUTests/v1";

class TestLogger {
    const fs::path log_path = fs::current_path() / "failed_test.log";

    const json& testCase;

    static void dump_failed_test_to_file(const json& test) {
        fs::path out = fs::current_path() / "failed_test.json";

        std::ofstream f(out);
        if (!f.is_open())
            return;

        f << test.dump(2);
        f << std::endl;

        std::cerr << "Wrote failing test to: " << out.string() << "\n";
    }

public:
    TestLogger(const json& testCase) :
        testCase(testCase) {
        testing::internal::CaptureStdout();
        testing::internal::CaptureStderr();
    };

    ~TestLogger() {
        std::string stdout_output = testing::internal::GetCapturedStdout();
        std::string stderr_output = testing::internal::GetCapturedStderr();

        if (::testing::Test::HasFailure() || ::testing::Test::HasFatalFailure()) {
            std::cerr << "\n==== Captured stdout ====\n"
                      << stdout_output
                      << "\n==== Captured stderr ====\n"
                      << stderr_output;

            std::ofstream log_file(log_path);
            log_file << "==== Captured stdout ====\n"
                     << stdout_output
                     << "\n==== Captured stderr ====\n"
                     << stderr_output;
            log_file.close();

            std::cout << "Wrote logs to: " << log_path.string() << "\n";

            dump_failed_test_to_file(testCase);
        }
    }

    TestLogger(TestLogger&&) = delete;
    TestLogger(const TestLogger&) = delete;
    TestLogger& operator=(const TestLogger&) = delete;
    TestLogger& operator=(TestLogger&&) = delete;
};

static fs::path get_test_dir() {
    if (test_config().test_dir.has_value()) {
        return test_config().test_dir.value() / "GameboyAdvanceCPUTests/v1";
    }
    return kTestDir;
}

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

template <typename T>
static inline bool get_bit(const T value, const unsigned bit) {
    return static_cast<bool>((value >> bit) & 1u);
}

static inline u16 read_u16(const json& j) {
    if (j.is_string()) {
        return static_cast<u16>(std::stoul(j.get<std::string>(), nullptr, 16));
    }
    return j.get<u16>();
}

static void tick(Varm_cpu_top& top, VerilatedContext& ctx) {
    std::cout << "PC: "
              << top.rootp->arm_cpu_top__DOT__cpu_inst__DOT__regs
                     .__PVT__user.__PVT__r15
              << std::endl;

    top.clk = 0;
    top.eval();
    ctx.timeInc(5);

    top.clk = 1;
    top.eval();
    ctx.timeInc(5);
}

static bool apply_instruction_memory(Varm_cpu_top& top, const json& test) {
    auto& memory = top.rootp->arm_cpu_top__DOT__mmu_inst__DOT__memory;

    const uint32_t base_addr = test["base_addr"].get<uint32_t>();

    top.rootp->arm_cpu_top__DOT__mmu_inst__DOT__opcode = test["opcode"];
    top.rootp->arm_cpu_top__DOT__mmu_inst__DOT__base_addr = test["base_addr"];

    std::unordered_map<uint32_t, uint32_t> seen;

    // First transaction is the instruction fetch.
    // EXPECT_EQ(test["transactions"][0]["data"].get<uint32_t>(), test["opcode"].get<uint32_t>());

    for (size_t i = 0; i < test["transactions"].size(); i++) {
        const uint32_t addr = test["transactions"][i]["addr"].get<uint32_t>();
        const uint32_t data = test["transactions"][i]["data"].get<uint32_t>();

        if (test["transactions"][i]["kind"].get<int>() == 1) { // general read
            if (addr == base_addr)
                // Skip this test since a read operation and the instruction fetch are colliding,
                // which our test framework doesn't currently support.
                return false;
            memory.set(addr, data);
        }
    }

    std::cout << "Initial memory state:" << std::endl;
    for (size_t i = 0; i < test["transactions"].size(); i++) {
        const uint32_t addr = test["transactions"][i]["addr"].get<uint32_t>();
        const uint32_t data = test["transactions"][i]["data"].get<uint32_t>();

        std::cout << "  [" << addr << "] = " << data << std::endl;
    }
    return true;
}

static bool apply_initial_state(Varm_cpu_top& top, const json& test, const bool thumb_mode) {
    auto& regs = top.rootp->arm_cpu_top__DOT__cpu_inst__DOT__regs;

    const auto& init = test["initial"];

    // R0–R7
    regs.__PVT__common.__PVT__r0 = init["R"][0];
    regs.__PVT__common.__PVT__r1 = init["R"][1];
    regs.__PVT__common.__PVT__r2 = init["R"][2];
    regs.__PVT__common.__PVT__r3 = init["R"][3];
    regs.__PVT__common.__PVT__r4 = init["R"][4];
    regs.__PVT__common.__PVT__r5 = init["R"][5];
    regs.__PVT__common.__PVT__r6 = init["R"][6];
    regs.__PVT__common.__PVT__r7 = init["R"][7];

    // R8–R14 (user bank)
    regs.__PVT__user.__PVT__r8 = init["R"][8];
    regs.__PVT__user.__PVT__r9 = init["R"][9];
    regs.__PVT__user.__PVT__r10 = init["R"][10];
    regs.__PVT__user.__PVT__r11 = init["R"][11];
    regs.__PVT__user.__PVT__r12 = init["R"][12];
    regs.__PVT__user.__PVT__r13 = init["R"][13];
    regs.__PVT__user.__PVT__r14 = init["R"][14];

    if (thumb_mode)
        regs.__PVT__user.__PVT__r15 = init["R"][15].get<uint32_t>() - 4;
    else
        regs.__PVT__user.__PVT__r15 = init["R"][15].get<uint32_t>() - 8;

    regs.__PVT__CPSR = init["CPSR"];

    regs.__PVT__fiq.__PVT__r8 = init["R_fiq"][0];
    regs.__PVT__fiq.__PVT__r9 = init["R_fiq"][1];
    regs.__PVT__fiq.__PVT__r10 = init["R_fiq"][2];
    regs.__PVT__fiq.__PVT__r11 = init["R_fiq"][3];
    regs.__PVT__fiq.__PVT__r12 = init["R_fiq"][4];
    regs.__PVT__fiq.__PVT__r13 = init["R_fiq"][5];
    regs.__PVT__fiq.__PVT__r14 = init["R_fiq"][6];

    regs.__PVT__abort.__PVT__r13 = init["R_abt"][0];
    regs.__PVT__abort.__PVT__r14 = init["R_abt"][1];

    regs.__PVT__irq.__PVT__r13 = init["R_irq"][0];
    regs.__PVT__irq.__PVT__r14 = init["R_irq"][1];

    regs.__PVT__supervisor.__PVT__r13 = init["R_svc"][0];
    regs.__PVT__supervisor.__PVT__r14 = init["R_svc"][1];

    regs.__PVT__undefined.__PVT__r13 = init["R_und"][0];
    regs.__PVT__undefined.__PVT__r14 = init["R_und"][1];

    regs.__PVT__SPSR.__PVT__fiq = init["SPSR"][0];
    regs.__PVT__SPSR.__PVT__supervisor = init["SPSR"][1];
    regs.__PVT__SPSR.__PVT__abort = init["SPSR"][2];
    regs.__PVT__SPSR.__PVT__irq = init["SPSR"][3];
    regs.__PVT__SPSR.__PVT__undefined = init["SPSR"][4];

    return apply_instruction_memory(top, test);
}

static void check_cpsr(const string& test_name, const Varm_cpu_top_cpu_regs_t__struct__0& regs, const json& expected, uint32_t flag_mask) {
    uint32_t actual = regs.__PVT__CPSR;
    uint32_t exp = expected["CPSR"];

    actual &= flag_mask;
    exp &= flag_mask;

    if (actual != exp) {
        auto flag = [](uint32_t v, int bit) {
            return (v >> bit) & 1;
        };

        std::stringstream ss;

        ss << "\n===== CPSR MISMATCH (Test " << test_name << ")=====\n";
        ss << "Actual   : " << actual << "\n";
        ss << "Expected : " << exp << "\n";
        ss << "Diff     : " << (actual ^ exp) << "\n\n";

        ss << "Flags:\n";
        ss << "  N: " << flag(actual, 31) << " (exp " << flag(exp, 31) << ")\n";
        ss << "  Z: " << flag(actual, 30) << " (exp " << flag(exp, 30) << ")\n";
        ss << "  C: " << flag(actual, 29) << " (exp " << flag(exp, 29) << ")\n";
        ss << "  V: " << flag(actual, 28) << " (exp " << flag(exp, 28) << ")\n";
        ss << "  Q: " << flag(actual, 27) << " (exp " << flag(exp, 27) << ")\n";

        ss << "\nControl bits:\n";
        ss << "  I (IRQ disable): " << flag(actual, 7)
           << " (exp " << flag(exp, 7) << ")\n";
        ss << "  F (FIQ disable): " << flag(actual, 6)
           << " (exp " << flag(exp, 6) << ")\n";
        ss << "  T (Thumb)      : " << flag(actual, 5)
           << " (exp " << flag(exp, 5) << ")\n";

        ss << "\nMode:\n";
        ss << "  Actual mode    : 0x" << std::hex << (actual & 0x1F) << "\n";
        ss << "  Expected mode  : 0x" << std::hex << (exp & 0x1F) << "\n";

        ss << "==========================\n";

        FAIL() << ss.str();
    }
}

static void verify_registers(
    const Varm_cpu_top& top,
    const json& expected,
    const std::string& test_name,
    const uint32_t flag_mask) {
    const auto& regs = top.rootp->arm_cpu_top__DOT__cpu_inst__DOT__regs;

#define CHECK_REG(actual, exp, name) \
    ASSERT_EQ((actual), (exp))       \
        << name << " mismatch in test " << test_name;

    CHECK_REG(regs.__PVT__common.__PVT__r0, expected["R"][0], "R0");
    CHECK_REG(regs.__PVT__common.__PVT__r1, expected["R"][1], "R1");
    CHECK_REG(regs.__PVT__common.__PVT__r2, expected["R"][2], "R2");
    CHECK_REG(regs.__PVT__common.__PVT__r3, expected["R"][3], "R3");
    CHECK_REG(regs.__PVT__common.__PVT__r4, expected["R"][4], "R4");
    CHECK_REG(regs.__PVT__common.__PVT__r5, expected["R"][5], "R5");
    CHECK_REG(regs.__PVT__common.__PVT__r6, expected["R"][6], "R6");
    CHECK_REG(regs.__PVT__common.__PVT__r7, expected["R"][7], "R7");

    CHECK_REG(regs.__PVT__user.__PVT__r8, expected["R"][8], "R8 (user)");
    CHECK_REG(regs.__PVT__user.__PVT__r9, expected["R"][9], "R9 (user)");
    CHECK_REG(regs.__PVT__user.__PVT__r10, expected["R"][10], "R10 (user)");
    CHECK_REG(regs.__PVT__user.__PVT__r11, expected["R"][11], "R11 (user)");
    CHECK_REG(regs.__PVT__user.__PVT__r12, expected["R"][12], "R12 (user)");
    CHECK_REG(regs.__PVT__user.__PVT__r13, expected["R"][13], "R13/SP (user)");
    CHECK_REG(regs.__PVT__user.__PVT__r14, expected["R"][14], "R14/LR (user)");
    CHECK_REG(regs.__PVT__user.__PVT__r15, expected["R"][15], "R15/PC");

    CHECK_REG(regs.__PVT__fiq.__PVT__r8, expected["R_fiq"][0], "R8_fiq");
    CHECK_REG(regs.__PVT__fiq.__PVT__r9, expected["R_fiq"][1], "R9_fiq");
    CHECK_REG(regs.__PVT__fiq.__PVT__r10, expected["R_fiq"][2], "R10_fiq");
    CHECK_REG(regs.__PVT__fiq.__PVT__r11, expected["R_fiq"][3], "R11_fiq");
    CHECK_REG(regs.__PVT__fiq.__PVT__r12, expected["R_fiq"][4], "R12_fiq");
    CHECK_REG(regs.__PVT__fiq.__PVT__r13, expected["R_fiq"][5], "R13_fiq");
    CHECK_REG(regs.__PVT__fiq.__PVT__r14, expected["R_fiq"][6], "R14_fiq");

    CHECK_REG(regs.__PVT__abort.__PVT__r13, expected["R_abt"][0], "R13_abt");
    CHECK_REG(regs.__PVT__abort.__PVT__r14, expected["R_abt"][1], "R14_abt");

    CHECK_REG(regs.__PVT__irq.__PVT__r13, expected["R_irq"][0], "R13_irq");
    CHECK_REG(regs.__PVT__irq.__PVT__r14, expected["R_irq"][1], "R14_irq");

    CHECK_REG(regs.__PVT__supervisor.__PVT__r13, expected["R_svc"][0], "R13_svc");
    CHECK_REG(regs.__PVT__supervisor.__PVT__r14, expected["R_svc"][1], "R14_svc");

    CHECK_REG(regs.__PVT__undefined.__PVT__r13, expected["R_und"][0], "R13_und");
    CHECK_REG(regs.__PVT__undefined.__PVT__r14, expected["R_und"][1], "R14_und");

    check_cpsr(test_name, regs, expected, flag_mask);

#undef CHECK_REG
}

static void verify_memory_writes(
    const Varm_cpu_top& top,
    const json& testCase,
    const std::string& test_name) {
    const auto& memory = top.rootp->arm_cpu_top__DOT__mmu_inst__DOT__memory;

    for (const auto& tx : testCase["transactions"]) {
        if (tx["kind"].get<int>() == 2) { // write
            uint32_t addr = tx["addr"].get<uint32_t>();
            uint32_t expected = tx["data"].get<uint32_t>();

            EXPECT_TRUE(memory.exists(addr))
                << "Memory write missing at addr=" << addr
                << " in test " << test_name;

            uint32_t actual = memory.at(addr);

            EXPECT_EQ(actual, expected)
                << "Memory mismatch at addr=" << addr
                << " in test " << test_name;
        }
    }
}

static inline uint32_t arm_mul_rd(uint32_t ir) {
    // Rd is bits [19:16]
    return (ir >> 16) & 0xF;
}

static inline uint32_t arm_mul_rs(uint32_t ir) {
    // Rs is bits [11:8]
    return (ir >> 8) & 0xF;
}

static inline uint32_t arm_rm(uint32_t ir) {
    // Rs is bits [3:0]
    return (ir >> 0) & 0xF;
}

static inline uint32_t arm_swp_rn(uint32_t ir) {
    // Rs is bits [19:16]
    return (ir >> 16) & 0xF;
}

static inline uint32_t arm_swp_rd(uint32_t ir) {
    // Rs is bits [19:16]
    return (ir >> 12) & 0xF;
}

static void run_single_test(const json& testCase, const fs::path& source, const size_t index) {

    TestLogger logger(testCase);

    constexpr uint32_t FULL_MASK = 0xFFFFFFFF;
    constexpr uint32_t IGNORE_C = ~(1u << 29);
    constexpr uint32_t IGNORE_V = ~(1u << 28);

    uint32_t flag_mask = FULL_MASK;

    // Skip known-bad case
    // TODO: Only skip MUL for thumb data proc
    if (source.filename() == "arm_mul_mla.json.bin" || source.filename() == "thumb_data_proc.json.bin") {
        const uint32_t opcode = testCase["opcode"].get<uint32_t>();
        if (arm_mul_rd(opcode) == 15 || arm_mul_rs(opcode) == 15 || arm_rm(opcode) == 15) {
            GTEST_SKIP() << "Skipping MUL/MLA with Rd==PC in arm_mul_mla.json.bin (test " << index << ")";
        }
        flag_mask = IGNORE_C;
    }

    if (source.filename() == "arm_swp.json.bin") {
        const uint32_t opcode = testCase["opcode"].get<uint32_t>();
        if (arm_swp_rd(opcode) == 15 || arm_swp_rn(opcode) == 15 || arm_rm(opcode) == 15) {
            GTEST_SKIP() << "Skipping SWP with Rd/Rn/Rm==PC in arm_swp.json.bin (test " << index << ")";
        }
    }

    VerilatedContext ctx;
    ctx.debug(0);
    ctx.time(0);

    Varm_cpu_top top(&ctx);

    std::cout << "Cycle 0: Reset Phase 1" << std::endl;

    // Reset
    top.reset = 1;
    tick(top, ctx);
    top.reset = 0;

    // If bit 5 (T) is 0, it's ARM mode; if it's 1, it's Thumb mode.
    const bool thumb_mode = get_bit(testCase["initial"]["CPSR"].get<uint32_t>(), 5);

    std::cout << "\nCycle 1: Reset Phase 2:" << std::endl;

    if (apply_initial_state(top, testCase, thumb_mode)) {

        ASSERT_EQ(top.rootp->arm_cpu_top__DOT__cpu_inst__DOT__controlUnit__DOT__flush_cnt, 3);

        // Fetch
        tick(top, ctx);

        std::cout << "\nCycle 2: Start flush" << std::endl;

        ASSERT_EQ(top.rootp->arm_cpu_top__DOT__cpu_inst__DOT__regs.__PVT__user.__PVT__r15, testCase["base_addr"]);

        // Check if it reset correctly and is now starting a flush.
        ASSERT_EQ(top.rootp->arm_cpu_top__DOT__cpu_inst__DOT__controlUnit__DOT__flush_cnt, 2);

        tick(top, ctx);

        const auto& IR = top.rootp->arm_cpu_top__DOT__cpu_inst__DOT__IR;

        // The IR should be latched
        ASSERT_EQ(IR, testCase["opcode"]);

        if (thumb_mode) // THUMB mode
            ASSERT_EQ(top.rootp->arm_cpu_top__DOT__cpu_inst__DOT__regs.__PVT__user.__PVT__r15, testCase["base_addr"].get<uint32_t>() + 2);
        else // ARM mode
            ASSERT_EQ(top.rootp->arm_cpu_top__DOT__cpu_inst__DOT__regs.__PVT__user.__PVT__r15, testCase["base_addr"].get<uint32_t>() + 4);

        ASSERT_EQ(top.rootp->arm_cpu_top__DOT__cpu_inst__DOT__controlUnit__DOT__flush_cnt, 1);

        std::cout << "\nCycle 3: Start flush and decode" << std::endl;

        // Fetch and Decode
        tick(top, ctx);

        if (thumb_mode) // THUMB mode
            ASSERT_EQ(top.rootp->arm_cpu_top__DOT__cpu_inst__DOT__regs.__PVT__user.__PVT__r15, testCase["base_addr"].get<uint32_t>() + 4);
        else // ARM mode
            ASSERT_EQ(top.rootp->arm_cpu_top__DOT__cpu_inst__DOT__regs.__PVT__user.__PVT__r15, testCase["base_addr"].get<uint32_t>() + 8);

        ASSERT_EQ(top.rootp->arm_cpu_top__DOT__cpu_inst__DOT__decoder_inst__DOT__IR, testCase["opcode"]);

        // Check if it flushed the reset correctly and is now ready to begin executing the instruction.
        ASSERT_EQ(top.rootp->arm_cpu_top__DOT__cpu_inst__DOT__controlUnit__DOT__flush_cnt, 0);

        const auto pipe1 = testCase["initial"]["pipeline"][1].get<uint32_t>();

        // Verify pipeline looks good
        ASSERT_EQ(top.rootp->arm_cpu_top__DOT__cpu_inst__DOT__decoder_inst__DOT__IR, testCase["initial"]["pipeline"][0])
            << "Pipeline stage 2 mismatch in test " << index
            << " where " << top.rootp->arm_cpu_top__DOT__cpu_inst__DOT__decoder_inst__DOT__IR << " != " << testCase["initial"]["pipeline"][0];

        top.rootp->arm_cpu_top__DOT__cpu_inst__DOT__instr_boundary = 0;

        int max_ticks = 40;
        int cycles = 0;
        while (top.rootp->arm_cpu_top__DOT__cpu_inst__DOT__instr_boundary == 0 && max_ticks-- > 0) {
            std::cout << "\nCycle " << (cycles + 4) << ": Execute" << std::endl;
            tick(top, ctx);
            cycles++;
        }

        ASSERT_GT(max_ticks, 0)
            << "Timeout in test " << index
            << " from " << source;

        if (top.rootp->arm_cpu_top__DOT__cpu_inst__DOT__flush_req) {
            std::cout << "\n2 cycles of flush remaining" << std::endl;
            tick(top, ctx);
            std::cout << "\n1 cycles of flush remaining" << std::endl;
            tick(top, ctx);
        }

        verify_registers(top, testCase["final"], std::to_string(index), flag_mask);
        verify_memory_writes(top, testCase, std::to_string(index));
    }
}

static void run_single_file(const fs::path& path) {
    TestStream stream(path.string());

    json testCase;
    std::size_t test_index = 0;

    while (stream.next(testCase)) {
        if (test_config().test_index.has_value()) {
            if (test_index != test_config().test_index.value()) {
                ++test_index;
                continue;
            }
        }

        run_single_test(testCase, path, test_index);
        if (::testing::Test::HasFailure())
            break;
        ++test_index;
    }
}

class GameboyAdvanceARMOpcodeTest : public ::testing::TestWithParam<fs::path> { };

TEST_P(GameboyAdvanceARMOpcodeTest, Run) {
    run_single_file(GetParam());
}

INSTANTIATE_TEST_SUITE_P(
    CPUTests,
    GameboyAdvanceARMOpcodeTest,
    ::testing::ValuesIn(collect_files_in_directory(
        get_test_dir(),
        ".bin",
        {},
        "arm")),
    get_test_name);

class GameboyAdvanceTHUMBOpcodeTest : public ::testing::TestWithParam<fs::path> { };

TEST_P(GameboyAdvanceTHUMBOpcodeTest, Run) {
    run_single_file(GetParam());
}

INSTANTIATE_TEST_SUITE_P(
    CPUTests,
    GameboyAdvanceTHUMBOpcodeTest,
    ::testing::ValuesIn(collect_files_in_directory(
        get_test_dir(),
        ".bin",
        {},
        "thumb")),
    get_test_name);