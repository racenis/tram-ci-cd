# CMake toolchain for cross-compiling tram-world-editor to 64-bit Windows
# from a Linux host using the MinGW-w64 toolchain.
#
# Usage (from the tram-world-editor source tree, with tram-ci-cd checked out
# alongside it):
#   cmake -S . -B build-win \
#       -DCMAKE_TOOLCHAIN_FILE=../tram-ci-cd/cmake/toolchain-mingw-w64.cmake
#   cmake --build build-win -j
#
# Tested against Fedora's mingw64-* packages, where compilers live at
# /usr/bin/x86_64-w64-mingw32-{gcc,g++,windres} and the sysroot is at
# /usr/x86_64-w64-mingw32/sys-root/mingw. Debian/Ubuntu's binutils-mingw-w64
# + g++-mingw-w64-x86-64 packages use the same triple, so this works there too
# (the sysroot path differs but we never hardcode it below — CMake discovers it
# via the compiler).

set(CMAKE_SYSTEM_NAME Windows)

# MINGW_TRIPLE can be overridden with -DMINGW_TRIPLE=i686-w64-mingw32 to
# produce a 32-bit .exe using the same toolchain file (tram-ci-cd/win32
# does this).
if(NOT DEFINED MINGW_TRIPLE)
    set(MINGW_TRIPLE x86_64-w64-mingw32)
endif()

if(MINGW_TRIPLE MATCHES "^i686")
    set(CMAKE_SYSTEM_PROCESSOR x86)
else()
    set(CMAKE_SYSTEM_PROCESSOR x86_64)
endif()

set(CMAKE_C_COMPILER   ${MINGW_TRIPLE}-gcc)
set(CMAKE_CXX_COMPILER ${MINGW_TRIPLE}-g++)
set(CMAKE_RC_COMPILER  ${MINGW_TRIPLE}-windres)
set(CMAKE_AR           ${MINGW_TRIPLE}-ar CACHE FILEPATH "")
set(CMAKE_RANLIB       ${MINGW_TRIPLE}-ranlib CACHE FILEPATH "")

# Only search the MinGW sysroot for libraries and headers — prevents CMake
# from accidentally picking up host-native Linux libs.
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

# Fedora convention. If this path doesn't exist on your distro, either symlink
# your sysroot to match or set CMAKE_FIND_ROOT_PATH on the cmake command line.
if(NOT DEFINED CMAKE_FIND_ROOT_PATH)
    set(CMAKE_FIND_ROOT_PATH /usr/${MINGW_TRIPLE}/sys-root/mingw)
endif()

# Point FindwxWidgets at the MinGW wx-config wrapper that Fedora's
# mingw64-wxWidgets package installs.
if(NOT DEFINED wxWidgets_CONFIG_EXECUTABLE
   AND EXISTS /usr/${MINGW_TRIPLE}/sys-root/mingw/bin/wx-config)
    set(wxWidgets_CONFIG_EXECUTABLE
        /usr/${MINGW_TRIPLE}/sys-root/mingw/bin/wx-config
        CACHE FILEPATH "MinGW wx-config")
endif()
