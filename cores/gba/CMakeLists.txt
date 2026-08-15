# TODO: The CMake is incredibly messy right now. Clean it up.

set(GBA_SRC_DIR ${CMAKE_CURRENT_SOURCE_DIR}/rtl)

add_library(gba_rtl INTERFACE)

function(gba_add_rtl)
  cmake_parse_arguments(ARG "" "" "PACKAGES;INTERFACES;SOURCES" ${ARGN})

  if(ARG_PACKAGES)
    set_property(
      TARGET gba_rtl
      APPEND
      PROPERTY INTERFACE_GBA_PACKAGES ${ARG_PACKAGES})
  endif()

  if(ARG_INTERFACES)
    set_property(
      TARGET gba_rtl
      APPEND
      PROPERTY INTERFACE_GBA_INTERFACES ${ARG_INTERFACES})
  endif()

  if(ARG_SOURCES)
    set_property(
      TARGET gba_rtl
      APPEND
      PROPERTY INTERFACE_GBA_SOURCES ${ARG_SOURCES})
  endif()
endfunction()

set(GBA_INCLUDE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/include)

add_subdirectory(rtl)

# target_sources(libgba PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/sim/gb.cpp)

target_include_directories(libgba PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/sim/)

find_package(SDL2 CONFIG REQUIRED)
target_link_libraries(libgba PUBLIC SDL2::SDL2)

set(GBA_BIOS_PATH "${CMAKE_SOURCE_DIR}/tests/gba_bios.bin"
    CACHE FILEPATH "Absolute path to a 16 KiB GBA BIOS image")
get_filename_component(GBA_BIOS_PATH "${GBA_BIOS_PATH}" ABSOLUTE)
if(NOT EXISTS "${GBA_BIOS_PATH}")
  message(FATAL_ERROR "GBA BIOS not found: ${GBA_BIOS_PATH}")
endif()

target_compile_definitions(
  libgba
  PUBLIC TEST_DIR="${CMAKE_SOURCE_DIR}/tests/"
         SOURCE_DIR="${CMAKE_CURRENT_SOURCE_DIR}"
         GBA_BIOS_PATH="${GBA_BIOS_PATH}")
add_subdirectory(sim)
add_subdirectory(tests)

find_package(Verilator REQUIRED HINTS $ENV{VERILATOR_ROOT})
