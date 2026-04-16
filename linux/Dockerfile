# Native Linux build container for Tramway SDK.
# Sibling repos are expected to be bind-mounted at /projects:
#     docker run --rm -v "$PWD/..":/projects -v "$PWD/out":/out tram-ci-cd-linux
FROM fedora:43

COPY deps.sh /tmp/deps.sh
RUN bash /tmp/deps.sh && dnf clean all && rm /tmp/deps.sh

COPY build.sh /opt/build.sh
RUN chmod +x /opt/build.sh

ENV TRAM_ROOT=/projects
ENV OUT_DIR=/out
WORKDIR /projects
RUN mkdir -p /out

CMD ["bash", "/opt/build.sh"]
