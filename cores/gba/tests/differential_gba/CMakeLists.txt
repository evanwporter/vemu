find_package(nlohmann_json CONFIG REQUIRED)
find_package(GTest CONFIG REQUIRED)

add_library(test_differential_gba)

target_sources(
  test_differential_gba
  PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/gba_differential.cpp
  PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/test_jsmolka_gba.cpp
         ${CMAKE_CURRENT_SOURCE_DIR}/test_libtonc_examples.cpp)

target_link_libraries(
  test_differential_gba PUBLIC libgba nba GameboyAdvanceHarness GTest::gtest
                               nlohmann_json::nlohmann_json libcommon)

target_include_directories(
  test_differential_gba
  PRIVATE ${GBA_TESTS_CPP_DIR}
  PUBLIC ${CMAKE_SOURCE_DIR}/cores/gba/tests/golden/nba/src/nba/include
         ${CMAKE_SOURCE_DIR}/cores/gba/tests/golden/nba/src/
         ${CMAKE_SOURCE_DIR}/cores/gba/tests/golden/nba/src/nba/src)

target_compile_definitions(test_differential_gba
                           PUBLIC TEST_DIR="${CMAKE_SOURCE_DIR}/tests/")
