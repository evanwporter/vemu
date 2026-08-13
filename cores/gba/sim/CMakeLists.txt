add_library(GameboyAdvanceHarness)

add_subdirectory(src)
target_include_directories(GameboyAdvanceHarness PUBLIC include)
target_link_libraries(GameboyAdvanceHarness PUBLIC
    libgba 
    libcommon
)

add_executable(gba ${CMAKE_CURRENT_SOURCE_DIR}/src/main.cpp)
target_link_libraries(gba PRIVATE GameboyAdvanceHarness)
