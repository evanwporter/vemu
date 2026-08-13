#include "gba.hpp"

#include <filesystem>
#include <iostream>
#include <string_view>

int main(int argc, char* argv[]) {
    if (argc < 2) {
        std::cerr << "Usage: gba <rom.gba> [--wave] [--log-level none|error|warn|info|trace]\n";
        return 1;
    }

    const std::filesystem::path rom_path = argv[1];
    GameboyAdvanceHarness::Options options;
    options.skip_boot_rom = true;
    for (int i = 2; i < argc; ++i) {
        const std::string_view arg = argv[i];
        if (arg == "--wave") {
            options.waveform = true;
        } else if (arg == "--log-level" && i + 1 < argc) {
            const std::string_view level = argv[++i];
            if (level == "none")
                options.log_level = GameboyAdvanceHarness::LogLevel::None;
            else if (level == "error")
                options.log_level = GameboyAdvanceHarness::LogLevel::Error;
            else if (level == "warn")
                options.log_level = GameboyAdvanceHarness::LogLevel::Warn;
            else if (level == "info")
                options.log_level = GameboyAdvanceHarness::LogLevel::Info;
            else if (level == "trace")
                options.log_level = GameboyAdvanceHarness::LogLevel::Trace;
            else {
                std::cerr << "Unknown log level: " << level << "\n";
                return 1;
            }
        } else {
            std::cerr << "Unknown argument: " << arg << "\n";
            return 1;
        }
    }

    GameboyAdvanceHarness gba(options);
    if (!gba.setup(rom_path))
        return 1;

    return gba.run() ? 0 : 1;
}
