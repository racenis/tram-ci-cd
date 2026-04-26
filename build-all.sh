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
mkdir -p "$OUT_ROOT"/{linux-fedora,linux-debian,win64,win32,installer}

build_and_run() {
    local target="$1"
    local tag="tram-ci-cd-$target"
    echo "===================================="
    echo "  [$target] docker build"
    echo "===================================="
    # win64/win32 COPY cmake/toolchain-mingw-w64.cmake and linux-fedora/
    # + linux-debian/ COPY from shared linux/; they all need tram-ci-cd/ as
    # the docker build context. integrations/ and installer/ already use
    # parent context via their existing -f invocations further down.
    case "$target" in
        win64|win32|linux-fedora|linux-debian)
            docker build -t "$tag" -f "$HERE/$target/Dockerfile" "$HERE"
            ;;
        *)
            docker build -t "$tag" "$HERE/$target"
            ;;
    esac
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

build_and_run linux-fedora
build_and_run linux-debian
build_and_run win64
build_and_run win32

# Installer needs the win artifacts + sources mounted. Run once per target so
# we ship a separate installer for win64 and win32.
echo "===================================="
echo "  [installer] docker build"
echo "===================================="
docker build -t tram-ci-cd-installer "$HERE/installer"
for arch in win64 win32; do
    echo "===================================="
    echo "  [installer:$arch] docker run"
    echo "===================================="
    mkdir -p "$OUT_ROOT/installer/$arch"
    docker run --rm \
        -v "$PROJECTS_DIR":/projects:ro \
        -v "$OUT_ROOT/$arch":/win-build:ro \
        -v "$OUT_ROOT/installer/$arch":/out \
        -e WIN_BUILD_DIR=/win-build \
        tram-ci-cd-installer
done

echo "==> release artifacts in $OUT_ROOT"
ls -la "$OUT_ROOT"/*
