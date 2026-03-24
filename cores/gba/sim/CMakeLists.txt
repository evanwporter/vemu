add_library(GameboyAdvanceHarness)

add_subdirectory(src)
target_include_directories(GameboyAdvanceHarness PUBLIC include)
target_link_libraries(GameboyAdvanceHarness PUBLIC
    libgba 
    libcommon
)