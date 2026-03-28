#pragma once

#include <cstdint>
#include <filesystem>
#include <string>
#include <unordered_set>
#include <vector>

#include <gtest/gtest.h>

#include "common/util.hpp"

std::vector<std::filesystem::path> collect_files_in_directory(
    const std::filesystem::path& dir,
    const std::string& extension,
    const std::unordered_set<std::string> exclude = {},
    const std::string& prefix = "");

std::string get_test_name(const ::testing::TestParamInfo<std::filesystem::path>& info);

bool is_thumb_mode(u32 cpsr);