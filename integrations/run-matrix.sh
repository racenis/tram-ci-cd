#!/usr/bin/env bash
# Matrix compile-check: build the SDK with one non-default toggle at a time.
# Baseline is OpenGL + Bullet + OpenAL + GLFW. For each variant we flip a single
# option and verify the build still produces libtramsdk.a + links src/main.cpp
# against it. This catches breakage in individual subsystems without a full
# combinatorial explosion.
set -euo pipefail

TRAM_ROOT="${TRAM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
WORK_DIR="${WORK_DIR:-/tmp/tram-build-matrix}"
JOBS="${JOBS:-$(nproc)}"

echo "==> TRAM_ROOT=$TRAM_ROOT"
echo "==> WORK_DIR=$WORK_DIR"

# Stage the SDK into a writable scratch dir — TRAM_ROOT is mounted read-only
# under /projects in CI, and CMake drops build artifacts inside the source tree.
mkdir -p "$WORK_DIR"
rsync -a --delete \
      --exclude='.git' --exclude='build*' \
      --exclude='*.o' --exclude='*.a' \
      "$TRAM_ROOT/tram-sdk/" "$WORK_DIR/tram-sdk/"
SDK="$WORK_DIR/tram-sdk"

# Variants: each is a space-separated list of -D args appended to the baseline.
# Baseline (no extra args) is the first entry.
VARIANTS=(
    "baseline"
    "-DPLATFORM_GLFW=OFF -DPLATFORM_SDL=ON"
    "-DAUDIO_OPENAL=OFF -DAUDIO_TEMPLATE=ON"
    "-DEXTENSION_CAMERA=OFF"
    "-DEXTENSION_MENU=OFF"
    "-DEXTENSION_LUA=OFF"
    "-DEXTENSION_KITCHENSINK=OFF"
    # TODO: RENDER_SOFTWARE and RENDER_DIRECT3D require SDL platform — add
    # combined variants once baseline is green.
)

# Variant link failures expected — tram-sdk/src/main.cpp references every
# extension unconditionally and the SDL platform replacement, so disabling those
# breaks the post-build link-check even though libtramsdk.a itself builds fine.
# Tracked so only *new* breakage (e.g. baseline failing) flips CI red.
KNOWN_FAILING=(
    "-DPLATFORM_GLFW=OFF -DPLATFORM_SDL=ON:link"
    "-DEXTENSION_CAMERA=OFF:link"
    "-DEXTENSION_MENU=OFF:link"
    "-DEXTENSION_LUA=OFF:link"
    "-DEXTENSION_KITCHENSINK=OFF:link"
)

FAILED=()
KNOWN_OBSERVED=()
record_failure() {
    local entry="$1"
    local known
    for known in "${KNOWN_FAILING[@]}"; do
        if [ "$known" = "$entry" ]; then
            KNOWN_OBSERVED+=("$entry")
            return
        fi
    done
    FAILED+=("$entry")
}

for variant in "${VARIANTS[@]}"; do
    tag="${variant//[^a-zA-Z0-9]/_}"
    build_dir="$WORK_DIR/build-$tag"
    rm -rf "$build_dir"
    echo "==> matrix variant: ${variant}"
    if [ "$variant" = "baseline" ]; then
        set -- "-B" "$build_dir" "-S" "$SDK"
    else
        # shellcheck disable=SC2086
        set -- "-B" "$build_dir" "-S" "$SDK" $variant
    fi
    if ! cmake "$@"; then record_failure "$variant:configure"; continue; fi
    if ! cmake --build "$build_dir" -j"$JOBS"; then record_failure "$variant:build"; continue; fi

    # Link-check: compile src/main.cpp against the produced library.
    exe="$build_dir/sdk_main"
    if ! g++ -std=c++20 -I"$SDK/src" -I"$SDK/libraries" \
             "$SDK/src/main.cpp" "$build_dir/libtramsdk.a" \
             -lglfw -lopenal -lGL -lBulletSoftBody -lBulletDynamics \
             -lBulletCollision -lLinearMath -llua -lpthread \
             -o "$exe"; then
        record_failure "$variant:link"
    fi
done

if [ "${#KNOWN_OBSERVED[@]}" -gt 0 ]; then
    echo "==> known-failing (acknowledged, not failing CI):"
    printf '    %s\n' "${KNOWN_OBSERVED[@]}"
fi
if [ "${#FAILED[@]}" -gt 0 ]; then
    echo "==> matrix regressions:" >&2
    printf '    %s\n' "${FAILED[@]}" >&2
    exit 1
fi
echo "==> all matrix variants built (or known-failing)"
