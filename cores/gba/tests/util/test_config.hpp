#pragma once

#include <cstddef>
#include <filesystem>
#include <optional>

struct TestConfig {
    std::optional<std::size_t> test_index;
    std::optional<std::filesystem::path> test_dir;
    bool update = false;
};

TestConfig& test_config();
