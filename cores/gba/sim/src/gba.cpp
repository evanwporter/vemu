#include "gba.hpp"
#include "verilated_vcd_c.h"

#include <SDL2/SDL.h>
#include <VGameboyAdvance.h>
#include <VGameboyAdvance___024root.h>
#include <gtest/gtest.h>
#include <verilated.h>
#include <verilated_types.h>

#include <array>
#include <filesystem>
#include <fstream>
#include <iostream>

namespace fs = std::filesystem;

void GameboyAdvanceHarness::load_bios(const std::filesystem::path& filename) {
    std::ifstream file(filename, std::ios::binary);
    if (!file) {
        throw std::runtime_error("Failed to open BIOS file");
    }

    auto& bios = top->rootp->GameboyAdvance__DOT__BIOS__DOT__mem;

    for (size_t i = 0; i < 0x4000; i++) {
        char byte;
        if (!file.read(&byte, 1)) {
            throw std::runtime_error("BIOS too small");
        }
        bios[i] = static_cast<uint8_t>(byte);
    }
}

bool GameboyAdvanceHarness::setup(const std::filesystem::path& rom_path) {
    const char* log_arg = nullptr;
    switch (options.log_level) {
    case LogLevel::Error:
        log_arg = "+gba-log-error";
        break;
    case LogLevel::Warn:
        log_arg = "+gba-log-warn";
        break;
    case LogLevel::Info:
        log_arg = "+gba-log-info";
        break;
    case LogLevel::Trace:
        log_arg = "+gba-log-trace";
        break;
    case LogLevel::None:
        break;
    }
    const char* verilator_args[] = { "gba", log_arg };
    ctx.commandArgs(log_arg ? 2 : 1, verilator_args);

    top = std::make_unique<VGameboyAdvance>(&ctx);
    if (options.waveform) {
        tfp = std::make_unique<VerilatedVcdC>();
        Verilated::traceEverOn(true);
        top->trace(tfp.get(), 99);
        tfp->open(options.wave_path.string().c_str());
    }

    cpu.emplace(*top);

    if (!load_rom(rom_path)) {
        return false;
    }

    load_bios(fs::path(__FILE__).parent_path() / "gba_bios.bin");

    std::cout << "Cycle 0: Reset Phase 1" << std::endl;

    // Reset
    top->reset = 1;
    tick();
    top->reset = 0;

    std::cout << "\nCycle 1: Reset Phase 2:" << std::endl;

    set_initial_state();

    tick();

    // std::cout << "\nCycle 2: Start flush" << std::endl;

    // tick();

    // std::cout << "\nCycle 3: Start flush and decode" << std::endl;

    // // Fetch and Decode
    // tick();

    // top->rootp->GameboyAdvance__DOT__cpu_inst__DOT__instr_boundary = 0;

    // // while (began_instruction()) {
    // //     tick();
    // // }

    // std::cout << "\n\nBeginning Execution of First Instruction\n";

    return true;
}

u8 GameboyAdvanceHarness::read_memory(u32 addr) const {

    if (addr <= 0x00003FFF) {
        return top->rootp->GameboyAdvance__DOT__BIOS__DOT__mem[addr];
    }

    if (addr <= 0x0203FFFF) {
        u32 address = addr - 0x02000000;
        u8 val = static_cast<u8>(top->rootp->GameboyAdvance__DOT__WRAM_BOARD__DOT__mem[address]);
        return val;
    }

    if (addr <= 0x0207FFFF) {
        u32 address = addr - 0x02040000;
        u8 val = static_cast<u8>(top->rootp->GameboyAdvance__DOT__WRAM_BOARD__DOT__mem[address]);
        return val;
    }

    if (addr <= 0x03007FFF) {
        u32 address = addr - 0x03000000;
        u8 val = static_cast<u8>(top->rootp->GameboyAdvance__DOT__WRAM_BOARD__DOT__mem[address]);
        return val;
    }

    // I/O
    else if (addr <= 0x040003FF) {
        u16 address = addr - 0x04000000;
        u8 val;
        if (addr <= 0x04000057) {
            const auto& regs = top->rootp->GameboyAdvance__DOT__ppu__DOT__regs;
            val = static_cast<u8>(regs[address / 4] >> ((address % 4) * 8));
        } else {
            val = static_cast<u8>(top->rootp->GameboyAdvance__DOT__IO__DOT__mem[address]);
        }
        return val;
    }

    else if (addr <= 0x050003FF) {
        u16 address = addr - 0x05000000;
        u8 val = static_cast<u8>(top->rootp->GameboyAdvance__DOT__IO__DOT__mem[address]);
        return val;
    }

    else if (addr <= 0x06017FFF) {
        u16 address = addr - 0x06000000;
        u8 val = top->rootp->GameboyAdvance__DOT__ppu__DOT__VRAM__DOT__mem[address];
        return val;
    }

    else if (addr <= 0x070003FF) {
        u16 address = addr - 0x07000000;
        u8 val = static_cast<u8>(top->rootp->GameboyAdvance__DOT__OAM__DOT__mem[address]);
        return val;
    }

    else if (addr <= 0x09FFFFFF) {
        u16 address = addr - 0x08000000;
        u8 val = top->rootp->GameboyAdvance__DOT__GAMEPAK_WS0__DOT__mem[address];
        return val;
    }

    else if (addr <= 0x0BFFFFFF) {
        u16 address = addr - 0x0A000000;
        u8 val = top->rootp->GameboyAdvance__DOT__GAMEPAK_WS1__DOT__mem[address];
        return val;
    }

    else if (addr <= 0x0CFFFFFF) {
        u16 address = addr - 0x0B000000;
        u8 val = top->rootp->GameboyAdvance__DOT__GAMEPAK_WS2__DOT__mem[address];
        return val;
    }

    else {
        std::cerr << "ERROR: Attempted to read from invalid memory address 0x" << std::hex << addr << std::dec << "\n";
        return 0xFF;
    }
}

bool GameboyAdvanceHarness::load_rom(const fs::path& filename) {
    std::ifstream rom(filename, std::ios::binary);
    if (!rom) {
        std::cerr << "Cannot open ROM!\n";
        return false;
    }

    size_t file_size = 0;
    char tmp;
    while (rom.read(&tmp, 1))
        file_size++;

    rom.clear();
    rom.seekg(0);

    for (size_t i = 0; i < sizeof(top->rootp->GameboyAdvance__DOT__GAMEPAK_WS0__DOT__mem); i++) {
        top->rootp->GameboyAdvance__DOT__GAMEPAK_WS0__DOT__mem[i] = 0;
    }

    for (int i = 0; i < 0x8000; i++) {
        char byte = 0;
        rom.read(&byte, 1);
        if (!rom)
            break;
        top->rootp->GameboyAdvance__DOT__GAMEPAK_WS0__DOT__mem[i] = (u8)byte;
    }

    std::cout << "Loaded ROM: " << file_size / 1024 << " KiB\n";
    return true;
}

void GameboyAdvanceHarness::set_initial_state() {
    auto& regs = top->rootp->GameboyAdvance__DOT__cpu_inst__DOT__regs;

    if (options.skip_boot_rom) {
        regs.__PVT__common.__PVT__r0 = 0x00000000;
        regs.__PVT__common.__PVT__r1 = 0x00000000;
        regs.__PVT__common.__PVT__r2 = 0x00000000;
        regs.__PVT__common.__PVT__r3 = 0x00000000;
        regs.__PVT__common.__PVT__r4 = 0x00000000;
        regs.__PVT__common.__PVT__r5 = 0x00000000;
        regs.__PVT__common.__PVT__r6 = 0x00000000;
        regs.__PVT__common.__PVT__r7 = 0x00000000;

        regs.__PVT__user.__PVT__r8 = 0x00000000;
        regs.__PVT__user.__PVT__r9 = 0x00000000;
        regs.__PVT__user.__PVT__r10 = 0x00000000;
        regs.__PVT__user.__PVT__r11 = 0x00000000;
        regs.__PVT__user.__PVT__r12 = 0x00000000;

        regs.__PVT__fiq.__PVT__r8 = 0x00000000;
        regs.__PVT__fiq.__PVT__r9 = 0x00000000;
        regs.__PVT__fiq.__PVT__r10 = 0x00000000;
        regs.__PVT__fiq.__PVT__r11 = 0x00000000;
        regs.__PVT__fiq.__PVT__r12 = 0x00000000;

        regs.__PVT__irq.__PVT__r13 = 0x03007FA0; // IRQ SP
        regs.__PVT__supervisor.__PVT__r13 = 0x03007FE0; // SVC SP

        regs.__PVT__user.__PVT__r13 = 0x03007F00; // SP

        regs.__PVT__CPSR = 0xDF;

        regs.__PVT__user.__PVT__r15 = 0x08000000;

        regs.__PVT__SPSR.__PVT__fiq = 0x00000000;
        regs.__PVT__SPSR.__PVT__abort = 0x00000000;
        regs.__PVT__SPSR.__PVT__supervisor = 0x00000000;
        regs.__PVT__SPSR.__PVT__undefined = 0x00000000;
        regs.__PVT__SPSR.__PVT__irq = 0x00000000;
    }
}

bool GameboyAdvanceHarness::began_instruction() const {
    if (top->rootp->GameboyAdvance__DOT__cpu_inst__DOT__instr_boundary == 0) {
        return true;
    }

    else {
        top->rootp->GameboyAdvance__DOT__cpu_inst__DOT__instr_boundary = 0;
        return false;
    }
};

bool GameboyAdvanceHarness::half_tick() {
    top->clk = 0;
    top->eval();
    if (tfp)
        tfp->dump(ctx.time());
    ctx.timeInc(5);

    return true;
}

bool GameboyAdvanceHarness::tick() {
    top->clk = 0;
    top->eval();
    if (tfp)
        tfp->dump(ctx.time());
    ctx.timeInc(5);

    top->clk = 1;
    top->eval();
    if (tfp)
        tfp->dump(ctx.time());
    ctx.timeInc(5);

    cycles++;

    return true;
}

bool GameboyAdvanceHarness::step() {
    while (began_instruction()) {
        if (!tick())
            return false;
        // debugger->on_tick();
    }
    // debugger->on_step();
    return true;
}

bool GameboyAdvanceHarness::run() {
    constexpr int width = 240;
    constexpr int height = 160;
    constexpr int scale = 3;
    constexpr int cycles_per_frame = 200'000;

    if (SDL_Init(SDL_INIT_VIDEO) != 0) {
        std::cerr << "SDL initialization failed: " << SDL_GetError() << "\n";
        return false;
    }

    SDL_Window* window = SDL_CreateWindow(
        "GBA - Mode 3",
        SDL_WINDOWPOS_CENTERED,
        SDL_WINDOWPOS_CENTERED,
        width * scale,
        height * scale,
        0);
    SDL_Renderer* renderer = window
        ? SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED)
        : nullptr;
    SDL_Texture* texture = renderer
        ? SDL_CreateTexture(
              renderer,
              SDL_PIXELFORMAT_ARGB8888,
              SDL_TEXTUREACCESS_STREAMING,
              width,
              height)
        : nullptr;

    if (!window || !renderer || !texture) {
        std::cerr << "SDL display setup failed: " << SDL_GetError() << "\n";
        if (texture)
            SDL_DestroyTexture(texture);
        if (renderer)
            SDL_DestroyRenderer(renderer);
        if (window)
            SDL_DestroyWindow(window);
        SDL_Quit();
        return false;
    }

    std::array<u32, width * height> framebuffer { };
    auto& vram = top->rootp->GameboyAdvance__DOT__ppu__DOT__VRAM__DOT__mem;
    bool running = true;

    while (running) {
        SDL_Event event;
        while (SDL_PollEvent(&event)) {
            if (event.type == SDL_QUIT)
                running = false;
        }

        for (int i = 0; i < cycles_per_frame && running; ++i)
            tick();

        const auto mode = top->rootp->GameboyAdvance__DOT__ppu__DOT__regs[0] & 0x7;

        if (mode == 3) {
            std::cout << "Rendering frame in Mode 3\n";
        }

        for (std::size_t pixel_index = 0; pixel_index < framebuffer.size(); ++pixel_index) {
            const std::size_t byte_index = pixel_index * 2;
            const u16 pixel = static_cast<u16>(vram[byte_index])
                | static_cast<u16>(vram[byte_index + 1] << 8);
            const u8 red = static_cast<u8>(((pixel >> 0) & 0x1F) * 255 / 31);
            const u8 green = static_cast<u8>(((pixel >> 5) & 0x1F) * 255 / 31);
            const u8 blue = static_cast<u8>(((pixel >> 10) & 0x1F) * 255 / 31);
            framebuffer[pixel_index] = 0xFF000000u
                | (static_cast<u32>(red) << 16)
                | (static_cast<u32>(green) << 8)
                | blue;
        }

        SDL_UpdateTexture(texture, nullptr, framebuffer.data(), width * sizeof(u32));
        SDL_RenderClear(renderer);
        SDL_RenderCopy(renderer, texture, nullptr, nullptr);
        SDL_RenderPresent(renderer);
    }

    SDL_DestroyTexture(texture);
    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
    SDL_Quit();
    return true;
}

ArmTraceState GameboyAdvanceHarness::capture_arm_state() const {
    ArmTraceState st { };

    const auto& regs = top->rootp->GameboyAdvance__DOT__cpu_inst__DOT__regs;
    const u32 mode = regs.__PVT__CPSR & 0x1F;

    // r0-r7 are always common
    st.r[0] = regs.__PVT__common.__PVT__r0;
    st.r[1] = regs.__PVT__common.__PVT__r1;
    st.r[2] = regs.__PVT__common.__PVT__r2;
    st.r[3] = regs.__PVT__common.__PVT__r3;
    st.r[4] = regs.__PVT__common.__PVT__r4;
    st.r[5] = regs.__PVT__common.__PVT__r5;
    st.r[6] = regs.__PVT__common.__PVT__r6;
    st.r[7] = regs.__PVT__common.__PVT__r7;

    // r8-r12 are banked only in FIQ
    if (mode == 0x11) { // FIQ
        st.r[8] = regs.__PVT__fiq.__PVT__r8;
        st.r[9] = regs.__PVT__fiq.__PVT__r9;
        st.r[10] = regs.__PVT__fiq.__PVT__r10;
        st.r[11] = regs.__PVT__fiq.__PVT__r11;
        st.r[12] = regs.__PVT__fiq.__PVT__r12;
    } else {
        st.r[8] = regs.__PVT__user.__PVT__r8;
        st.r[9] = regs.__PVT__user.__PVT__r9;
        st.r[10] = regs.__PVT__user.__PVT__r10;
        st.r[11] = regs.__PVT__user.__PVT__r11;
        st.r[12] = regs.__PVT__user.__PVT__r12;
    }

    // r13-r14 are banked per mode
    switch (mode) {
    case 0x11: // FIQ
        st.r[13] = regs.__PVT__fiq.__PVT__r13;
        st.r[14] = regs.__PVT__fiq.__PVT__r14;
        st.spsr = regs.__PVT__SPSR.__PVT__fiq;
        break;
    case 0x12: // IRQ
        st.r[13] = regs.__PVT__irq.__PVT__r13;
        st.r[14] = regs.__PVT__irq.__PVT__r14;
        st.spsr = regs.__PVT__SPSR.__PVT__irq;
        break;
    case 0x13: // SVC
        st.r[13] = regs.__PVT__supervisor.__PVT__r13;
        st.r[14] = regs.__PVT__supervisor.__PVT__r14;
        st.spsr = regs.__PVT__SPSR.__PVT__supervisor;
        break;
    case 0x17: // ABT
        st.r[13] = regs.__PVT__abort.__PVT__r13;
        st.r[14] = regs.__PVT__abort.__PVT__r14;
        st.spsr = regs.__PVT__SPSR.__PVT__abort;
        break;
    case 0x1B: // UND
        st.r[13] = regs.__PVT__undefined.__PVT__r13;
        st.r[14] = regs.__PVT__undefined.__PVT__r14;
        st.spsr = regs.__PVT__SPSR.__PVT__undefined;
        break;
    case 0x10: // USR
    case 0x1F: // SYS
    default:
        st.r[13] = regs.__PVT__user.__PVT__r13;
        st.r[14] = regs.__PVT__user.__PVT__r14;
        st.spsr = regs.__PVT__CPSR; // matches your log format
        break;
    }

    st.r[15] = regs.__PVT__user.__PVT__r15;
    st.cpsr = regs.__PVT__CPSR;

    return st;
}
