find_package(nlohmann_json CONFIG REQUIRED)
find_package(GTest CONFIG REQUIRED)
find_package(Python3 REQUIRED COMPONENTS Interpreter)

set(CPU_TEST_DATA_DIR "${CMAKE_SOURCE_DIR}/tests/GameboyCPUTests/v2")
set(CPU_TEST_GENERATOR "${CMAKE_SOURCE_DIR}/scripts/generate_cpu_tests.py")
set(GENERATED_CPU_TESTS "${CMAKE_CURRENT_SOURCE_DIR}/generated_opcode_test.cpp")
set(GENERATED_CB_CPU_TESTS "${CMAKE_CURRENT_SOURCE_DIR}/generated_cb_opcode_test.cpp")

file(GLOB CPU_TEST_DATA_FILES CONFIGURE_DEPENDS "${CPU_TEST_DATA_DIR}/*.json")
file(GLOB CB_CPU_TEST_DATA_FILES CONFIGURE_DEPENDS "${CPU_TEST_DATA_DIR}/cb/*.json")
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${CPU_TEST_GENERATOR}")

execute_process(
    COMMAND
        "${Python3_EXECUTABLE}" "${CPU_TEST_GENERATOR}"
        --input-dir "${CPU_TEST_DATA_DIR}"
        --pattern "[0-9a-f][0-9a-f].json"
        --suite GameboyOpcodeTest
        --runner run_gameboy_cpu_test_file
        --output "${GENERATED_CPU_TESTS}"
    RESULT_VARIABLE CPU_TEST_GENERATOR_RESULT
    ERROR_VARIABLE CPU_TEST_GENERATOR_ERROR
)
if(NOT CPU_TEST_GENERATOR_RESULT EQUAL 0)
    message(FATAL_ERROR "Failed to generate Game Boy CPU tests: ${CPU_TEST_GENERATOR_ERROR}")
endif()

execute_process(
    COMMAND
        "${Python3_EXECUTABLE}" "${CPU_TEST_GENERATOR}"
        --input-dir "${CPU_TEST_DATA_DIR}/cb"
        --pattern "[0-9a-f][0-9a-f].json"
        --suite GameboyCBOpcodeTest
        --runner run_gameboy_cb_cpu_test_file
        --output "${GENERATED_CB_CPU_TESTS}"
    RESULT_VARIABLE CB_CPU_TEST_GENERATOR_RESULT
    ERROR_VARIABLE CB_CPU_TEST_GENERATOR_ERROR
)
if(NOT CB_CPU_TEST_GENERATOR_RESULT EQUAL 0)
    message(FATAL_ERROR "Failed to generate Game Boy CB CPU tests: ${CB_CPU_TEST_GENERATOR_ERROR}")
endif()

add_library(test_cpu)

target_sources(test_cpu
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}/test_cpu.cpp
        ${GENERATED_CPU_TESTS}
        ${GENERATED_CB_CPU_TESTS}
)

target_link_libraries(test_cpu PRIVATE
    GTest::gtest
    nlohmann_json::nlohmann_json
)

target_include_directories(test_cpu
    PUBLIC
        ${GB_TESTS_CPP_DIR}
        ${CMAKE_CURRENT_SOURCE_DIR}
)

get_target_property(GB_PACKAGES gb_rtl INTERFACE_GB_PACKAGES)
get_target_property(GB_INTERFACES gb_rtl INTERFACE_GB_INTERFACES)

verilate(test_cpu
    PREFIX Vcpu_top
    TOP_MODULE cpu_top
    SOURCES
        ${GB_PACKAGES}
        ${GB_INTERFACES}

        ${CMAKE_CURRENT_SOURCE_DIR}/cpu_top.sv

    VERILATOR_ARGS
        --sv
        --trace
        -Wall
        -Wno-fatal
        -I${GB_INCLUDE_DIR}
        -I${GB_SRC_DIR}
        -I${CMAKE_CURRENT_BINARY_DIR}/
)

target_compile_definitions(test_cpu PUBLIC
    TEST_DIR="${CMAKE_SOURCE_DIR}/tests/"
)
