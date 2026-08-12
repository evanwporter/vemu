#include "common/util.hpp"
#include "util/util.hpp"

namespace vemu::gba {

    // If bit 5 (T) is 0, it's ARM mode; if it's 1, it's Thumb mode.
    bool is_thumb_mode(u32 cpsr) {
        return get_bit(cpsr, 5);
    };

}
