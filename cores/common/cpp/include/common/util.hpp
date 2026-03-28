#pragma once

#include <filesystem>
#include <limits>
#include <type_traits>
#include <vector>

#include "types.hpp"

namespace vemu {

    std::vector<u8> read_buffer(const std::filesystem::path& filename);

    template <typename T>
    static inline bool get_bit(T value, unsigned bit) {
        static_assert(std::is_integral_v<T>, "get_bit requires integral type");

        using U = std::make_unsigned_t<T>;

        if (bit >= std::numeric_limits<U>::digits)
            return false;

        return (static_cast<U>(value) >> bit) & U(1);
    }

    static std::string hex16(u32 v) {
        std::ostringstream oss;
        oss << "0x"
            << std::hex << std::uppercase
            << std::setw(4) << std::setfill('0')
            << v;
        return oss.str();
    }

    static std::string hex32(u32 v) {
        std::ostringstream oss;
        oss << "0x"
            << std::hex << std::uppercase
            << std::setw(8) << std::setfill('0')
            << v;
        return oss.str();
    }
}