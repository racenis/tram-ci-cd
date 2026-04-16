#!/usr/bin/env bash
# Assemble setupfiles/ from pre-built artifacts, then run Inno Setup via Wine.
#
# Inputs (env vars):
#   WIN_BUILD_DIR   directory containing win64 build artifacts (required).
#                   Should already have the layout Inno expects to COPY from.
#   SDK_SRC_DIR     source checkout of tram-sdk (for data/, shaders/, src/, scripts/, asset.db, project.cfg).
#                   Default: $TRAM_ROOT/tram-sdk
#   TEMPLATE_SRC_DIR  source checkout of tram-template (default: $TRAM_ROOT/tram-template).
#   OUT_DIR         where the installer .exe lands (default: ./out).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TRAM_ROOT="${TRAM_ROOT:-$(cd "$HERE/../.." && pwd)}"
WIN_BUILD_DIR="${WIN_BUILD_DIR:?set WIN_BUILD_DIR to the win64 build output}"
SDK_SRC_DIR="${SDK_SRC_DIR:-$TRAM_ROOT/tram-sdk}"
TEMPLATE_SRC_DIR="${TEMPLATE_SRC_DIR:-$TRAM_ROOT/tram-template}"
OUT_DIR="${OUT_DIR:-$(pwd)/out}"
mkdir -p "$OUT_DIR"

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/setupfiles/tram-binary" \
         "$STAGE/setupfiles/tram-sdk" \
         "$STAGE/setupfiles/tram-template"

# 1. tram-binary/ — every .exe and .dll from the win64 build.
cp -r "$WIN_BUILD_DIR"/*.exe "$WIN_BUILD_DIR"/*.dll "$STAGE/setupfiles/tram-binary/" 2>/dev/null || true
cp "$HERE/license.txt" "$STAGE/setupfiles/tram-binary/licenses.txt"
# resources/ (icons, etc.) if present next to the Inno script
[ -d "$HERE/resources" ] && cp -r "$HERE/resources" "$STAGE/setupfiles/tram-binary/"

# 2. tram-sdk/ — SDK source layout minus build junk.
rsync -a --exclude='*.o' --exclude='build*' --exclude='.git' \
      --exclude='tests' --exclude='docs' \
      "$SDK_SRC_DIR/" "$STAGE/setupfiles/tram-sdk/"
cp "$WIN_BUILD_DIR/libtramsdk.a" "$STAGE/setupfiles/tram-sdk/" 2>/dev/null || true

# 3. tram-template/ — template source + pre-built .exe.
rsync -a --exclude='*.o' --exclude='.git' --exclude='build*' \
      "$TEMPLATE_SRC_DIR/" "$STAGE/setupfiles/tram-template/"
cp "$WIN_BUILD_DIR/template.exe" "$STAGE/setupfiles/tram-template/" 2>/dev/null || true

# 4. Copy the .iss and its assets into the stage root.
cp "$HERE/tram-full.iss" "$STAGE/"
cp "$HERE/license.txt"   "$STAGE/"
[ -f "$HERE/wizardimage.bmp" ] && cp "$HERE/wizardimage.bmp" "$STAGE/"

# 5. Run ISCC under Wine.
export WINEPREFIX="${WINEPREFIX:-/opt/wineprefix}"
export WINEDEBUG=-all
ISCC="$(find "$WINEPREFIX" -iname 'iscc.exe' | head -n1)"
[ -z "$ISCC" ] && { echo "iscc.exe not found — run deps.sh first" >&2; exit 1; }

cd "$STAGE"
xvfb-run -a wine "$ISCC" "tram-full.iss" /O"$OUT_DIR"

echo "==> installer(s) in $OUT_DIR:"
ls -la "$OUT_DIR"
