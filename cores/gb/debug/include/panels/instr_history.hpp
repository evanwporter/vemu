#include "op_history.hpp"
#include "../types.hpp"

#include <optional>

namespace debug::panels {

    class InstructionHistoryPanel {
    public:
        void set_history(const OperationHistory* history);
        std::optional<std::size_t> render(ExecMode exec_mode);

    private:
        const OperationHistory* history = nullptr;
        int selected = -1;
        std::size_t visible_count = 0;
    };
} // namespace debug::panels
