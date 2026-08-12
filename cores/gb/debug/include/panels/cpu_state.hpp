#pragma once

#include "../types.hpp"

namespace debug::panels {

    class CPUStatePanel {
    public:
        CPUStatePanel();

        // IDebuggerPanel interface
        void render();
        const char* get_name() const { return "CPU State"; }
        bool is_visible() const { return visible_; }
        void set_visible(bool visible) { visible_ = visible; }

        /**
         * Update the CPU state to display
         */
        void update(const CPURegisters& state);

    private:
        CPURegisters state_;
        bool visible_;
    };

} // namespace debug::panels
