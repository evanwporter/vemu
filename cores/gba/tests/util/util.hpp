#pragma once

#include <cstdint>
#include <filesystem>
#include <string>
#include <unordered_set>
#include <vector>

#include <gtest/gtest.h>

std::vector<std::filesystem::path> collect_files_in_directory(
    const std::filesystem::path& dir,
    const std::string& extension,
    const std::unordered_set<std::string> exclude = {},
    const std::string& prefix = "");

std::string get_test_name(const ::testing::TestParamInfo<std::filesystem::path>& info);

static inline uint32_t gb_color(uint8_t c) {
    switch (c & 0x3) {
    case 0:
        return 0xFFFFFFFF; // white
    case 1:
        return 0xFFAAAAAA; // light gray
    case 2:
        return 0xFF555555; // dark gray
    case 3:
        return 0xFF000000; // black
    default:
        return 0xFFFFFFFF;
    }
}