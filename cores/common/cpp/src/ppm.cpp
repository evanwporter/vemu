#include "common/ppm.hpp"

#include <fstream>
#include <stdexcept>
#include <string>

namespace vemu {

void write_ppm(std::span<const uint32_t> pixels,
    std::size_t width,
    std::size_t height,
    const std::filesystem::path& path,
    PixelFormat format) {
    if (pixels.size() != width * height)
        throw std::runtime_error("Framebuffer dimensions do not match its size");

    std::ofstream output(path, std::ios::binary);
    if (!output)
        throw std::runtime_error("Failed to open " + path.string());

    output << "P6\n" << width << ' ' << height << "\n255\n";
    for (uint32_t pixel : pixels) {
        const int red_shift = format == PixelFormat::ARGB8888 ? 16 : 0;
        const int blue_shift = format == PixelFormat::ARGB8888 ? 0 : 16;
        const char rgb[] = {
            static_cast<char>((pixel >> red_shift) & 0xff),
            static_cast<char>((pixel >> 8) & 0xff),
            static_cast<char>((pixel >> blue_shift) & 0xff),
        };
        output.write(rgb, sizeof(rgb));
    }
}

std::vector<uint32_t> read_ppm(const std::filesystem::path& path,
    std::size_t& width,
    std::size_t& height,
    PixelFormat format) {
    std::ifstream input(path, std::ios::binary);
    if (!input)
        throw std::runtime_error("Failed to open " + path.string());

    std::string magic;
    int max_value;
    input >> magic >> width >> height >> max_value;
    input.get();
    if (magic != "P6" || max_value != 255)
        throw std::runtime_error("Invalid PPM image: " + path.string());

    std::vector<uint8_t> bytes(width * height * 3);
    input.read(reinterpret_cast<char*>(bytes.data()), static_cast<std::streamsize>(bytes.size()));
    if (!input)
        throw std::runtime_error("Truncated PPM image: " + path.string());

    std::vector<uint32_t> pixels(width * height);
    for (std::size_t i = 0; i < pixels.size(); ++i) {
        const uint32_t red = bytes[i * 3];
        const uint32_t green = bytes[i * 3 + 1];
        const uint32_t blue = bytes[i * 3 + 2];
        pixels[i] = format == PixelFormat::ARGB8888
            ? 0xff000000u | (red << 16) | (green << 8) | blue
            : 0xff000000u | (blue << 16) | (green << 8) | red;
    }
    return pixels;
}

} // namespace vemu
