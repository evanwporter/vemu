find_package(Verilator REQUIRED HINTS $ENV{VERILATOR_ROOT})

add_library(libgba)

gba_add_rtl(
    PACKAGES
        ${CMAKE_CURRENT_SOURCE_DIR}/types.sv
    INTERFACES
    SOURCES
        ${CMAKE_CURRENT_SOURCE_DIR}/GameboyAdvance.sv
        ${CMAKE_CURRENT_SOURCE_DIR}/Memory.sv
)

add_subdirectory(cpu)
add_subdirectory(mmu)
add_subdirectory(ppu)

get_target_property(GBA_PACKAGES gba_rtl INTERFACE_GBA_PACKAGES)
get_target_property(GBA_INTERFACES gba_rtl INTERFACE_GBA_INTERFACES)
get_target_property(GBA_SOURCES gba_rtl INTERFACE_GBA_SOURCES)

set(GBA_F_CONTENT
"${GBA_PACKAGES}
${GBA_INTERFACES}
${GBA_SOURCES}
")

string(REPLACE ";" "\n" GBA_F_CONTENT "${GBA_F_CONTENT}")

set(GBA_COMMAND_FILE ${CMAKE_CURRENT_BINARY_DIR}/gba.f)
file(WRITE ${GBA_COMMAND_FILE} "${GBA_F_CONTENT}\n")
file(APPEND ${GBA_COMMAND_FILE} "+incdir+${CMAKE_CURRENT_SOURCE_DIR}\n")
file(APPEND ${GBA_COMMAND_FILE} "+incdir+${GBA_INCLUDE_DIR}\n")

verilate(libgba
    PREFIX VGameboyAdvance
    SOURCES 
        ${GBA_PACKAGES}
        ${GBA_INTERFACES}
        ${GBA_SOURCES}
    TOP_MODULE GameboyAdvance
    VERILATOR_ARGS
        --sv
        --trace-vcd
        # -Wall
        -I${CMAKE_CURRENT_SOURCE_DIR}
        -I${GBA_INCLUDE_DIR}
        -O3
        --trace-params
        --trace-structs
)
