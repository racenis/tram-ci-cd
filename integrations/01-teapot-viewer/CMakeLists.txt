# Teapot integration. Layered on top of a staged tram-template tree —
# run-regression.sh rsyncs the template over this directory, so the
# template's CMakeLists is overwritten by this file.
cmake_minimum_required(VERSION 3.16)
project(teapot CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Caller passes:
#   -DTRAM_SDK_SRC=/path/to/tram-sdk   (headers: src/ + libraries/)
#   -DTRAM_SDK_LIB=/path/to/build-dir  (directory containing libtramsdk.a)
# Falls back to a combined TRAM_SDK_DIR for the common case where both live
# together (e.g. a plain source checkout with libtramsdk.a next to Makefile).
if(NOT DEFINED TRAM_SDK_SRC)
    set(TRAM_SDK_SRC "${TRAM_SDK_DIR}")
endif()
if(NOT DEFINED TRAM_SDK_LIB)
    set(TRAM_SDK_LIB "${TRAM_SDK_DIR}")
endif()

include_directories(
    ${TRAM_SDK_SRC}/src
    ${TRAM_SDK_SRC}/libraries
)

add_executable(teapot src/main.cpp)

target_link_directories(teapot PRIVATE ${TRAM_SDK_LIB})
target_link_libraries(teapot PRIVATE
    tramsdk
    glfw openal GL pthread
    BulletSoftBody BulletDynamics BulletCollision LinearMath
    lua
)
