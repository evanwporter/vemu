find_package(nlohmann_json CONFIG REQUIRED)
find_package(GTest CONFIG REQUIRED)

add_library(test_arm_gba)

target_sources(test_arm_gba
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}/test_arm.cpp
)

target_link_libraries(test_arm_gba PUBLIC
    libgba
    GameboyAdvanceHarness
    GTest::gtest
    nlohmann_json::nlohmann_json
)

target_include_directories(test_arm_gba
    PRIVATE
        ${GBA_TESTS_CPP_DIR}
)

target_compile_definitions(test_arm_gba PUBLIC
    TEST_DIR="${CMAKE_SOURCE_DIR}/tests/"
)
