set(GB_TESTS_CPP_DIR ${CMAKE_CURRENT_SOURCE_DIR})

add_subdirectory(cpu)
add_subdirectory(ppu)
add_subdirectory(blargg)
add_subdirectory(mooneye)

add_executable(test_gb
    ${CMAKE_CURRENT_SOURCE_DIR}/main.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/verilator_time.cpp
)

add_subdirectory(util)

find_package(GTest CONFIG REQUIRED)
target_link_libraries(test_gb
    PRIVATE
        test_cpu
        test_blargg
        test_mooneye
        # test_ppu
        libgb
        libcommon
        GTest::gtest
)

target_compile_definitions(test_gb PRIVATE
    TEST_DIR="${CMAKE_SOURCE_DIR}/tests/"
)

target_include_directories(test_gb PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
)

include(GoogleTest)
gtest_discover_tests(test_gb)
