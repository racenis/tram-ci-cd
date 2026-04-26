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
for repo in tram-sdk tram-template tram-applets tram-world-editor; do
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

# --- Template (tram-template/CMakeLists.txt — fetches bullet/glfw/openal/lua) ---
# Reuses the same approach as win64; we deliberately NOT pass the XP_CFLAGS
# here because template's fetched deps (bullet, openal-soft) don't target XP
# cleanly and the goal of a 32-bit template is broader user reach, not XP.
if [ -d "$WORK_DIR/tram-template" ]; then
    echo "==> building template.exe (win32)"
    cd "$WORK_DIR/tram-template"
    cmake -B build-win32 -S . -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
        -DTRAM_SDK_DIR="$WORK_DIR/tram-sdk"
    cmake --build build-win32 -j"$JOBS"
    cp build-win32/template.exe "$OUT_DIR/"
fi

# --- Devtools (tbsp, tmap, trad) ---
# Header-only deps; mingw-g++ -static gets us a self-contained .exe.
# Same approach as win64/build.sh.
build_devtool_win32() {
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
    echo "==> building devtool $tool (win32)"
    if ! build_devtool_win32 "$tool"; then
        echo "WARN: devtool $tool failed to cross-build — continuing" >&2
    fi
done

# --- tram-world-editor (tedit.exe, 32-bit) ---
# Reuses the editor's MinGW toolchain file with MINGW_TRIPLE overridden to the
# 32-bit triple. We skip the XP-compat flags the SDK build above uses —
# wxWidgets 3.2 dropped XP support, and the editor has always been a modern
# Win32 app. wxWidgets is built from source; the POST_BUILD step in the
# editor's CMakeLists stages every wx*.dll next to tedit.exe.
if [ -d "$WORK_DIR/tram-world-editor" ]; then
    echo "==> building tedit.exe + wx DLLs (win32)"
    cd "$WORK_DIR/tram-world-editor"
    cmake -B build-win32 -S . -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_TOOLCHAIN_FILE="${EDITOR_TOOLCHAIN:-/opt/cmake/toolchain-mingw-w64.cmake}" \
        -DMINGW_TRIPLE=i686-w64-mingw32 \
        -DTRAM_SDK_DIR="$WORK_DIR/tram-sdk"
    cmake --build build-win32 -j"$JOBS"
    cp build-win32/tedit.exe "$OUT_DIR/"
    cp build-win32/*.dll "$OUT_DIR/" 2>/dev/null || true
fi

# --- Lazarus applets: win32 ---
# FPC i386-win32 cross-RTL/packages and Lazarus cross-built LCL are baked into
# the image at build time (see Dockerfile + win64/build-fpc-pkgs.sh +
# win64/build-lazarus-cross.sh, parameterized by env). Per-applet XP subsystem
# version (-WP5.01) is not plumbed through lazbuild here yet — applets ship as
# regular Win32 binaries; the SDK binaries above carry the XP linker flags.
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
