find_package(nlohmann_json CONFIG REQUIRED)
find_package(GTest CONFIG REQUIRED)

add_library(test_thumb_gba)

target_sources(test_thumb_gba
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}/test_thumb.cpp
)

target_link_libraries(test_thumb_gba PUBLIC
    libgba
    nba
    GameboyAdvanceHarness
    GTest::gtest
    nlohmann_json::nlohmann_json
    libcommon
)

target_include_directories(test_thumb_gba
    PRIVATE
        ${GBA_TESTS_CPP_DIR}
    PUBLIC
        ${CMAKE_SOURCE_DIR}/cores/gba/tests/golden/nba/src/nba/include
        ${CMAKE_SOURCE_DIR}/cores/gba/tests/golden/nba/src/
)

target_compile_definitions(test_thumb_gba PUBLIC
    TEST_DIR="${CMAKE_SOURCE_DIR}/tests/"
)
