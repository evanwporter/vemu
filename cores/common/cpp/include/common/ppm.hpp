#pragma once

#include <cstdint>
#include <filesystem>
#include <span>
#include <vector>

namespace vemu {

enum class PixelFormat {
    ARGB8888,
    ABGR8888,
};

void write_ppm(std::span<const uint32_t> pixels,
    std::size_t width,
    std::size_t height,
    const std::filesystem::path& path,
    PixelFormat format = PixelFormat::ARGB8888);

std::vector<uint32_t> read_ppm(const std::filesystem::path& path,
    std::size_t& width,
    std::size_t& height,
    PixelFormat format = PixelFormat::ARGB8888);

} // namespace vemu
