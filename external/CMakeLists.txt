cmake_minimum_required(VERSION 3.7)

PROJECT("external")

INCLUDE(${CMAKE_SOURCE_DIR}/../cmake/platform.cmake)


#----------------------------------------------------------------------------
#
# Include the projects in the subdirectories.
#
ADD_SUBDIRECTORY(linenoise)


#----------------------------------------------------------------------------
