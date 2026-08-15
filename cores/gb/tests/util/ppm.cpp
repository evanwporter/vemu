#include "ppm.hpp"
#include "common/ppm.hpp"

namespace fs = std::filesystem;
void write_ppm(
    const uint32_t framebuffer[FB_SIZE],
    const fs::path& path) {
    vemu::write_ppm({ framebuffer, FB_SIZE }, GB_WIDTH, GB_HEIGHT, path);
}

std::vector<uint32_t> read_ppm(
    const fs::path& path,
    std::size_t& width,
    std::size_t& height) {

    return vemu::read_ppm(path, width, height);
}
