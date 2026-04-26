# tram-ci-cd

* ⚠️ WARNING: THIS IS A DRAFT VERSION, DO NOT USE IN PRODUCTION ⚠️ *

Container-based release pipeline for the Tramway SDK. Builds the same set of
artifacts (SDK static lib + 3 devtools + template + tedit editor + 9 Lazarus
applets) for four targets, and packages a Windows installer at the end.

```
sibling repos expected at $PROJECTS_DIR (default: ../):
  tram-sdk/   tram-template/   tram-applets/   tram-world-editor/
```

## Quickstart — build everything

From this directory:

```sh
./build-all.sh
```

Runs the integration gate, all four platform builds, then the installer.
Artifacts land under `out/`. Set `SKIP_INTEGRATIONS=1` to skip the gating
test phase for a fast platform-only rebuild.

## Per-target builds

Each target is a Dockerfile + `build.sh` + `deps.sh` triple. Build the image
once, then run it with the source tree mounted read-only and an output dir
mounted writable:

```sh
docker build -t tram-ci-cd-<target> -f <target>/Dockerfile .
docker run --rm \
    -v "$(cd .. && pwd)":/projects:ro \
    -v "$(pwd)/out/<target>":/out \
    tram-ci-cd-<target>
```

Substitute `<target>` with one of:

| Target          | Output type                                     |
|-----------------|--------------------------------------------------|
| `linux-fedora`  | native ELF + `.so` (gcc, Fedora)                |
| `linux-debian`  | native ELF + `.so` (gcc, Debian)                |
| `win64`         | PE32+ x86-64 (mingw-w64 cross)                  |
| `win32`         | PE32 i686, XP-compatible (mingw-w64 cross)      |

The `linux-fedora` and `linux-debian` images both share `linux/build.sh` —
the Dockerfiles only differ in `deps.sh` (distro package names).

The Windows images bake an FPC cross-RTL + Lazarus cross LCL into the image
at build time (see `win64/build-fpc-pkgs.sh` and `win64/build-lazarus-cross.sh`),
so the Lazarus applet step in `build.sh` works out of the box. The win32
image reuses the same scripts via `COPY win64/build-*.sh` — they're
parameterised by `CPU_TARGET`/`OS_TARGET`/`BINUTILSPREFIX`.

## Where the binaries land

After `./build-all.sh`:

```
out/
├── linux-fedora/      libtramsdk.a, tbsp, tmap, trad, template,
│                       tedit, libwx_*.so*, <applets>
├── linux-debian/      same layout as linux-fedora
├── win64/             libtramsdk.a, tbsp.exe, tmap.exe, trad.exe,
│                       template.exe, tedit.exe, wx*.dll, <applets>.exe
├── win32/             same layout as win64 (PE32 i386)
└── installer/
    ├── win64/         Inno Setup-built single-file installer (.exe)
    └── win32/         same, 32-bit
```

Applet executables per target (9 total): `assetmanager`, `datalibtests`,
`kitchensink`, `languageeditor`, `materialeditor`, `particleeditor`,
`projectmanager`, `scratchpad`, `spriteeditor` (`.exe` suffix on Windows).

## Just one component

Each `build.sh` is a normal shell script — you can run it on the host once
the tools are in place. Inside a target image:

```sh
docker run --rm -it \
    -v "$(cd .. && pwd)":/projects:ro \
    -v "$(pwd)/out/<target>":/out \
    tram-ci-cd-<target> bash
# then edit /opt/build.sh or call its helper functions directly
```

## Integration gate

`./integrations/` runs the full unit/matrix/regression test suite as a
prerequisite for the release builds. `build-all.sh` invokes it first; pass
`SKIP_INTEGRATIONS=1` to bypass.

## Installer

`installer/` is a Wine + Inno Setup container. `build-all.sh` runs it twice
— once against `out/win64`, once against `out/win32` — so you get a
distributable installer per Windows arch.
