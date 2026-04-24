# Native Linux build container (Fedora 43) for the Tramway SDK.
# Produces artifacts that run on Fedora 37+ (glibc 2.36+).
# For broader-compat Linux binaries, see linux-debian/.
#
# Built from the tram-ci-cd/ root so linux/ is in the context:
#     docker build -f linux-fedora/Dockerfile -t tram-ci-cd-linux-fedora .
#
# Sibling repos are expected to be bind-mounted at /projects:
#     docker run --rm -v "$PWD/..":/projects -v "$PWD/out":/out tram-ci-cd-linux-fedora
FROM fedora:43

COPY linux/deps.sh /tmp/deps.sh
RUN bash /tmp/deps.sh && dnf clean all && rm /tmp/deps.sh

COPY linux/build.sh /opt/build.sh
RUN chmod +x /opt/build.sh

ENV TRAM_ROOT=/projects
ENV OUT_DIR=/out
WORKDIR /projects
RUN mkdir -p /out

CMD ["bash", "/opt/build.sh"]
