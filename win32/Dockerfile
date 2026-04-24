# Cross-compilation container: Linux host → Windows i686 (XP) target.
#
# Built from the tram-ci-cd/ root so cmake/ is in the context:
#     docker build -f win32/Dockerfile -t tram-ci-cd-win32 .
FROM fedora:43

COPY win32/deps.sh /tmp/deps.sh
RUN bash /tmp/deps.sh && dnf clean all && rm /tmp/deps.sh

COPY win32/build.sh /opt/build.sh
COPY cmake/toolchain-mingw-w64.cmake /opt/cmake/toolchain-mingw-w64.cmake
RUN chmod +x /opt/build.sh

ENV TRAM_ROOT=/projects
ENV OUT_DIR=/out
WORKDIR /projects
RUN mkdir -p /out

CMD ["bash", "/opt/build.sh"]
