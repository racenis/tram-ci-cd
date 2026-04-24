#!/usr/bin/env bash
# Builds tram-world-editor for Linux and Windows from a single source tree.
# Designed to run inside the editor-dev Dockerfile image — but works on any
# Fedora-like host with the same packages installed.
#
# Env vars:
#   SRC                path to tram-world-editor (default: /src, else script sibling)
#   TRAM_SDK_DIR       path to tram-sdk sources (default: /sdk, else sibling of SRC)
#   EDITOR_TOOLCHAIN   MinGW toolchain file (default: /opt/cmake/toolchain-mingw-w64.cmake,
#                      else ../cmake/toolchain-mingw-w64.cmake next to this script)
#   BUILD_TYPE         CMake build type (default: Release)
#   JOBS               parallel job count (default: all CPUs)

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_TYPE="${BUILD_TYPE:-Release}"
JOBS="${JOBS:-$(nproc)}"

# --- Locate editor source ---
if [[ -z "${SRC:-}" ]]; then
    if   [[ -d /src/src ]];                               then SRC=/src
    elif [[ -d "$HERE/../../tram-world-editor/src" ]];    then SRC="$HERE/../../tram-world-editor"
    else
        echo "error: tram-world-editor not found. Mount at /src or set SRC." >&2
        exit 1
    fi
fi

# --- Locate SDK ---
if [[ -z "${TRAM_SDK_DIR:-}" ]]; then
    if   [[ -d /sdk/src ]];                 then TRAM_SDK_DIR=/sdk
    elif [[ -d "$SRC/../tram-sdk/src" ]];   then TRAM_SDK_DIR="$SRC/../tram-sdk"
    else
        echo "error: tram-sdk not found. Mount at /sdk or set TRAM_SDK_DIR." >&2
        exit 1
    fi
fi

# --- Locate MinGW toolchain file (relocated to tram-ci-cd/cmake/) ---
if [[ -z "${EDITOR_TOOLCHAIN:-}" ]]; then
    if   [[ -f /opt/cmake/toolchain-mingw-w64.cmake ]];        then EDITOR_TOOLCHAIN=/opt/cmake/toolchain-mingw-w64.cmake
    elif [[ -f "$HERE/../cmake/toolchain-mingw-w64.cmake" ]];  then EDITOR_TOOLCHAIN="$HERE/../cmake/toolchain-mingw-w64.cmake"
    else
        echo "error: MinGW toolchain file not found. Set EDITOR_TOOLCHAIN." >&2
        exit 1
    fi
fi

echo "== tram-world-editor CI build =="
echo "   source:     $SRC"
echo "   tram-sdk:   $TRAM_SDK_DIR"
echo "   toolchain:  $EDITOR_TOOLCHAIN"
echo "   type:       $BUILD_TYPE"
echo "   jobs:       $JOBS"

# --- Linux native ---------------------------------------------------------
echo
echo "== Linux native build =="
cmake -S "$SRC" -B "$SRC/build-linux" -G Ninja \
    -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
    -DTRAM_SDK_DIR="$TRAM_SDK_DIR"
cmake --build "$SRC/build-linux" -j "$JOBS"
file "$SRC/build-linux/tedit"

# --- Windows (MinGW cross) -----------------------------------------------
echo
echo "== Windows MinGW cross build =="
cmake -S "$SRC" -B "$SRC/build-windows" -G Ninja \
    -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
    -DCMAKE_TOOLCHAIN_FILE="$EDITOR_TOOLCHAIN" \
    -DTRAM_SDK_DIR="$TRAM_SDK_DIR"
cmake --build "$SRC/build-windows" -j "$JOBS"
file "$SRC/build-windows/tedit.exe"

echo
echo "Artifacts:"
echo "  $SRC/build-linux/tedit"
echo "  $SRC/build-windows/tedit.exe"
