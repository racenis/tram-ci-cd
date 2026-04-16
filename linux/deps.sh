#!/usr/bin/env bash
# Install build dependencies for a native Linux build of the Tramway SDK.
# Works on Fedora 40+ and Debian 12+. Run as root (or with sudo).
set -euo pipefail

if [ -r /etc/os-release ]; then . /etc/os-release; fi

case "${ID:-}" in
    fedora)
        dnf install -y \
            gcc gcc-c++ make cmake git which rsync \
            bullet-devel lua-devel glfw-devel openal-soft-devel \
            mesa-libGL-devel mesa-libGLU-devel SDL2-devel \
            fpc fpc-src lazarus
        ;;
    debian|ubuntu)
        export DEBIAN_FRONTEND=noninteractive
        apt-get update
        apt-get install -y --no-install-recommends \
            build-essential cmake git ca-certificates rsync \
            libbullet-dev liblua5.4-dev libglfw3-dev libopenal-dev \
            libgl1-mesa-dev libglu1-mesa-dev libsdl2-dev \
            fpc lazarus
        ;;
    *)
        echo "Unsupported distro: ${ID:-unknown}" >&2
        exit 1
        ;;
esac
