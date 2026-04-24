# Shared Linux build scripts

`deps.sh` and `build.sh` here are the distro-agnostic native-Linux build
scripts. They're consumed by:

- `../linux-fedora/Dockerfile` — Fedora 43 image (narrow glibc compat, matches
  the dev machine)
- `../linux-debian/Dockerfile` — Debian 12 bookworm image (broad glibc compat,
  the artifact that ships to users running any current desktop Linux)
- `../integrations/Dockerfile` — pulls these in on top of its test-runner deps

`deps.sh` dispatches on `/etc/os-release` `${ID}` to pick apt vs dnf package
names, so the same script handles both distros.

There is no `Dockerfile` in this directory anymore — build contexts use the
tram-ci-cd root so the per-distro Dockerfiles can `COPY linux/deps.sh …` from
this shared location.
