#!/usr/bin/env bash
# Orchestrator for a full release build: integrations gate → linux + win64 + win32 + installer.
# Builds each image, runs it with the projects/ tree mounted, collects artifacts.
#
# Run from tram-ci-cd/. Expects sibling repos at ../tram-sdk, ../tram-template, ../tram-applets.
#
# Set SKIP_INTEGRATIONS=1 to bypass the gating CI phase for a fast platform-only rebuild.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECTS_DIR="${PROJECTS_DIR:-$(cd "$HERE/.." && pwd)}"
OUT_ROOT="${OUT_ROOT:-$HERE/out}"
mkdir -p "$OUT_ROOT"/{linux,win64,win32,installer}

build_and_run() {
    local target="$1"
    local tag="tram-ci-cd-$target"
    echo "===================================="
    echo "  [$target] docker build"
    echo "===================================="
    docker build -t "$tag" "$HERE/$target"
    echo "===================================="
    echo "  [$target] docker run"
    echo "===================================="
    docker run --rm \
        -v "$PROJECTS_DIR":/projects:ro \
        -v "$OUT_ROOT/$target":/out \
        "$tag"
}

# Gate: full CI suite (compile-check + unit tests + matrix + integration regressions).
# Failures here block the release build — no point cross-compiling broken code.
# The integrations Dockerfile sits at integrations/Dockerfile but uses tram-ci-cd/
# as its build context (it COPYs from linux/ too), so use -f to point at it.
if [ "${SKIP_INTEGRATIONS:-0}" != "1" ]; then
    echo "===================================="
    echo "  [integrations] docker build"
    echo "===================================="
    docker build -t tram-ci-cd-integrations -f "$HERE/integrations/Dockerfile" "$HERE"
    echo "===================================="
    echo "  [integrations] docker run"
    echo "===================================="
    docker run --rm -v "$PROJECTS_DIR":/projects:ro tram-ci-cd-integrations
fi

build_and_run linux
build_and_run win64
build_and_run win32

# Installer needs the win64 artifacts + sources mounted.
echo "===================================="
echo "  [installer] docker build"
echo "===================================="
docker build -t tram-ci-cd-installer "$HERE/installer"
echo "===================================="
echo "  [installer] docker run"
echo "===================================="
docker run --rm \
    -v "$PROJECTS_DIR":/projects:ro \
    -v "$OUT_ROOT/win64":/win-build:ro \
    -v "$OUT_ROOT/installer":/out \
    -e WIN_BUILD_DIR=/win-build \
    tram-ci-cd-installer

echo "==> release artifacts in $OUT_ROOT"
ls -la "$OUT_ROOT"/*
