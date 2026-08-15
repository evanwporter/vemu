#include "gba_differential.hpp"
#include "util/decode.hpp"
#include "util/test_config.hpp"
#include "util/util.hpp"

namespace vemu::gba::test {

    std::vector<u8> ReadFile(const fs::path& path) {
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

    uint32_t read_u32_mem(const GameboyAdvanceHarness& harness, uint32_t address) {
        return static_cast<uint32_t>(harness.read_memory(address))
            | (static_cast<uint32_t>(harness.read_memory(address + 1)) << 8)
            | (static_cast<uint32_t>(harness.read_memory(address + 2)) << 16)
            | (static_cast<uint32_t>(harness.read_memory(address + 3)) << 24);
    }

    u32 read_u16_mem(const GameboyAdvanceHarness& harness, uint32_t address) {
        return static_cast<u32>(harness.read_memory(address))
            | (static_cast<u32>(harness.read_memory(address + 1)) << 8);
    }

    std::string format_row_plain(const TraceRow& row, bool pc_minus_4) {
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

    void print_debug_mismatch(const std::optional<TraceRow>& last_good, const TraceRow& expected, const TraceRow& actual) {
        std::cout << "\n================ TRACE DEBUG ================\n"
                  << "Last matching:\n  "
                  << (last_good ? format_row_plain(*last_good) : "<none>")
                  << "\nExpected:\n  " << format_row_plain(expected)
                  << "\nActual:\n  " << format_row_plain(actual)
                  << "\n=============================================\n\n";
    }

    NbaOracle CreateNbaOracle(const fs::path& rom_path, const std::optional<fs::path>& bios_path) {
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

    TraceRow capture_nba_state(nba::core::Core* core, size_t step_index) {
        TraceRow row { };
        row.step_index = step_index;
        auto& state = core->GetCPU().state;
        row.r = { state.r0, state.r1, state.r2, state.r3, state.r4, state.r5, state.r6, state.r7, state.r8, state.r9, state.r10, state.r11, state.r12, state.r13, state.r14, state.r15 };
        row.cpsr = state.cpsr.v;
        row.spsr = state.spsr[0].v;
        return row;
    }

    TraceRow capture_dut_state(GameboyAdvanceHarness& harness, size_t step_index) {
        TraceRow row { };
        row.step_index = step_index;
        const ArmTraceState state = harness.capture_arm_state();
        row.r = state.r;
        row.cpsr = state.cpsr;
        row.spsr = state.spsr;
        return row;
    }

    void compare_states(const TraceRow& expected, const TraceRow& actual, const std::optional<TraceRow>& last_good) {
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

    void RunCpuInstructionTest(const InstructionTestConfig& config) {
        fs::path rom_path = test_config().test_dir.has_value()
            ? test_config().test_dir.value() / config.rom_rel_path
            : fs::path(TEST_DIR) / config.rom_rel_path;

        ASSERT_TRUE(std::filesystem::exists(rom_path)) << "Path " << rom_path << " does not exist";

        testing::internal::CaptureStdout();
        testing::internal::CaptureStderr();

        const fs::path vcd_path = fs::path(__FILE__).parent_path() / (config.name + ".vcd");
        GameboyAdvanceHarness harness({ true, vcd_path });
        ASSERT_TRUE(harness.setup(rom_path)) << "Failed to setup harness: " << rom_path;

        size_t step_index = 0;
        std::optional<TraceRow> last_good;

        const auto nba = CreateNbaOracle(rom_path, fs::path(GBA_BIOS_PATH));
        ASSERT_NE(nba.impl, nullptr) << "Failed to create NBA oracle";

        // Macro/lambda to handle state comparisons
        auto assert_state = [&](const std::string& ctx) {
            TraceRow actual = capture_dut_state(harness, step_index);
            TraceRow expected = capture_nba_state(nba.impl, step_index);
            compare_states(expected, actual, last_good);
            ASSERT_FALSE(::testing::Test::HasFailure()) << ctx << " at step " << step_index;
            last_good = expected;
            step_index++;
        };

        // Cycles 1-3 Reset & Pipeline Flush Sequence
        assert_state("Initial state mismatch after reset");

        std::cout << "\nCycle 2: Start flush\n";
        harness.tick();
        nba.core->Step();
        assert_state("State mismatch at step");

        std::cout << "\nCycle 3: Start flush and decode\n";
        harness.tick();
        nba.core->Step();
        harness.get_top().rootp->GameboyAdvance__DOT__cpu_inst__DOT__instr_boundary = 0;
        assert_state("State mismatch at step");

        std::cout << "\n\nBeginning Execution of First Instruction\n";

        int cycles = 0;
        int instructions_executed = 0;

        while (true) {
            int max_ticks = 40;
            std::cout << "\n===============================================\n";
            std::cout << "Executing instruction " << instructions_executed << "\n";
            std::cout << "===============================================\n";

            // Instruction Inspection & Opcode Decoding
            {
                TraceRow actual = capture_dut_state(harness, step_index);
                uint32_t pc = actual.r[15];
                bool thumb_mode = is_thumb_mode(actual.cpsr);
                int instr_size = thumb_mode ? 2 : 4;

                u32 instr_addr_exec = pc - (2 * instr_size);
                u32 instr_addr_fetch = pc - instr_size;

                u32 instr_exec = thumb_mode ? read_u16_mem(harness, instr_addr_exec) : read_u32_mem(harness, instr_addr_exec);
                u32 instr_fetch = thumb_mode ? read_u16_mem(harness, instr_addr_fetch) : read_u32_mem(harness, instr_addr_fetch);

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

                EXPECT_EQ(instr_exec, nba.impl->GetCPU().GetFetchedOpcode(0));
                EXPECT_EQ(instr_fetch, nba.impl->GetCPU().GetFetchedOpcode(1));

                auto mask_thumb = [&](uint32_t v) { return thumb_mode ? (v & 0xFFFF) : v; };
                u32 decoder_inst_IR = mask_thumb(harness.get_top().rootp->GameboyAdvance__DOT__cpu_inst__DOT__decoder_inst__DOT__IR);
                u32 cpu_inst_IR = mask_thumb(harness.get_top().rootp->GameboyAdvance__DOT__cpu_inst__DOT__IR);

                EXPECT_EQ(decoder_inst_IR, nba.impl->GetCPU().GetFetchedOpcode(0));
                EXPECT_EQ(cpu_inst_IR, nba.impl->GetCPU().GetFetchedOpcode(1));

                if (::testing::Test::HasFailure()) {
                    harness.half_tick();
                    break;
                }
            }

            harness.get_top().rootp->GameboyAdvance__DOT__cpu_inst__DOT__instr_boundary = 0;

            while (harness.get_top().rootp->GameboyAdvance__DOT__cpu_inst__DOT__instr_boundary == 0 && max_ticks-- > 0) {
                std::cout << "\nCycle " << (cycles + 4) << ": Execute\n";
                harness.tick();
                cycles++;
            }

            nba.core->Step();
            instructions_executed++;

            EXPECT_GT(max_ticks, 0) << "Timeout in test.";

            if (harness.get_top().rootp->GameboyAdvance__DOT__cpu_inst__DOT__flush_req) {
                std::cout << "\n2 cycles of flush remaining\n";
                harness.tick();
                std::cout << "\n1 cycles of flush remaining\n";
                harness.tick();
            }

            // Apply pre-comparison hooks (e.g., Register fixup at step 862)
            if (config.step_hook) {
                config.step_hook(harness, step_index);
            }

            // Apply post-comparison hooks (e.g., display triggers)
            if (config.end_step_index == step_index) {
                break;
            }

            TraceRow actual = capture_dut_state(harness, step_index);
            TraceRow expected = capture_nba_state(nba.impl, step_index);
            compare_states(expected, actual, last_good);

            if (::testing::Test::HasFailure()) {
                harness.half_tick();
                print_debug_mismatch(last_good, expected, actual);
                break;
            }

            step_index++;
        }

        std::string stdout_output = testing::internal::GetCapturedStdout();
        std::string stderr_output = testing::internal::GetCapturedStderr();

        const fs::path log_path = fs::absolute(fs::current_path() / (config.name + "_trace.log"));
        std::ofstream logfile(log_path);
        ASSERT_TRUE(logfile) << "Failed to open " << log_path;
        logfile << "\n==== Captured stdout ====\n"
                << stdout_output
                << "\n==== Captured stderr ====\n"
                << stderr_output;
        logfile.close();

        std::cout << "Differential trace log: file://" << log_path.string() << '\n';
    }

} // namespace vemu::gba::test
