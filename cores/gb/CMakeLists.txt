# TODO: The CMake is incredibly messy right now. Clean it up.

set(GB_SRC_DIR ${CMAKE_CURRENT_SOURCE_DIR}/rtl)

add_library(gb_rtl INTERFACE)

function(gb_add_rtl)
    cmake_parse_arguments(ARG "" "" "PACKAGES;INTERFACES;SOURCES" ${ARGN})

    if(ARG_PACKAGES)
        set_property(TARGET gb_rtl APPEND PROPERTY
            INTERFACE_GB_PACKAGES ${ARG_PACKAGES})
    endif()

    if(ARG_INTERFACES)
        set_property(TARGET gb_rtl APPEND PROPERTY
            INTERFACE_GB_INTERFACES ${ARG_INTERFACES})
    endif()

    if(ARG_SOURCES)
        set_property(TARGET gb_rtl APPEND PROPERTY
            INTERFACE_GB_SOURCES ${ARG_SOURCES})
    endif()
endfunction()

set(GB_INCLUDE_DIR
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)

add_subdirectory(rtl)

target_sources(libgb PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/sim/gb.cpp)

target_include_directories(libgb PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/sim/)

find_package(SDL2 CONFIG REQUIRED)
target_link_libraries(libgb PUBLIC
    SDL2::SDL2
)

target_compile_definitions(libgb PUBLIC
    TEST_DIR="${CMAKE_SOURCE_DIR}/tests/"
    SOURCE_DIR="${CMAKE_CURRENT_SOURCE_DIR}"
)

add_subdirectory(tests)

find_package(Verilator REQUIRED HINTS $ENV{VERILATOR_ROOT})

find_package(argparse CONFIG REQUIRED)

add_executable(gb ${CMAKE_CURRENT_SOURCE_DIR}/sim/main.cpp)

target_include_directories(gb PRIVATE
    ${CMAKE_BINARY_DIR}/gb/CMakeFiles/libgb.dir/VGameboy.dir
    ${VERILATOR_ROOT}/include
)

target_link_libraries(gb PRIVATE
    libgb
    argparse::argparse
    GameboyHarness
)

add_subdirectory(debug)
add_subdirectory(sim)
