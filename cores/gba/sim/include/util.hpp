#include <filesystem>
#include <fstream>
#include <iterator>
#include <string>
#include <vector>

namespace fs = std::filesystem;

std::vector<unsigned char> read_buffer(const fs::path& filename) {

    // Source - https://stackoverflow.com/a/5420568
    // Posted by Björn Pollex, modified by community. See post 'Timeline' for change history
    // Retrieved 2026-03-22, License - CC BY-SA 4.0

    std::ifstream input(filename, std::ios::binary);

    // copies all data into buffer
    std::vector<unsigned char> buffer(std::istreambuf_iterator<char>(input), {});

    return buffer;
}
