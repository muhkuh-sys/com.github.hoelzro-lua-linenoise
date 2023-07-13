cmake_minimum_required(VERSION 3.7)

PROJECT("linenoise")

INCLUDE(ExternalProject)

SET(SUB_CMAKE_ARGS "")
LIST(APPEND SUB_CMAKE_ARGS "-DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}")
LIST(APPEND SUB_CMAKE_ARGS "-DCMAKE_TESTS_DIRECTORY=${CMAKE_HOME_DIRECTORY}/../cmake/tests")
LIST(APPEND SUB_CMAKE_ARGS "-DCMAKE_INSTALL_PREFIX=''")


ExternalProject_Add(TARGET_linenoise
                    PREFIX ${CMAKE_CURRENT_BINARY_DIR}/linenoise
                    URL ${CMAKE_CURRENT_SOURCE_DIR}/linenoise-4a12be854d95.zip
                    URL_HASH SHA1=c353bc18f63cbf9aeffe057cfee908b7f76fb52c
                    PATCH_COMMAND ${CMAKE_COMMAND} -E copy_directory ${CMAKE_CURRENT_SOURCE_DIR}/copy-over ${CMAKE_CURRENT_BINARY_DIR}/linenoise/src/TARGET_linenoise
                    CMAKE_ARGS ${SUB_CMAKE_ARGS}
                    TEST_COMMAND make test
                    INSTALL_COMMAND make install DESTDIR=${CMAKE_CURRENT_BINARY_DIR}/install
)
