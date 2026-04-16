#!/usr/bin/env bash
# Install cross-toolchain for mingw-w64 i686 (32-bit, XP-compatible) + FPC cross to win32.
# Works on Fedora 40+ and Debian 12+. Run as root (or with sudo).
set -euo pipefail

if [ -r /etc/os-release ]; then . /etc/os-release; fi

case "${ID:-}" in
    fedora)
        # Bullet/Lua/GLFW/OpenAL/SDL2 static libs come from
        # tram-sdk/libraries/binaries/win32/ — Fedora doesn't package all the
        # mingw32-* variants. Just install the toolchain + rsync.
        dnf install -y \
            git make cmake which rsync \
            mingw32-gcc mingw32-gcc-c++ \
            mingw32-winpthreads mingw32-winpthreads-static \
            fpc fpc-src lazarus
        ;;
    debian|ubuntu)
        export DEBIAN_FRONTEND=noninteractive
        apt-get update
        apt-get install -y --no-install-recommends \
            git make cmake ca-certificates rsync \
            mingw-w64 g++-mingw-w64-i686 \
            fpc lazarus
        echo "NOTE: Debian does not package mingw cross builds of bullet/lua/glfw/openal."
        ;;
    *)
        echo "Unsupported distro: ${ID:-unknown}" >&2
        exit 1
        ;;
esac
