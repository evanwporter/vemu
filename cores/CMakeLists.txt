add_subdirectory(gb)
add_subdirectory(gba)

file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/slang.f "-f ${CMAKE_CURRENT_BINARY_DIR}/gb/rtl/gb.f\n")
file(APPEND ${CMAKE_CURRENT_BINARY_DIR}/slang.f "-f ${CMAKE_CURRENT_BINARY_DIR}/gba/rtl/gba.f\n")