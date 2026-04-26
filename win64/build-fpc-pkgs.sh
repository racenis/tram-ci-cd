#!/usr/bin/env bash
# Cross-build FPC 3.2.2 RTL + packages for $CPU_TARGET-$OS_TARGET.
# Expected env: CPU_TARGET, OS_TARGET, BINUTILSPREFIX.
set -e

FPCSRC=/tmp/fpcsrc
INSTALL_BASEDIR=/usr/lib64/fpc/3.2.2

rm -rf "$FPCSRC"
cp -r /usr/share/fpcsrc "$FPCSRC"

# --- RTL ---
cd "$FPCSRC/rtl"
make all \
    CPU_TARGET="$CPU_TARGET" OS_TARGET="$OS_TARGET" \
    BINUTILSPREFIX="$BINUTILSPREFIX" CROSSINSTALL=1 >/dev/null
make install \
    CPU_TARGET="$CPU_TARGET" OS_TARGET="$OS_TARGET" \
    CROSSINSTALL=1 INSTALL_BASEDIR="$INSTALL_BASEDIR" >/dev/null

# --- Stub out platform-specific packages that Fedora's fpc-src strips out ---
# fpmake_proc.inc wraps most packages in `procedure add_<name>(ADirectory); begin
# with Installer do {$include <name>/fpmake.pp} end;`, so a stub that mirrors
# another `AddPackage` body works. Easiest way to get a valid shape is to clone
# a known-good, small package (fastcgi) and rewrite the name + OSes filter.
stub_pkg() {
    local name="$1" osset="$2"
    local out="$FPCSRC/packages/$name"
    rm -rf "$out"
    cp -r "$FPCSRC/packages/fastcgi" "$out"
    rm -rf "$out/src" "$out/examples" "$out/tests"
    local pp="$out/fpmake.pp"
    sed -i "s/AddPackage('fastcgi')/AddPackage('$name')/" "$pp"
    sed -i "s/ShortName := 'fcgi'/ShortName := '$name'/" "$pp"
    sed -i "s|AllUnixOSes+AllWindowsOSes+AllAmigaLikeOSes-\\[qnx\\]|[$osset]|" "$pp"
    sed -i "/SourcePath\\.Add\\|Targets\\.AddUnit/d" "$pp"
}
for x in amunits:Amiga arosunits:Aros morphunits:MorphOS os2units:OS2 \
         os4units:Amiga palmunits:PalmOS tosunits:Atari winceunits:WinCE; do
    stub_pkg "${x%:*}" "${x#*:}"
done

# `ide` is a special case: fpmake_proc.inc has bare `{$include ide/fpmake.pp}`
# at module scope (no `procedure add_ide ... begin` wrapper), because the
# original ide/fpmake.pp defines both `add_ide` and `add_ide_comandlineoptions`
# itself. Replace with a minimal no-op version that still provides both
# procedures — the real IDE needs compiler internals that aren't available
# in a cross-build anyway.
if [ -d "$FPCSRC/packages/ide" ]; then
    mv "$FPCSRC/packages/ide" "$FPCSRC/packages/ide.orig"
    mkdir -p "$FPCSRC/packages/ide"
    cat > "$FPCSRC/packages/ide/fpmake.pp" <<'STUBEOF'
{$ifndef ALLPACKAGES}
{$mode objfpc}{$H+}
program fpmake;
uses fpmkunit;
begin end.
{$endif ALLPACKAGES}

procedure add_ide_comandlineoptions();
begin
end;

procedure add_ide(const ADirectory: string);
begin
end;
STUBEOF
fi

# --- Packages ---
cd "$FPCSRC/packages"
make all \
    CPU_TARGET="$CPU_TARGET" OS_TARGET="$OS_TARGET" \
    BINUTILSPREFIX="$BINUTILSPREFIX" CROSSINSTALL=1
make install \
    CPU_TARGET="$CPU_TARGET" OS_TARGET="$OS_TARGET" \
    CROSSINSTALL=1 INSTALL_BASEDIR="$INSTALL_BASEDIR"

# fpmake's install step ignores INSTALL_BASEDIR and writes to the fpmake
# hardcoded prefix /usr/local/lib/fpc/... Move the units back under
# /usr/lib64 so fpc.cfg's default -Fu paths find them.
FPMAKE_INSTALLED="/usr/local/lib/fpc/3.2.2/units/$CPU_TARGET-$OS_TARGET"
if [ -d "$FPMAKE_INSTALLED" ]; then
    mkdir -p "$INSTALL_BASEDIR/units/$CPU_TARGET-$OS_TARGET"
    cp -rln "$FPMAKE_INSTALLED/." "$INSTALL_BASEDIR/units/$CPU_TARGET-$OS_TARGET/"
fi

echo "=== installed units ==="
ls "$INSTALL_BASEDIR/units/$CPU_TARGET-$OS_TARGET/"
