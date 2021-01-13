cmake_minimum_required(VERSION 3.7)

PROJECT("lua-linenoise")

ENABLE_TESTING()
INCLUDE(cmake/version.cmake)
INCLUDE(cmake/platform.cmake)
MESSAGE("Building for: ${JONCHKI_PLATFORM}")

OPTION(BUILDCFG_ONLY_JONCHKI_CFG "Build only the jonchki configuration. This is used for the resolve phase. The default is OFF."
       "OFF")


#----------------------------------------------------------------------------
#
# Include the projects in the subdirectories.
#

ADD_SUBDIRECTORY(lua-linenoise)


#----------------------------------------------------------------------------

