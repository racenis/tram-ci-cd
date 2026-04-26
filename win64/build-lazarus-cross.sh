#!/usr/bin/env bash
# Cross-build the Lazarus components needed by the tram-applets so that
# `lazbuild --os=$OS_TARGET --cpu=$CPU_TARGET --ws=win32` resolves all
# package state files. Builds in-place under /usr/lib64/lazarus.
#
# Required env: CPU_TARGET, OS_TARGET, BINUTILSPREFIX. Run AFTER build-fpc-pkgs.sh.
set -e

LAZ_ROOT=/usr/lib64/lazarus
COMMON_FLAGS=(
    "CPU_TARGET=$CPU_TARGET"
    "OS_TARGET=$OS_TARGET"
    "LCL_PLATFORM=win32"
    "BINUTILSPREFIX=$BINUTILSPREFIX"
)

# Build order matters: each step's output is consumed by the next.
#   packager/registration → provides LazarusPackageIntf etc.
#   components/lazutils   → core utilities used by everything LCL-adjacent
#   components/freetype   → EasyLazFreeType (LCL needs it)
#   lcl                   → the widgetset-platform LCL itself
for d in packager/registration \
         components/lazutils \
         components/freetype \
         lcl; do
    echo "==> building $d for $CPU_TARGET-$OS_TARGET"
    (cd "$LAZ_ROOT/$d" && make all "${COMMON_FLAGS[@]}" >/dev/null)
done
