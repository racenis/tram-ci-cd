#!/usr/bin/env bash
# Install build dependencies for a native Linux build of the Tramway SDK.
# Works on Fedora 40+ and Debian 12+. Run as root (or with sudo).
set -euo pipefail

if [ -r /etc/os-release ]; then . /etc/os-release; fi

case "${ID:-}" in
    fedora)
        # Editor builds wxWidgets from source via FetchContent; wxGTK on Linux
        # needs GTK3 + image/compression libs. No wx-*-devel packages needed.
        dnf install -y \
            gcc gcc-c++ make cmake ninja-build git which rsync \
            bullet-devel lua-devel glfw-devel openal-soft-devel \
            mesa-libGL-devel mesa-libGLU-devel SDL2-devel \
            gtk3-devel libpng-devel libjpeg-turbo-devel libtiff-devel \
            zlib-devel expat-devel \
            fpc fpc-src lazarus
        ;;
    debian|ubuntu)
        export DEBIAN_FRONTEND=noninteractive
        apt-get update
        apt-get install -y --no-install-recommends \
            build-essential cmake ninja-build git ca-certificates rsync \
            libbullet-dev liblua5.4-dev libglfw3-dev libopenal-dev \
            libgl1-mesa-dev libglu1-mesa-dev libsdl2-dev \
            libgtk-3-dev libpng-dev libjpeg-dev libtiff-dev \
            zlib1g-dev libexpat1-dev \
            fpc lazarus
        ;;
    *)
        echo "Unsupported distro: ${ID:-unknown}" >&2
        exit 1
        ;;
esac
