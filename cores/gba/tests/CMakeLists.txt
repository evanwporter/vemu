set(GBA_TESTS_CPP_DIR ${CMAKE_CURRENT_SOURCE_DIR})

set(USE_SYSTEM_FMT
    ON
    CACHE BOOL "Use the development environment's fmt" FORCE)
add_subdirectory(golden/nba/src/nba)

if(NOT MSVC)
  get_target_property(NBA_COMPILE_OPTIONS nba COMPILE_OPTIONS)
  list(REMOVE_ITEM NBA_COMPILE_OPTIONS /bigobj)
  set_target_properties(nba PROPERTIES COMPILE_OPTIONS "${NBA_COMPILE_OPTIONS}")
endif()

add_subdirectory(cpu)
add_subdirectory(arm.gba)
add_subdirectory(thumb.gba)
add_subdirectory(image.gba)

add_executable(test_gba ${CMAKE_CURRENT_SOURCE_DIR}/main.cpp
                        ${CMAKE_CURRENT_SOURCE_DIR}/verilator_time.cpp)

add_subdirectory(util)

find_package(GTest CONFIG REQUIRED)
target_link_libraries(test_gba PRIVATE test_cpu_adv test_arm_gba test_thumb_gba
                                       test_image_gba GTest::gtest libcommon)

target_compile_definitions(test_gba
                           PRIVATE TEST_DIR="${CMAKE_SOURCE_DIR}/tests/")

target_include_directories(test_gba PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})

include(GoogleTest)
gtest_discover_tests(test_gba)
