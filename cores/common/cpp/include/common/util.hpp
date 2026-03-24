#include <filesystem>
#include <fstream>
#include <iterator>
#include <string>
#include <vector>

#include "types.hpp"

std::vector<u8> read_buffer(const std::filesystem::path& filename);