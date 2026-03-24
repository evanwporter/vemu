set(GBA_TESTS_CPP_DIR ${CMAKE_CURRENT_SOURCE_DIR})

add_subdirectory(cpu)
add_subdirectory(arm.gba)

add_executable(test_gba
    ${CMAKE_CURRENT_SOURCE_DIR}/main.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/verilator_time.cpp
)

add_subdirectory(util)

add_test(
    NAME test_gba
    COMMAND test_gba
)

find_package(GTest CONFIG REQUIRED)
target_link_libraries(test_gba
    PRIVATE
        test_cpu_adv
        test_arm_gba
        GTest::gtest
)

target_compile_definitions(test_gba PRIVATE
    TEST_DIR="${CMAKE_SOURCE_DIR}/tests/"
)

target_include_directories(test_gba PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
)
