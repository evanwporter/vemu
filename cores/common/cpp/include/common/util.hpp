#pragma once

#include <filesystem>
#include <limits>
#include <type_traits>
#include <vector>

#include "types.hpp"

std::vector<u8> read_buffer(const std::filesystem::path& filename);

template <typename T>
static inline bool get_bit(T value, unsigned bit) {
    static_assert(std::is_integral_v<T>, "get_bit requires integral type");

    using U = std::make_unsigned_t<T>;

    if (bit >= std::numeric_limits<U>::digits)
        return false;

    return (static_cast<U>(value) >> bit) & U(1);
}