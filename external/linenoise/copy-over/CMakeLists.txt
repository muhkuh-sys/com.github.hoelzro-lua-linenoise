CMAKE_MINIMUM_REQUIRED(VERSION 3.7)

PROJECT("linenoise")

ENABLE_TESTING()
FIND_PACKAGE(PythonInterp 2.7 REQUIRED)

# Build the Lua module.
ADD_LIBRARY(TARGET_linenoise STATIC
            linenoise.c
            stringbuf.c
            utf8.c)
TARGET_INCLUDE_DIRECTORIES(TARGET_linenoise
                           PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
TARGET_COMPILE_DEFINITIONS(TARGET_linenoise
                           PUBLIC USE_UTF8)
TARGET_COMPILE_OPTIONS(TARGET_linenoise
                       PRIVATE -fPIC)

# Set the name of the output file to "linenoise".
SET_TARGET_PROPERTIES(TARGET_linenoise PROPERTIES PREFIX "" OUTPUT_NAME "linenoise")

# On mingw link all compiler libraries static.
IF((${CMAKE_SYSTEM_NAME} STREQUAL "Windows") AND (${CMAKE_COMPILER_IS_GNUCC}))
	SET_PROPERTY(TARGET TARGET_linenoise PROPERTY LINK_FLAGS "-static -static-libgcc -static-libstdc++")
ENDIF((${CMAKE_SYSTEM_NAME} STREQUAL "Windows") AND (${CMAKE_COMPILER_IS_GNUCC}))

# Install the lua module.
INSTALL(TARGETS TARGET_linenoise
        EXPORT EXPORT_package
        LIBRARY DESTINATION lib
        ARCHIVE DESTINATION lib
        RUNTIME DESTINATION bin
        INCLUDES DESTINATION include)
# Install the header files.
INSTALL(FILES linenoise.h
        DESTINATION include)

# Add tests for this module.
IF((${CMAKE_SYSTEM_NAME} STREQUAL "Windows") AND (${CMAKE_COMPILER_IS_GNUCC}))
	# Here are the MinGW specific tests.
	ADD_TEST(NAME linenoise_MinGW_DLL_dependencies
	         COMMAND "${PYTHON_EXECUTABLE}" ${CMAKE_TESTS_DIRECTORY}/mingw_dll_dependencies.py -u lua5.1 -u lua5.2 -u lua5.3 -u lua5.4 $<TARGET_FILE:TARGET_linenoise>)
ENDIF((${CMAKE_SYSTEM_NAME} STREQUAL "Windows") AND (${CMAKE_COMPILER_IS_GNUCC}))
