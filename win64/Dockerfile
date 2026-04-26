# Cross-compilation container: Linux host → Windows x86_64 target.
#
# Built from the tram-ci-cd/ root so cmake/ is in the context:
#     docker build -f win64/Dockerfile -t tram-ci-cd-win64 .
FROM fedora:43

COPY win64/deps.sh /tmp/deps.sh
RUN bash /tmp/deps.sh && dnf clean all && rm /tmp/deps.sh

# Bake in the FPC win64 cross-RTL + packages and the cross-compiled Lazarus
# LCL/lazutils/freetype. Doing this at image-build time means each CI run
# starts with `lazbuild --os=win64 --cpu=x86_64 --ws=win32` already wired up,
# instead of paying the ~2 minute setup cost on every build.
COPY win64/build-fpc-pkgs.sh /opt/build-fpc-pkgs.sh
COPY win64/build-lazarus-cross.sh /opt/build-lazarus-cross.sh
RUN chmod +x /opt/build-fpc-pkgs.sh /opt/build-lazarus-cross.sh && \
    CPU_TARGET=x86_64 OS_TARGET=win64 BINUTILSPREFIX=x86_64-w64-mingw32- \
        bash /opt/build-fpc-pkgs.sh && \
    CPU_TARGET=x86_64 OS_TARGET=win64 BINUTILSPREFIX=x86_64-w64-mingw32- \
        bash /opt/build-lazarus-cross.sh && \
    rm -rf /tmp/fpcsrc /usr/local/lib/fpc

COPY win64/build.sh /opt/build.sh
COPY cmake/toolchain-mingw-w64.cmake /opt/cmake/toolchain-mingw-w64.cmake
RUN chmod +x /opt/build.sh

ENV TRAM_ROOT=/projects
ENV OUT_DIR=/out
WORKDIR /projects
RUN mkdir -p /out

CMD ["bash", "/opt/build.sh"]
