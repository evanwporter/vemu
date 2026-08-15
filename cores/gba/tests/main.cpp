#include "util/test_config.hpp"
#include <gtest/gtest.h>

int main(int argc, char** argv) {

    // TODO: Arg parse
    int write_index = 1;
    for (int i = 1; i < argc; ++i) {
        std::string_view arg(argv[i]);
        if (arg == "--update") {
            test_config().update = true;
        } else if (arg.rfind("--test-index=", 0) == 0) {
            auto value = arg.substr(strlen("--test-index="));
            test_config().test_index = std::stoul(std::string(value));
        } else if (arg.rfind("--test-dir=", 0) == 0) {
            auto value = arg.substr(strlen("--test-dir="));
            test_config().test_dir = std::string(value);
        } else {
            argv[write_index++] = argv[i];
        }
    }
    argc = write_index;

    ::testing::InitGoogleTest(&argc, argv);

    return RUN_ALL_TESTS();
}
