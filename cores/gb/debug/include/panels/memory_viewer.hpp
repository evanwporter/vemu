#pragma once

#include <optional>

#include "../types.hpp"

#include <array>

namespace debug::panels {

    class MemoryViewerPanel {
    public:
        MemoryViewerPanel();

        // Update full 64KB snapshot
        void update(const u16 addr, const u8 value);

        void render();

        void set_snapshot(const std::array<u8, 0x10000>& mem);
        void set_selection(const MemorySelection& sel);

    private:
        bool visible_ = true;

        std::array<u8, 0x10000> memory_ {};
        std::array<bool, 0x10000> highlight_ {};

        bool valid_ = false;

        std::optional<u16> focus_addr_;

        void render_region(u16 start, u16 end);
    };
}
