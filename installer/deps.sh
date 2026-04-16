#!/usr/bin/env bash
# Install Wine + Inno Setup for producing Windows installers from Linux.
set -euo pipefail

if [ -r /etc/os-release ]; then . /etc/os-release; fi

case "${ID:-}" in
    fedora)
        dnf install -y wine wget cabextract xorg-x11-server-Xvfb xorg-x11-xauth rsync ca-certificates
        ;;
    debian|ubuntu)
        export DEBIAN_FRONTEND=noninteractive
        dpkg --add-architecture i386 || true
        apt-get update
        apt-get install -y --no-install-recommends \
            wine wine32 wine64 wget cabextract xvfb rsync ca-certificates
        ;;
    *)
        echo "Unsupported distro: ${ID:-unknown}" >&2
        exit 1
        ;;
esac

# Install Inno Setup 6 under Wine (bundled here to keep the build reproducible).
INNO_URL="${INNO_URL:-https://github.com/jrsoftware/issrc/releases/download/is-6_7_1/innosetup-6.7.1.exe}"
INNO_CACHE="/opt/innosetup-installer.exe"
if [ ! -f "$INNO_CACHE" ]; then
    wget -q -O "$INNO_CACHE" "$INNO_URL"
fi

export WINEPREFIX="${WINEPREFIX:-/opt/wineprefix}"
export WINEDEBUG=-all
mkdir -p "$WINEPREFIX"
# /VERYSILENT handles the installer non-interactively.
xvfb-run -a wine "$INNO_CACHE" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP- || true

# Sanity check: iscc.exe should now exist somewhere under the wine prefix.
ISCC="$(find "$WINEPREFIX" -iname 'iscc.exe' 2>/dev/null | head -n1 || true)"
if [ -z "$ISCC" ]; then
    echo "ERROR: iscc.exe not found in $WINEPREFIX after Inno install" >&2
    exit 1
fi
echo "Inno Setup ISCC installed at: $ISCC"
