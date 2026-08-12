#pragma once

#include <cstdint>
#include "common/util.hpp"

namespace vemu::gba {

    bool is_thumb_mode(vemu::u32 cpsr);

}
