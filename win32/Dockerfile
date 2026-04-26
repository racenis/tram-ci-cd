# Cross-compilation container: Linux host → Windows i686 (XP) target.
#
# Built from the tram-ci-cd/ root so cmake/ and win64/ are in the context:
#     docker build -f win32/Dockerfile -t tram-ci-cd-win32 .
FROM fedora:43

COPY win32/deps.sh /tmp/deps.sh
RUN bash /tmp/deps.sh && dnf clean all && rm /tmp/deps.sh

# Bake in the FPC win32 cross-RTL + packages and the cross-compiled Lazarus
# LCL/lazutils/freetype. The helper scripts are shared with the win64 image
# (target is parameterized by env vars) — that's why they're sourced from
# win64/. Doing this at image-build time means each CI run starts with
# `lazbuild --os=win32 --cpu=i386 --ws=win32` already wired up.
COPY win64/build-fpc-pkgs.sh /opt/build-fpc-pkgs.sh
COPY win64/build-lazarus-cross.sh /opt/build-lazarus-cross.sh
RUN chmod +x /opt/build-fpc-pkgs.sh /opt/build-lazarus-cross.sh && \
    CPU_TARGET=i386 OS_TARGET=win32 BINUTILSPREFIX=i686-w64-mingw32- \
        bash /opt/build-fpc-pkgs.sh && \
    CPU_TARGET=i386 OS_TARGET=win32 BINUTILSPREFIX=i686-w64-mingw32- \
        bash /opt/build-lazarus-cross.sh && \
    rm -rf /tmp/fpcsrc /usr/local/lib/fpc

COPY win32/build.sh /opt/build.sh
COPY cmake/toolchain-mingw-w64.cmake /opt/cmake/toolchain-mingw-w64.cmake
RUN chmod +x /opt/build.sh

ENV TRAM_ROOT=/projects
ENV OUT_DIR=/out
WORKDIR /projects
RUN mkdir -p /out

CMD ["bash", "/opt/build.sh"]
