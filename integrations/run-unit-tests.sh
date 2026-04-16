#!/usr/bin/env bash
# Compile and run the unit tests in tram-sdk/tests/.
# The upstream Makefile hardcodes win64 library paths; we override for Linux.
set -euo pipefail

TRAM_ROOT="${TRAM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
# Prefer Phase 1's writable staging copy so test binaries land somewhere we can
# write — TRAM_ROOT/tram-sdk is the read-only source mount under CI.
WORK_SDK="${WORK_SDK:-/tmp/tram-build/tram-sdk}"
if [ -d "$WORK_SDK/tests" ]; then
    TESTS_DIR="$WORK_SDK/tests"
else
    TESTS_DIR="$TRAM_ROOT/tram-sdk/tests"
fi

cd "$TESTS_DIR"
CXX="${CXX:-g++}"
CXXFLAGS="-std=c++20 -I../src -I../libraries -I../libraries/glfw3"
LDLIBS="-lglfw -lGL -lpthread"

# Tests the user has acknowledged as broken — failures here are reported but
# don't fail the suite. New failures outside this list are treated as regressions.
KNOWN_FAILING=("settings:run" "aabb_tree:run")

FAILED=()
KNOWN_OBSERVED=()
for src in core.cpp uid.cpp event.cpp value.cpp file.cpp settings.cpp \
           aabb_tree.cpp hashmap.cpp octree.cpp pool.cpp queue.cpp stack.cpp stackpool.cpp; do
    name="${src%.cpp}"
    echo "==> unit: $name"
    result=""
    if ! $CXX $CXXFLAGS "$src" -o "$name" $LDLIBS; then
        echo "COMPILE FAIL: $name" >&2
        result="$name:compile"
    elif ! "./$name"; then
        echo "RUN FAIL: $name" >&2
        result="$name:run"
    fi
    if [ -n "$result" ]; then
        is_known=0
        for known in "${KNOWN_FAILING[@]}"; do
            if [ "$known" = "$result" ]; then is_known=1; break; fi
        done
        if [ "$is_known" = 1 ]; then
            KNOWN_OBSERVED+=("$result")
        else
            FAILED+=("$result")
        fi
    fi
done

if [ "${#KNOWN_OBSERVED[@]}" -gt 0 ]; then
    echo "==> known-failing (acknowledged, not failing CI): ${KNOWN_OBSERVED[*]}"
fi
if [ "${#FAILED[@]}" -gt 0 ]; then
    echo "==> unit test regressions: ${FAILED[*]}" >&2
    exit 1
fi
echo "==> all unit tests passed (or known-failing)"
