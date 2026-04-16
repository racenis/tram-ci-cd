# Container for building the Windows installer via Wine + Inno Setup.
# Expects a pre-built Windows artifacts directory to be bind-mounted in:
#   docker run --rm \
#       -v "$PWD/../out-win64":/win-build \
#       -v "$PWD/..":/projects \
#       -v "$PWD/out":/out \
#       -e WIN_BUILD_DIR=/win-build \
#       tram-ci-cd-installer
FROM fedora:43

COPY deps.sh /tmp/deps.sh
RUN bash /tmp/deps.sh && dnf clean all && rm /tmp/deps.sh

COPY build.sh tram-full.iss license.txt /opt/installer/
# wizardimage.bmp is optional — copied if present at build context
COPY wizardimage.bmp* /opt/installer/
RUN chmod +x /opt/installer/build.sh

ENV TRAM_ROOT=/projects
ENV OUT_DIR=/out
ENV WINEPREFIX=/opt/wineprefix
WORKDIR /opt/installer
RUN mkdir -p /out

CMD ["bash", "/opt/installer/build.sh"]
