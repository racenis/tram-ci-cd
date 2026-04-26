# Standalone dev/CI image for tram-world-editor — produces a Linux native
# binary AND a Windows (MinGW) cross-compiled .exe from the same source tree
# in one pass. This is redundant with the linux/ + win64/ target containers
# used by build-all.sh; it exists for devs who want a one-shot editor build
# without touching the rest of the SDK stack.
#
# Built from the tram-ci-cd/ root so cmake/ is in the context:
#     docker build -f editor-dev/Dockerfile -t tram-editor-dev .
#
# Run a build (tram-world-editor mounted at /src, tram-sdk at /sdk):
#     docker run --rm -v "$PWD/tram-world-editor:/src" \
#                     -v "$PWD/tram-sdk:/sdk" \
#                     tram-editor-dev
# Outputs: /src/build-linux/tedit and /src/build-windows/tedit.exe.

FROM fedora:43

RUN dnf install -y --setopt=install_weak_deps=False \
        # --- native Linux build (wx built from source via CMake FetchContent) ---
        gcc-c++ \
        cmake \
        make \
        ninja-build \
        mesa-libGL-devel \
        gtk3-devel \
        libpng-devel libjpeg-turbo-devel libtiff-devel \
        zlib-devel expat-devel \
        # --- MinGW cross build (64-bit Windows) ---
        # wxMSW ships vendored zlib/libpng/libjpeg/libtiff for MinGW, so no
        # mingw64-wxWidgets* packages are needed here.
        mingw64-gcc-c++ \
        mingw64-binutils \
        mingw64-winpthreads-static \
        mingw64-cmake \
        # --- misc ---
        git \
        file \
    && dnf clean all

COPY editor-dev/build.sh                 /opt/build.sh
COPY cmake/toolchain-mingw-w64.cmake     /opt/cmake/toolchain-mingw-w64.cmake
RUN chmod +x /opt/build.sh

ENV EDITOR_TOOLCHAIN=/opt/cmake/toolchain-mingw-w64.cmake
WORKDIR /src

CMD ["bash", "/opt/build.sh"]
