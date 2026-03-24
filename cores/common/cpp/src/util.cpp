#include <filesystem>
#include <fstream>
#include <iterator>
#include <string>
#include <vector>

#include "common/types.hpp"

namespace fs = std::filesystem;

std::vector<u8> read_buffer(const fs::path& filename) {

    // Source - https://stackoverflow.com/a/5420568
    // Posted by Björn Pollex, modified by community. See post 'Timeline' for change history
    // Retrieved 2026-03-22, License - CC BY-SA 4.0

    std::ifstream input(filename, std::ios::binary);

    // copies all data into buffer
    std::vector<u8> buffer(std::istreambuf_iterator<char>(input), {});

    return buffer;
}
