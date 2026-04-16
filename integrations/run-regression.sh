#!/usr/bin/env bash
# Build each integration under integrations/<NN-name>/, then for each test case
# listed in its tests.txt run the binary (under Xvfb + Mesa llvmpipe) and diff
# the dumped PNG against baseline/<test_name>.png.
#
# Directory layout per integration:
#     integrations/01-teapot-viewer/
#         CMakeLists.txt
#         src/main.cpp         — accepts --out=PATH --tick=N
#         tests.txt            — optional, format: "<test_name>|<args>" per line
#         baseline/<name>.png  — reference screenshot per test
#
# If tests.txt is absent, a single test named "default" runs with no extra args
# and the baseline is baseline/default.png.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TRAM_ROOT="${TRAM_ROOT:-$(cd "$HERE/../.." && pwd)}"
TEMPLATE_SRC="${TEMPLATE_SRC:-$TRAM_ROOT/tram-template}"
# Headers live in the source checkout; libtramsdk.a comes from Phase 1's build
# dir (/tmp/tram-build/tram-sdk) if that exists, otherwise next to sources.
TRAM_SDK_SRC="${TRAM_SDK_SRC:-$TRAM_ROOT/tram-sdk}"
TRAM_SDK_LIB="${TRAM_SDK_LIB:-/tmp/tram-build/tram-sdk}"
[ -f "$TRAM_SDK_LIB/libtramsdk.a" ] || TRAM_SDK_LIB="$TRAM_SDK_SRC"
DIFF_THRESHOLD="${DIFF_THRESHOLD:-1000}"  # magick AE: pixels differing by any amount

export DISPLAY=":99"
export LIBGL_ALWAYS_SOFTWARE=1
export GALLIUM_DRIVER=llvmpipe
# Tramway shaders are #version 400 core — llvmpipe supports 4.5, but it only
# advertises it if we explicitly opt in. Without this override Mesa caps the
# reported version at 3.1, GLFW's GL 4.0 request still wins but shaders using
# gl_Layer / explicit uniform locations / etc. silently fail to compile.
export MESA_GL_VERSION_OVERRIDE=4.5
export MESA_GLSL_VERSION_OVERRIDE=450

Xvfb :99 -screen 0 800x600x24 -nolisten tcp &
XVFB_PID=$!
trap 'kill $XVFB_PID 2>/dev/null || true' EXIT

FAILED=()

# Read the tests.txt manifest into two parallel arrays. A missing manifest
# yields a single test "default" with empty args.
load_tests() {
    local int_dir="$1"
    TEST_NAMES=()
    TEST_ARGS=()
    local manifest="$int_dir/tests.txt"
    if [ ! -f "$manifest" ]; then
        TEST_NAMES+=("default")
        TEST_ARGS+=("")
        return
    fi
    # NOTE: use _tname/_targs here — `read name` would clobber the outer-loop $name.
    while IFS='|' read -r _tname _targs; do
        [ -z "${_tname// }" ] && continue
        [[ "$_tname" == \#* ]] && continue
        TEST_NAMES+=("$(echo "$_tname" | xargs)")
        TEST_ARGS+=("$(echo "${_targs:-}" | xargs)")
    done < "$manifest"
}

# Sort-order the integration dirs so 01- runs before 02- etc.
for int_dir in $(printf '%s\n' "$HERE"/*/ | sort); do
    name="$(basename "$int_dir")"
    [ -f "$int_dir/src/main.cpp" ] || continue
    echo "==> integration: $name"

    # 1. Stage once per integration: template tree + integration overlay.
    stage="$(mktemp -d)"
    rsync -a --exclude='.git' --exclude='build*' --exclude='*.o' \
          "$TEMPLATE_SRC/" "$stage/"
    rsync -a --exclude='baseline' --exclude='tests.txt' \
          "$int_dir/" "$stage/"

    # 2. Build once per integration.
    if ! cmake -B "$stage/build" -S "$stage" \
               -DTRAM_SDK_SRC="$TRAM_SDK_SRC" -DTRAM_SDK_LIB="$TRAM_SDK_LIB"; then
        FAILED+=("$name:configure"); rm -rf "$stage"; continue
    fi
    if ! cmake --build "$stage/build" -j"$(nproc)"; then
        FAILED+=("$name:build"); rm -rf "$stage"; continue
    fi
    exe="$(find "$stage/build" -maxdepth 2 -type f -executable | head -n1)"
    if [ -z "$exe" ]; then
        FAILED+=("$name:no-binary"); rm -rf "$stage"; continue
    fi

    # 3. Run each test case.
    load_tests "$int_dir"
    mkdir -p "$int_dir/baseline"
    for i in "${!TEST_NAMES[@]}"; do
        tname="${TEST_NAMES[$i]}"
        targs="${TEST_ARGS[$i]}"
        echo "    ---- test: $tname (args: $targs)"
        out_png="$stage/${tname}.png"
        # The integration binary writes to --out relative to its cwd.
        (cd "$stage" && timeout 60 "$exe" --out="$out_png" $targs) || {
            FAILED+=("$name/$tname:run"); continue
        }
        if [ ! -f "$out_png" ]; then
            FAILED+=("$name/$tname:no-capture"); continue
        fi
        baseline="$int_dir/baseline/${tname}.png"
        if [ ! -f "$baseline" ]; then
            echo "        (no baseline — recording as ${tname}.png.new)"
            cp "$out_png" "$int_dir/baseline/${tname}.png.new"
            continue
        fi
        diff_raw=$(magick compare -metric AE "$baseline" "$out_png" \
                   "$int_dir/baseline/${tname}.diff.png" 2>&1 || true)
        diff_pixels="${diff_raw//[^0-9]/}"
        diff_pixels="${diff_pixels:-999999}"
        echo "        diff pixels: $diff_pixels (threshold $DIFF_THRESHOLD)"
        if [ "$diff_pixels" -gt "$DIFF_THRESHOLD" ]; then
            FAILED+=("$name/$tname:regression(${diff_pixels}px)")
            cp "$out_png" "$int_dir/baseline/${tname}.actual.png"
        fi
    done

    rm -rf "$stage"
done

if [ "${#FAILED[@]}" -gt 0 ]; then
    echo "==> regression failures:" >&2
    printf '    %s\n' "${FAILED[@]}" >&2
    exit 1
fi
echo "==> all integrations passed"
