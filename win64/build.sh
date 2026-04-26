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

# --- Template (tram-template/CMakeLists.txt — fetches bullet/glfw/openal/lua) ---
# The template's own CMake picks up our locally-rsynced SDK via TRAM_SDK_DIR
# so the cross-build is against matching SDK sources. All the native deps
# come from FetchContent and cross-compile cleanly with the MinGW toolchain.
if [ -d "$WORK_DIR/tram-template" ]; then
    echo "==> building template.exe (win64)"
    cd "$WORK_DIR/tram-template"
    cmake -B build-win64 -S . -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
        -DTRAM_SDK_DIR="$WORK_DIR/tram-sdk"
    cmake --build build-win64 -j"$JOBS"
    cp build-win64/template.exe "$OUT_DIR/"
fi

# --- Devtools (tbsp, tmap, trad) ---
# Each devtool is just main.cpp + engine_libs.cpp compiled against the SDK's
# src/ and libraries/ headers — no external link deps. The checked-in Makefiles
# call native `g++` with `.exe` output (they were authored on Windows), so we
# skip them and invoke the mingw compiler directly with the same flags.
# -static -static-libstdc++ so the .exe runs without needing mingw DLLs alongside.
build_devtool_win64() {
    local tool="$1"
    local dir="$WORK_DIR/tram-sdk/devtools/$tool"
    [ -d "$dir" ] || { echo "    skip: $dir missing"; return 0; }
    cd "$dir"
    "${HOST}-g++" -std=c++20 -O2 -c engine_libs.cpp -o engine_libs.o \
        -I../../src/ -I../../libraries/
    "${HOST}-g++" -std=c++20 -O2 main.cpp engine_libs.o -o "${tool}.exe" \
        -static -static-libstdc++ \
        -I../../src/ -I../../libraries/
    cp "${tool}.exe" "$OUT_DIR/"
}
for tool in tbsp tmap trad; do
    echo "==> building devtool $tool (win64)"
    if ! build_devtool_win64 "$tool"; then
        echo "WARN: devtool $tool failed to cross-build — continuing" >&2
    fi
done

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
# Wired up via lazbuild's `--os=win64 --cpu=x86_64 --ws=win32` mode. The FPC
# win64 cross-RTL/packages and Lazarus cross-built LCL/lazutils/freetype were
# baked into the image at build time (see Dockerfile + build-fpc-pkgs.sh +
# build-lazarus-cross.sh), so the lazbuild invocation here just consumes them.
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
