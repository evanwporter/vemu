find_package(nlohmann_json CONFIG REQUIRED)
find_package(GTest CONFIG REQUIRED)
find_package(Python3 REQUIRED COMPONENTS Interpreter)

set(CPU_TEST_DATA_DIR "${CMAKE_SOURCE_DIR}/tests/GameboyAdvanceCPUTests/v1")
set(CPU_TEST_GENERATOR "${CMAKE_SOURCE_DIR}/scripts/generate_cpu_tests.py")
# neotest-ctest ignores build directories and recognizes *_test.cpp files.
set(GENERATED_ARM_CPU_TESTS "${CMAKE_CURRENT_SOURCE_DIR}/generated_arm_cpu_test.cpp")
set(GENERATED_THUMB_CPU_TESTS "${CMAKE_CURRENT_SOURCE_DIR}/generated_thumb_cpu_test.cpp")

# CONFIGURE_DEPENDS makes additions and removals in the test data directory
# trigger a CMake reconfigure and regenerate the explicit GoogleTest cases.
file(GLOB CPU_TEST_DATA_FILES CONFIGURE_DEPENDS "${CPU_TEST_DATA_DIR}/*.bin")
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${CPU_TEST_GENERATOR}")

execute_process(
    COMMAND
        "${Python3_EXECUTABLE}" "${CPU_TEST_GENERATOR}"
        --input-dir "${CPU_TEST_DATA_DIR}"
        --pattern "arm_*.bin"
        --suite GameboyAdvanceARMOpcodeTest
        --runner run_cpu_test_file
        --output "${GENERATED_ARM_CPU_TESTS}"
    RESULT_VARIABLE ARM_CPU_TEST_GENERATOR_RESULT
    ERROR_VARIABLE ARM_CPU_TEST_GENERATOR_ERROR
)
if(NOT ARM_CPU_TEST_GENERATOR_RESULT EQUAL 0)
    message(FATAL_ERROR "Failed to generate ARM CPU tests: ${ARM_CPU_TEST_GENERATOR_ERROR}")
endif()

execute_process(
    COMMAND
        "${Python3_EXECUTABLE}" "${CPU_TEST_GENERATOR}"
        --input-dir "${CPU_TEST_DATA_DIR}"
        --pattern "thumb_*.bin"
        --suite GameboyAdvanceTHUMBOpcodeTest
        --runner run_cpu_test_file
        --output "${GENERATED_THUMB_CPU_TESTS}"
    RESULT_VARIABLE THUMB_CPU_TEST_GENERATOR_RESULT
    ERROR_VARIABLE THUMB_CPU_TEST_GENERATOR_ERROR
)
if(NOT THUMB_CPU_TEST_GENERATOR_RESULT EQUAL 0)
    message(FATAL_ERROR "Failed to generate THUMB CPU tests: ${THUMB_CPU_TEST_GENERATOR_ERROR}")
endif()

add_library(test_cpu_adv)

target_sources(test_cpu_adv
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}/test_cpu.cpp
        ${CMAKE_CURRENT_SOURCE_DIR}/json_parser.cpp
        ${GENERATED_ARM_CPU_TESTS}
        ${GENERATED_THUMB_CPU_TESTS}
)

target_link_libraries(test_cpu_adv PRIVATE
    GTest::gtest
    nlohmann_json::nlohmann_json
    libcommon
)

target_include_directories(test_cpu_adv
    PUBLIC
        ${GBA_TESTS_CPP_DIR}
        ${CMAKE_CURRENT_SOURCE_DIR}
)

get_target_property(GBA_PACKAGES gba_rtl INTERFACE_GBA_PACKAGES)
get_target_property(GBA_INTERFACES gba_rtl INTERFACE_GBA_INTERFACES)

verilate(test_cpu_adv
    PREFIX Varm_cpu_top
    TOP_MODULE arm_cpu_top
    SOURCES
        ${CMAKE_CURRENT_SOURCE_DIR}/test_cpu.vlt
    
        ${GBA_PACKAGES}
        ${GBA_INTERFACES}

        ${CMAKE_CURRENT_SOURCE_DIR}/arm_cpu_top.sv
        ${GBA_SRC_DIR}/cpu/CPU.sv
        ${GBA_SRC_DIR}/cpu/ALU.sv
        ${GBA_SRC_DIR}/cpu/BarrelShifter.sv
        ${GBA_SRC_DIR}/cpu/control_types.sv
        ${GBA_SRC_DIR}/cpu/Decoder.sv
        ${GBA_SRC_DIR}/cpu/ControlUnit.sv
        ${GBA_SRC_DIR}/cpu/Multiplier.sv
        ${GBA_SRC_DIR}/cpu/interface.sv
        ${GBA_SRC_DIR}/cpu/types.sv

    VERILATOR_ARGS
        --sv
        --trace
        -Wall
        -Wno-fatal
        -I${GBA_SRC_DIR}
        -I${GBA_INCLUDE_DIR}
        -I${CMAKE_CURRENT_BINARY_DIR}/
        -O3
        --trace-params
        --trace-structs
)

target_compile_definitions(test_cpu_adv PUBLIC
    TEST_DIR="${CMAKE_SOURCE_DIR}/tests/"
)
