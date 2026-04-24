#!/usr/bin/env bash
# Cross-compile the Tramway SDK for Windows x86_64 using mingw-w64.
# This is the known-good build target (framework already builds on Windows/mingw).
# Requires cross-packages from deps.sh.
set -euo pipefail

TRAM_ROOT="${TRAM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
OUT_DIR="${OUT_DIR:-$(pwd)/out}"
WORK_DIR="${WORK_DIR:-/tmp/tram-build-win64}"
JOBS="${JOBS:-$(nproc)}"
HOST="${HOST:-x86_64-w64-mingw32}"
mkdir -p "$OUT_DIR" "$WORK_DIR"

echo "==> TRAM_ROOT=$TRAM_ROOT"
echo "==> OUT_DIR=$OUT_DIR"
echo "==> WORK_DIR=$WORK_DIR"
echo "==> HOST=$HOST"

# Copy sources into writable workdir — the source mount is read-only.
for repo in tram-sdk tram-template tram-applets tram-world-editor; do
    if [ -d "$TRAM_ROOT/$repo" ]; then
        rsync -a --delete \
              --exclude='.git' --exclude='build*' \
              --exclude='*.o' --exclude='*.a' --exclude='*.ppu' --exclude='*.compiled' \
              --exclude='lib' \
              "$TRAM_ROOT/$repo/" "$WORK_DIR/$repo/"
    fi
done

# CMake toolchain file for mingw-w64 cross-compile.
TOOLCHAIN="$(mktemp --suffix=.cmake)"
trap 'rm -f "$TOOLCHAIN"' EXIT
cat > "$TOOLCHAIN" <<EOF
set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_C_COMPILER ${HOST}-gcc)
set(CMAKE_CXX_COMPILER ${HOST}-g++)
set(CMAKE_RC_COMPILER ${HOST}-windres)
set(CMAKE_FIND_ROOT_PATH /usr/${HOST} /usr/${HOST}/sys-root/mingw)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
EOF

# --- SDK static library (via CMake, which uses vendored libraries/) ---
echo "==> building libtramsdk.a (win64)"
cd "$WORK_DIR/tram-sdk"
cmake -B build-win64 -S . -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN"
cmake --build build-win64 -j"$JOBS"
cp build-win64/libtramsdk.a "$OUT_DIR/"

# --- Devtools and template ---
# TODO: devtool and template Makefiles are Linux-first (/usr/include/bullet etc).
# For now we invoke g++ directly against vendored libraries/ headers.
# This is a placeholder — expect breakage until the build rules are abstracted.
echo "==> devtools/template win64 build NOT YET IMPLEMENTED — see TODO"
echo "    (vendored libraries need windows binaries in libraries/binaries/win64/)"

# --- tram-world-editor (tedit.exe) ---
# Uses the editor's own toolchain file (same one devs use locally). We pass
# TRAM_SDK_DIR so FetchContent isn't triggered for the SDK — those sources
# are already rsynced into $WORK_DIR. wxWidgets IS fetched fresh and built
# from source; the editor's CMakeLists does a POST_BUILD copy of every wx*.dll
# next to tedit.exe, so we just glob the whole build dir for *.dll.
if [ -d "$WORK_DIR/tram-world-editor" ]; then
    echo "==> building tedit.exe + wx DLLs (win64)"
    cd "$WORK_DIR/tram-world-editor"
    cmake -B build-win64 -S . -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_TOOLCHAIN_FILE="${EDITOR_TOOLCHAIN:-/opt/cmake/toolchain-mingw-w64.cmake}" \
        -DTRAM_SDK_DIR="$WORK_DIR/tram-sdk"
    cmake --build build-win64 -j"$JOBS"
    cp build-win64/tedit.exe "$OUT_DIR/"
    # Every wx*.dll the POST_BUILD step staged next to the binary.
    cp build-win64/*.dll "$OUT_DIR/" 2>/dev/null || true
fi

# --- Lazarus applets cross-compile to win64 ---
# lazbuild --os=win64 --cpu=x86_64 --ws=win32
# Requires LCL cross-built for win32 widgetset. fpcupdeluxe is the normal way.
# TODO: bake LCL cross-build into deps.sh once the Fedora lazarus package is mapped out.
if command -v lazbuild >/dev/null && [ -d "$WORK_DIR/tram-applets" ]; then
    # Register .lpk packages so .lpi projects that depend on them resolve.
    # Same as the Linux build — without this, applets fail with "Broken dependency".
    echo "==> registering Lazarus packages"
    while IFS= read -r lpk; do
        lazbuild --add-package-link "$lpk" >/dev/null 2>&1 || \
            echo "    WARN: failed to register $lpk" >&2
    done < <(find "$WORK_DIR/tram-applets" -name '*.lpk' ! -path '*/backup/*')

    for applet_dir in "$WORK_DIR/tram-applets"/*/; do
        name="$(basename "$applet_dir")"
        lpi="$(find "$applet_dir" -maxdepth 2 -name '*.lpi' ! -path '*/backup/*' | head -n1)"
        [ -z "$lpi" ] && continue
        echo "==> applet $name → win64"
        if ! lazbuild --quiet --os=win64 --cpu=x86_64 --ws=win32 "$lpi"; then
            echo "WARN: $name failed to cross-build for win64 — continuing" >&2
            continue
        fi
        find "$applet_dir" -maxdepth 3 -name '*.exe' -newer "$lpi" \
             -exec cp {} "$OUT_DIR/" \; 2>/dev/null || true
    done
fi

echo "==> done. artifacts in $OUT_DIR:"
ls -la "$OUT_DIR"
