#!/usr/bin/env bash
# Install cross-toolchain for mingw-w64 x86_64 builds + FPC/Lazarus cross to win64.
# Works on Fedora 40+ and Debian 12+. Run as root (or with sudo).
set -euo pipefail

if [ -r /etc/os-release ]; then . /etc/os-release; fi

case "${ID:-}" in
    fedora)
        # Bullet/Lua/GLFW/OpenAL static libs come from tram-sdk/libraries/binaries/win64/
        # so we don't need Fedora's mingw64-* packages for those (which aren't all
        # packaged anyway). Just the toolchain + rsync.
        dnf install -y \
            git make cmake which rsync \
            mingw64-gcc mingw64-gcc-c++ \
            mingw64-winpthreads mingw64-winpthreads-static \
            fpc fpc-src lazarus
        ;;
    debian|ubuntu)
        export DEBIAN_FRONTEND=noninteractive
        apt-get update
        apt-get install -y --no-install-recommends \
            git make cmake ca-certificates rsync \
            mingw-w64 g++-mingw-w64-x86-64 \
            fpc lazarus
        ;;
    *)
        echo "Unsupported distro: ${ID:-unknown}" >&2
        exit 1
        ;;
esac
