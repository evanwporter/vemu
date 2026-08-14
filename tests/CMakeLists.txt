include(ExternalProject)

ExternalProject_Add(
  libtonc_examples
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/libtonc-examples
  PREFIX ${CMAKE_CURRENT_BINARY_DIR}/libtonc_examples
  STAMP_DIR ${CMAKE_CURRENT_BINARY_DIR}/libtonc_examples/stamp
  TMP_DIR ${CMAKE_CURRENT_BINARY_DIR}/libtonc_examples/tmp
  CONFIGURE_COMMAND
    compiledb -n --full-path -o
    ${CMAKE_CURRENT_BINARY_DIR}/libtonc_examples/compile_commands.json make
  BUILD_COMMAND make
  BUILD_IN_SOURCE 1
  INSTALL_COMMAND "")

add_custom_target(
  merge_compile_commands ALL
  COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_BINARY_DIR}/clangd
  COMMAND
    jq -s 'add | unique_by(.file)' ${CMAKE_BINARY_DIR}/compile_commands.json
    ${CMAKE_CURRENT_BINARY_DIR}/libtonc_examples/compile_commands.json >
    ${CMAKE_BINARY_DIR}/clangd/compile_commands.tmp.json
  COMMAND
    ${CMAKE_COMMAND} -E rename
    ${CMAKE_BINARY_DIR}/clangd/compile_commands.tmp.json
    ${CMAKE_BINARY_DIR}/clangd/compile_commands.json
  DEPENDS libtonc_examples
  COMMENT "Merging CMake and libtonc compile_commands.json")
