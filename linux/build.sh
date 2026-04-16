#!/usr/bin/env bash
# Native Linux build of the whole Tramway SDK stack.
# Expects sibling repos checked out under $TRAM_ROOT:
#     $TRAM_ROOT/tram-sdk
#     $TRAM_ROOT/tram-template
#     $TRAM_ROOT/tram-applets
# Emits artifacts into $OUT_DIR.
set -euo pipefail

TRAM_ROOT="${TRAM_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
OUT_DIR="${OUT_DIR:-$(pwd)/out}"
WORK_DIR="${WORK_DIR:-/tmp/tram-build}"
JOBS="${JOBS:-$(nproc)}"
mkdir -p "$OUT_DIR" "$WORK_DIR"

echo "==> TRAM_ROOT=$TRAM_ROOT"
echo "==> OUT_DIR=$OUT_DIR"
echo "==> WORK_DIR=$WORK_DIR"

# Copy sources into a writable workdir so builds don't touch the source tree.
# Makefiles drop .o / .a / binaries alongside sources, so an RO source mount breaks them.
for repo in tram-sdk tram-template tram-applets; do
    if [ -d "$TRAM_ROOT/$repo" ]; then
        # Exclude lib/ wholesale — Lazarus/FPC drops .ppu/.o/.compiled there, and
        # stale contents from prior host-side builds make lazbuild think units are
        # up-to-date, leading to missing .o files at link time.
        rsync -a --delete \
              --exclude='.git' --exclude='build*' \
              --exclude='*.o' --exclude='*.a' --exclude='*.ppu' --exclude='*.compiled' \
              --exclude='lib' \
              "$TRAM_ROOT/$repo/" "$WORK_DIR/$repo/"
    fi
done

# Each component runs in its own subshell and any failure is recorded in FAILED[]
# rather than aborting the whole build. The user flagged that the whole SDK has
# only been built on Windows so far, so devtools/template may be rough on Linux.
FAILED=()
run_step() {
    local name="$1"; shift
    echo "===================================="
    echo "  $name"
    echo "===================================="
    if ( set -e; "$@" ); then
        echo "    [$name] OK"
    else
        echo "    [$name] FAILED" >&2
        FAILED+=("$name")
    fi
}

# --- SDK static library ---
build_sdk() {
    cd "$WORK_DIR/tram-sdk"
    make -j"$JOBS" library
    cp libtramsdk.a "$OUT_DIR/"
}
run_step "libtramsdk.a" build_sdk

# --- Devtools (tbsp, tmap, trad) ---
# KNOWN-BROKEN on Linux: link fails on Platform::SwitchForeground (terminal colors
# are only implemented in the Windows branch of src/platform/terminal.cpp).
# Listed here so the failure shows up as a tracked component, not a silent skip.
build_devtool() {
    local tool="$1"
    cd "$WORK_DIR/tram-sdk/devtools/$tool"
    # Devtool Makefiles have missing deps (tbsp rule doesn't declare engine_libs.o
    # as a prereq), so parallel builds race. Serial is fine — these are small.
    make
    [ -f "$tool.exe" ] && mv "$tool.exe" "$tool" || true
    cp "$tool" "$OUT_DIR/"
}
for tool in tbsp tmap trad; do
    run_step "devtool:$tool" build_devtool "$tool"
done

# --- Template ---
build_template() {
    cd "$WORK_DIR/tram-template"
    make -j"$JOBS"
    cp template "$OUT_DIR/"
}
run_step "template" build_template

# --- Lazarus applets ---
build_applet() {
    local applet_dir="$1"
    local name
    name="$(basename "$applet_dir")"
    # Skip backup/ subdirs — several applets have them for archived copies of the project.
    local lpi
    lpi="$(find "$applet_dir" -maxdepth 2 -name '*.lpi' ! -path '*/backup/*' | head -n1)"
    [ -z "$lpi" ] && return 0
    # Explicit exit-code check — lazbuild's exit status doesn't always propagate
    # cleanly through set -e, and --quiet swallows the visible "FAILED" message.
    if ! lazbuild --quiet "$lpi"; then
        echo "    lazbuild failed for $lpi — re-running verbose tail for diagnosis:" >&2
        lazbuild "$lpi" 2>&1 | tail -15 >&2 || true
        return 1
    fi
    # Some applets are libraries (datalib, sdkwrapper) that don't produce a binary.
    # Others name the executable after the .lpr (e.g. asset-manager/ → assetmanager).
    # Search wider than the lpi dir to catch lib/<arch>/ outputs and just collect
    # whatever shows up as a fresh executable.
    local found
    found=$(find "$applet_dir" -maxdepth 5 -type f -executable \
            ! -path '*/backup/*' \
            ! -name '*.sh' ! -name '*.py' ! -name '*.so*' \
            -newer "$lpi" 2>/dev/null)
    if [ -z "$found" ]; then
        echo "    (no binary produced — likely a Pascal library)"
        return 0
    fi
    while IFS= read -r bin; do
        echo "    collected: $bin"
        cp "$bin" "$OUT_DIR/"
    done <<< "$found"
}
if [ -d "$WORK_DIR/tram-applets" ]; then
    # Register .lpk packages before building projects that depend on them —
    # applets like asset-manager / kitchensink require tramdatalib, sdkwrapper, etc.
    # Without this, lazbuild reports "Broken dependency: <package>" and silently
    # succeeds the configure step but produces no binary.
    echo "===================================="
    echo "  registering Lazarus packages"
    echo "===================================="
    while IFS= read -r lpk; do
        echo "    + $lpk"
        lazbuild --add-package-link "$lpk" >/dev/null || \
            echo "    WARN: failed to register $lpk" >&2
    done < <(find "$WORK_DIR/tram-applets" -name '*.lpk' ! -path '*/backup/*')

    for applet_dir in "$WORK_DIR/tram-applets"/*/; do
        name="$(basename "$applet_dir")"
        run_step "applet:$name" build_applet "$applet_dir"
    done
fi

echo "===================================="
echo "  build summary"
echo "===================================="
ls -la "$OUT_DIR"
if [ "${#FAILED[@]}" -gt 0 ]; then
    echo ""
    echo "FAILED components (${#FAILED[@]}):" >&2
    printf '  - %s\n' "${FAILED[@]}" >&2
    exit 1
fi
echo "all components built successfully"
