// panels/vram_viewer.hpp
#pragma once

#include "../types.hpp"
#include <array>
#include <optional>
#include <vector>

namespace debug::panels {

    class TilesPanel {
    public:
        void set_snapshot(const std::array<u8, 0x10000>& mem);
        void set_highlight(const std::vector<u16>& addresses);

        void render();

    private:
        static constexpr u16 VRAM_START = 0x8000;
        static constexpr u16 VRAM_SIZE = 0x2000;
        static constexpr int TILE_COUNT = 384;

        const u8* vram_ = nullptr;

        std::array<bool, VRAM_SIZE> dirty_ {};
        std::optional<int> focused_tile_;
        int selected_tile_ = -1;

        void render_tile_grid();
        bool tile_dirty(int tile) const;
    };

} // namespace debug::panels
