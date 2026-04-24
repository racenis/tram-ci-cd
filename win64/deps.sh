#!/usr/bin/env bash
# Install cross-toolchain for mingw-w64 x86_64 builds + FPC/Lazarus cross to win64.
# Works on Fedora 40+ and Debian 12+. Run as root (or with sudo).
set -euo pipefail

if [ -r /etc/os-release ]; then . /etc/os-release; fi

case "${ID:-}" in
    fedora)
        # Bullet/Lua/GLFW/OpenAL static libs come from tram-sdk/libraries/binaries/win64/
        # so we don't need Fedora's mingw64-* packages for those (which aren't all
        # packaged anyway). The editor fetches and cross-compiles wxWidgets from
        # source — wxMSW is self-contained and ships its own zlib/libpng/libjpeg/
        # libtiff submodules, so no mingw64-wxWidgets* needed here.
        dnf install -y \
            git make cmake ninja-build which rsync \
            mingw64-gcc mingw64-gcc-c++ \
            mingw64-winpthreads mingw64-winpthreads-static \
            mingw64-mesa-libGL \
            fpc fpc-src lazarus
        ;;
    debian|ubuntu)
        export DEBIAN_FRONTEND=noninteractive
        apt-get update
        apt-get install -y --no-install-recommends \
            git make cmake ninja-build ca-certificates rsync \
            mingw-w64 g++-mingw-w64-x86-64 \
            fpc lazarus
        ;;
    *)
        echo "Unsupported distro: ${ID:-unknown}" >&2
        exit 1
        ;;
esac
