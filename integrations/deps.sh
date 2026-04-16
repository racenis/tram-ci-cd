#!/usr/bin/env bash
# Dependencies for running CI checks: unit tests, matrix compile-checks, integration regressions.
# Builds on top of linux/deps.sh — adds software rendering (Mesa llvmpipe), Xvfb, ImageMagick.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$HERE/../linux/deps.sh"

if [ -r /etc/os-release ]; then . /etc/os-release; fi

case "${ID:-}" in
    fedora)
        # llvmpipe is shipped in mesa-dri-drivers; OSMesa isn't needed
        # (we use LIBGL_ALWAYS_SOFTWARE=1 + GALLIUM_DRIVER=llvmpipe).
        dnf install -y \
            mesa-dri-drivers mesa-libGL \
            xorg-x11-server-Xvfb \
            ImageMagick
        ;;
    debian|ubuntu)
        export DEBIAN_FRONTEND=noninteractive
        apt-get install -y --no-install-recommends \
            libgl1-mesa-dri \
            xvfb imagemagick
        ;;
esac
