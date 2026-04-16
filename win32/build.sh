#!/usr/bin/env bash
# Cross-compile the Tramway SDK for Windows i686 (32-bit), targeting Windows XP.
# XP-compatibility is achieved via _WIN32_WINNT=0x0501 and subsystem 5.01.
# Expect this to need iteration — toolchain pinning for XP on modern mingw is fiddly.
set -euo pipefail

TRAM_ROOT="${TRAM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
OUT_DIR="${OUT_DIR:-$(pwd)/out}"
WORK_DIR="${WORK_DIR:-/tmp/tram-build-win32}"
JOBS="${JOBS:-$(nproc)}"
HOST="${HOST:-i686-w64-mingw32}"
mkdir -p "$OUT_DIR" "$WORK_DIR"

XP_CFLAGS="-D_WIN32_WINNT=0x0501 -DWINVER=0x0501"
XP_LDFLAGS="-Wl,--subsystem,console:5.01 -Wl,--major-subsystem-version,5 -Wl,--minor-subsystem-version,1"

echo "==> TRAM_ROOT=$TRAM_ROOT"
echo "==> OUT_DIR=$OUT_DIR"
echo "==> WORK_DIR=$WORK_DIR"
echo "==> HOST=$HOST (XP-compat)"

# Copy sources into writable workdir — the source mount is read-only.
for repo in tram-sdk tram-template tram-applets; do
    if [ -d "$TRAM_ROOT/$repo" ]; then
        rsync -a --delete \
              --exclude='.git' --exclude='build*' \
              --exclude='*.o' --exclude='*.a' --exclude='*.ppu' --exclude='*.compiled' \
              --exclude='lib' \
              "$TRAM_ROOT/$repo/" "$WORK_DIR/$repo/"
    fi
done

TOOLCHAIN="$(mktemp --suffix=.cmake)"
trap 'rm -f "$TOOLCHAIN"' EXIT
cat > "$TOOLCHAIN" <<EOF
set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_SYSTEM_PROCESSOR x86)
set(CMAKE_C_COMPILER ${HOST}-gcc)
set(CMAKE_CXX_COMPILER ${HOST}-g++)
set(CMAKE_RC_COMPILER ${HOST}-windres)
set(CMAKE_FIND_ROOT_PATH /usr/${HOST} /usr/${HOST}/sys-root/mingw)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_C_FLAGS_INIT "${XP_CFLAGS}")
set(CMAKE_CXX_FLAGS_INIT "${XP_CFLAGS}")
set(CMAKE_EXE_LINKER_FLAGS_INIT "${XP_LDFLAGS}")
EOF

echo "==> building libtramsdk.a (win32 XP)"
cd "$WORK_DIR/tram-sdk"
cmake -B build-win32 -S . -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN"
cmake --build build-win32 -j"$JOBS"
cp build-win32/libtramsdk.a "$OUT_DIR/"

# TODO: devtools/template Makefiles are Linux-first. Cross-compile needs the
# build rules abstracted (see win64/build.sh — same story).
echo "==> devtools/template win32 build NOT YET IMPLEMENTED — see win64/build.sh TODO"

# --- Lazarus applets: win32, XP-compatible ---
# FPC supports XP via -WP5.01 (min subsystem version) and older RTL still works.
# Blocked on FPC win32 cross-RTL — Fedora's fpc package is host-only.
# TODO: bake win32 cross-RTL (via fpcupdeluxe or prebuilt tarball) into deps.sh.
if command -v lazbuild >/dev/null && [ -d "$WORK_DIR/tram-applets" ]; then
    # Register .lpk packages so .lpi projects that depend on them resolve.
    echo "==> registering Lazarus packages"
    while IFS= read -r lpk; do
        lazbuild --add-package-link "$lpk" >/dev/null 2>&1 || \
            echo "    WARN: failed to register $lpk" >&2
    done < <(find "$WORK_DIR/tram-applets" -name '*.lpk' ! -path '*/backup/*')

    for applet_dir in "$WORK_DIR/tram-applets"/*/; do
        name="$(basename "$applet_dir")"
        lpi="$(find "$applet_dir" -maxdepth 2 -name '*.lpi' ! -path '*/backup/*' | head -n1)"
        [ -z "$lpi" ] && continue
        echo "==> applet $name → win32 (XP)"
        # XP subsystem version (-WP5.01) would go here, but lazbuild rejects
        # --compiler-options. Applets are blocked on FPC win32 cross-RTL either way;
        # revisit the XP flag once the cross-RTL is in place.
        if ! lazbuild --quiet --os=win32 --cpu=i386 --ws=win32 "$lpi"; then
            echo "WARN: $name failed to cross-build for win32 — continuing" >&2
            continue
        fi
        find "$applet_dir" -maxdepth 5 -name '*.exe' -newer "$lpi" \
             -exec cp {} "$OUT_DIR/" \; 2>/dev/null || true
    done
fi

echo "==> done. artifacts in $OUT_DIR:"
ls -la "$OUT_DIR"
