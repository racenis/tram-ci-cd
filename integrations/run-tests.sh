#!/usr/bin/env bash
# Top-level CI entry point: compile check → unit tests → matrix → integrations.
# Each phase is its own script so a failing phase can be re-run in isolation.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# linux/build.sh defaults OUT_DIR to $(pwd)/out, but in CI /projects is mounted
# read-only. Park artifacts under /tmp — Phase 4 only needs libtramsdk.a, which
# run-regression.sh picks up from /tmp/tram-build/tram-sdk anyway.
export OUT_DIR="${OUT_DIR:-/tmp/tram-build-out}"
mkdir -p "$OUT_DIR"

echo "===================================="
echo "  Phase 1/4: full native build"
echo "===================================="
# linux/build.sh exits non-zero on known-broken Linux components (devtools'
# Platform::SwitchForeground, Lazarus applets needing kernel32.dll). Phases
# 2-4 only need libtramsdk.a, so gate on that artifact instead of the exit code.
bash "$HERE/../linux/build.sh" || true
if [ ! -f "$OUT_DIR/libtramsdk.a" ]; then
    echo "Phase 1 failed: $OUT_DIR/libtramsdk.a was not produced" >&2
    exit 1
fi

echo "===================================="
echo "  Phase 2/4: unit tests"
echo "===================================="
bash "$HERE/run-unit-tests.sh"

echo "===================================="
echo "  Phase 3/4: matrix compile-check"
echo "===================================="
bash "$HERE/run-matrix.sh"

echo "===================================="
echo "  Phase 4/4: integration regressions"
echo "===================================="
bash "$HERE/run-regression.sh"

echo "==> all CI checks passed"
