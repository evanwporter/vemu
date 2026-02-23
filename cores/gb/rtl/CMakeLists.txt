find_package(Verilator REQUIRED HINTS $ENV{VERILATOR_ROOT})

add_library(libgb)

add_subdirectory(ppu)
add_subdirectory(mmu)
add_subdirectory(cpu)
add_subdirectory(cartridge)

gb_add_rtl(
    PACKAGES
        ${CMAKE_CURRENT_SOURCE_DIR}/types.sv
    INTERFACES
    SOURCES
        ${CMAKE_CURRENT_SOURCE_DIR}/Memory.sv
        ${CMAKE_CURRENT_SOURCE_DIR}/Input.sv
        ${CMAKE_CURRENT_SOURCE_DIR}/Serial.sv
        ${CMAKE_CURRENT_SOURCE_DIR}/Timer.sv
        ${CMAKE_CURRENT_SOURCE_DIR}/Gameboy.sv
)

get_target_property(GB_PACKAGES gb_rtl INTERFACE_GB_PACKAGES)
get_target_property(GB_INTERFACES gb_rtl INTERFACE_GB_INTERFACES)
get_target_property(GB_SOURCES gb_rtl INTERFACE_GB_SOURCES)

set(GB_F_CONTENT
"${GB_PACKAGES}
${GB_INTERFACES}
${GB_SOURCES}
")

string(REPLACE ";" "\n" GB_F_CONTENT "${GB_F_CONTENT}")

set(GB_COMMAND_FILE ${CMAKE_CURRENT_BINARY_DIR}/gb.f)
file(WRITE ${GB_COMMAND_FILE} "${GB_F_CONTENT}\n")
file(APPEND ${GB_COMMAND_FILE} "+incdir+${CMAKE_CURRENT_SOURCE_DIR}\n")
file(APPEND ${GB_COMMAND_FILE} "+incdir+${GB_INCLUDE_DIR}\n")

verilate(libgb
    PREFIX VGameboy
    SOURCES 
        ${GB_PACKAGES}
        ${GB_INTERFACES}
        ${GB_SOURCES}
        ${CMAKE_CURRENT_SOURCE_DIR}/Gameboy.sv
    TOP_MODULE Gameboy
    VERILATOR_ARGS
        --sv
        --trace-vcd
        # -Wall
        -I${GB_INCLUDE_DIR}
        -O3
)

