find_package(GTest CONFIG REQUIRED)

add_library(test_image_gba)

target_sources(test_image_gba PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/test_image.cpp)

target_link_libraries(test_image_gba PUBLIC libgba GameboyAdvanceHarness
                                            GTest::gtest libcommon)

target_include_directories(test_image_gba PRIVATE ${GBA_TESTS_CPP_DIR})

target_compile_definitions(test_image_gba
                           PUBLIC TEST_DIR="${CMAKE_SOURCE_DIR}/tests/")
