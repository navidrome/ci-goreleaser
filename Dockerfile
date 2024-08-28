#####################################################################################################
FROM ghcr.io/goreleaser/goreleaser-cross:v1.23 AS base

RUN apt-get update
#RUN apt-get install -y pkg-config zlib1g-dev lib32z1-dev
RUN apt-get install -y gcc-multilib g++-multilib pkg-config zlib1g-dev lib32z1-dev
RUN #apt-get install -y binutils build-essential cpp cpp-10 dpkg-dev g++ g++-10 gcc gcc-10

#####################################################################################################
FROM base AS base-taglib

# Download TagLib source
ARG TAGLIB_VERSION
ARG TAGLIB_SHA
ENV TABLIB_BUILD_OPTS=-DCMAKE_BUILD_TYPE=Release -DWITH_MP4=ON -DWITH_ASF=ON -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTING=OFF

RUN cd /tmp && \
    git clone https://github.com/taglib/taglib.git && \
    cd taglib && \
    git checkout v$TAGLIB_VERSION && \
    test `git rev-parse HEAD` = $TAGLIB_SHA || exit 1; \
    git submodule update --init && \
    find . -name .git | xargs rm -rf

RUN cd /tmp && \
    mv taglib /tmp/taglib-src


#####################################################################################################
FROM base-taglib AS build-arm

RUN echo "Build static taglib for Linux ARMv6 and v7" && \
    cd /tmp/taglib-src && \
    cmake \
        -DCMAKE_INSTALL_PREFIX=/arm $TABLIB_BUILD_OPTS \
        -DCMAKE_C_COMPILER=arm-linux-gnueabi-gcc \
        -DCMAKE_CXX_COMPILER=arm-linux-gnueabi-g++ && \
    make install

#####################################################################################################
FROM base-taglib AS build-arm64

RUN echo "Build static taglib for Linux ARM64" && \
    cd /tmp/taglib-src && \
    cmake \
        -DCMAKE_INSTALL_PREFIX=/arm64 $TABLIB_BUILD_OPTS \
        -DCMAKE_C_COMPILER=aarch64-linux-gnu-gcc \
        -DCMAKE_CXX_COMPILER=aarch64-linux-gnu-g++ && \
    make install

#####################################################################################################
FROM base-taglib AS build-win32

RUN echo "Build static taglib for Windows 32" && \
    cd /tmp/taglib-src && \
    cmake  \
        -DCMAKE_INSTALL_PREFIX=/mingw32 $TABLIB_BUILD_OPTS \
        -DCMAKE_SYSTEM_NAME=Windows \
        -DCMAKE_C_COMPILER=i686-w64-mingw32-gcc \
        -DCMAKE_CXX_COMPILER=i686-w64-mingw32-g++ && \
    make install

#####################################################################################################
FROM base-taglib AS build-win64

RUN echo "Build static taglib for Windows 64" && \
    cd /tmp/taglib-src && \
    cmake  \
        -DCMAKE_INSTALL_PREFIX=/mingw64 $TABLIB_BUILD_OPTS \
        -DCMAKE_SYSTEM_NAME=Windows \
        -DCMAKE_C_COMPILER=x86_64-w64-mingw32-gcc \
        -DCMAKE_CXX_COMPILER=x86_64-w64-mingw32-g++ && \
    make install


#####################################################################################################
FROM base-taglib AS build-darwin-arm64

RUN echo "Build static taglib for darwin arm64" && \
    cd /tmp/taglib-src && \
    cmake  \
        -DCMAKE_INSTALL_PREFIX=/darwin-arm64 $TABLIB_BUILD_OPTS \
        -DCMAKE_C_COMPILER=oa64-clang \
        -DCMAKE_CXX_COMPILER=oa64-clang++ && \
    make install

#####################################################################################################
FROM base-taglib AS build-darwin-amd64

RUN echo "Build static taglib for darwin amd64" && \
    cd /tmp/taglib-src && \
    cmake  \
        -DCMAKE_INSTALL_PREFIX=/darwin-amd64 $TABLIB_BUILD_OPTS \
        -DCMAKE_C_COMPILER=o64-clang \
        -DCMAKE_CXX_COMPILER=o64-clang++ && \
    make install

#####################################################################################################
FROM base-taglib AS final

# Build TagLib for Linux64
RUN echo "Build static taglib for Linux 64" && \
    cd /tmp/taglib-src && \
    cmake $TABLIB_BUILD_OPTS  \
        -DCMAKE_C_COMPILER=x86_64-linux-gnu-gcc \
        -DCMAKE_CXX_COMPILER=x86_64-linux-gnu-g++ && \
    make install

#####################################################################################################
#FROM base AS final

LABEL maintainer="deluan@navidrome.org"
ENV GOOS=linux
ENV GOARCH=amd64

# Copy cross-compiled static libraries
COPY --from=build-arm /arm /arm
COPY --from=build-arm64 /arm64 /arm64
COPY --from=build-win32 /mingw32 /mingw32
COPY --from=build-win64 /mingw64 /mingw64
COPY --from=build-darwin-amd64 /darwin-amd64 /darwin-amd64
COPY --from=build-darwin-arm64 /darwin-arm64 /darwin-arm64
#COPY --from=build-linux64 /amd64 /amd64

#CMD ["goreleaser", "-v"]
