gba_add_rtl(
    PACKAGES
        ${CMAKE_CURRENT_SOURCE_DIR}/types.sv
        ${CMAKE_CURRENT_SOURCE_DIR}/vram_types.sv
    INTERFACES
    SOURCES
        ${CMAKE_CURRENT_SOURCE_DIR}/util.sv
        ${CMAKE_CURRENT_SOURCE_DIR}/PPU.sv)
