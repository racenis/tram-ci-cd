# Native Linux build container (Debian 12 "bookworm") for the Tramway SDK.
# Produces artifacts that run on Debian 12+, Ubuntu 22.04+, and any Fedora
# ≥ 37 — anything with glibc 2.36 or newer, which covers essentially every
# currently-supported desktop Linux distro.
#
# Built from the tram-ci-cd/ root so linux/ is in the context:
#     docker build -f linux-debian/Dockerfile -t tram-ci-cd-linux-debian .
#
# Sibling repos are expected to be bind-mounted at /projects:
#     docker run --rm -v "$PWD/..":/projects -v "$PWD/out":/out tram-ci-cd-linux-debian
FROM debian:bookworm-slim

# bookworm-slim doesn't ship `ca-certificates` or `gnupg` by default; both are
# indirectly needed by apt-get install flows for the dev packages below.
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates bash \
    && rm -rf /var/lib/apt/lists/*

COPY linux/deps.sh /tmp/deps.sh
RUN bash /tmp/deps.sh \
    && apt-get clean && rm -rf /var/lib/apt/lists/* \
    && rm /tmp/deps.sh

COPY linux/build.sh /opt/build.sh
RUN chmod +x /opt/build.sh

ENV TRAM_ROOT=/projects
ENV OUT_DIR=/out
WORKDIR /projects
RUN mkdir -p /out

CMD ["bash", "/opt/build.sh"]
