#####################################################################################################
# Needs to derive from an old Linux to be able to generate binaries compatible with old kernels
FROM debian:bullseye as base

# Set basic env vars
ENV GOROOT          /usr/local/go
ENV GOPATH          /go
ENV PATH            ${GOPATH}/bin:${GOROOT}/bin:${PATH}
ENV OSX_NDK_X86     /usr/local/osx-ndk-x86
ENV PATH            ${OSX_NDK_X86}/bin:$PATH
ENV LD_LIBRARY_PATH ${OSX_NDK_X86}/lib:$LD_LIBRARY_PATH

WORKDIR ${GOPATH}

# Install tools
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update && \
    apt-get install -y automake autogen pkg-config \
    libtool libxml2-dev uuid-dev libssl-dev bash \
    patch cmake make tar xz-utils bzip2 gzip zlib1g-dev sed cpio \
    git apt-transport-https ca-certificates wget ssh python-is-python3 \
    gcc-multilib g++-multilib clang llvm-dev --no-install-recommends \
    || exit 1

RUN mkdir -p /root/.ssh; \
    chmod 0700 /root/.ssh; \
    ssh-keyscan github.com > /root/.ssh/known_hosts;

#####################################################################################################
# Install macOS cross-compiling toolset
FROM base as base-macos

ENV OSX_SDK_VERSION 	11.1
ENV OSX_SDK     		MacOSX$OSX_SDK_VERSION.sdk
ENV OSX_SDK_PATH 		$OSX_SDK.tar.xz

COPY $OSX_SDK_PATH /go

RUN git clone https://github.com/tpoechtrager/osxcross.git && \
    git -C osxcross checkout 035cc170338b7b252e3f13b0e3ccbf4411bffc41 || exit 1; \
    mv $OSX_SDK_PATH osxcross/tarballs/ && \
    UNATTENDED=yes SDK_VERSION=${OSX_SDK_VERSION} OSX_VERSION_MIN=10.10 osxcross/build.sh || exit 1; \
    mv osxcross/target $OSX_NDK_X86; \
    rm -rf osxcross;

#####################################################################################################
FROM base as base-taglib

# Install other cross-compiling tools and dependencies
RUN dpkg --add-architecture armel && \
    dpkg --add-architecture arm64 && \
    dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y \
# Install Windows toolset
    gcc-mingw-w64 g++-mingw-w64 \
# Install ARM toolset
    gcc-arm-linux-gnueabi g++-arm-linux-gnueabi libc6-dev-armel-cross \
    gcc-aarch64-linux-gnu g++-aarch64-linux-gnu libc6-dev-arm64-cross \
    g++-10-aarch64-linux-gnu g++-10-arm-linux-gnueabi gcc-10-aarch64-linux-gnu gcc-10-arm-linux-gnueabi \
# Install build & runtime dependencies
    lib32z1-dev \
    || exit 1

# Fix support for 386 (Linux 32bits) platform
# From https://stackoverflow.com/a/38751292
RUN ln -s /usr/include/asm-generic /usr/include/asm

# Download TagLib source
ARG TAGLIB_VERSION
ARG TAGLIB_SHA
ENV TABLIB_BUILD_OPTS     -DCMAKE_BUILD_TYPE=Release -DWITH_MP4=ON -DWITH_ASF=ON -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTING=OFF

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
FROM base-macos as build-macos

COPY --from=base-taglib /tmp/taglib-src /tmp/taglib-src

RUN echo "Build static taglib for macOS" && \
    cd /tmp/taglib-src && \
    cmake  \
        $TABLIB_BUILD_OPTS -DCMAKE_INSTALL_PREFIX=/darwin \
        -DCMAKE_C_COMPILER=${OSX_NDK_X86}/bin/o64-clang \
        -DCMAKE_CXX_COMPILER=${OSX_NDK_X86}/bin/o64-clang++ \
        -DCMAKE_RANLIB=${OSX_NDK_X86}/bin/x86_64-apple-darwin20.2-ranlib \
        -DCMAKE_AR=${OSX_NDK_X86}/bin/x86_64-apple-darwin20.2-ar && \
    make install

#####################################################################################################
FROM base-taglib as build-linux32

RUN echo "Build static taglib for Linux 32" && \
    cd /tmp/taglib-src && \
    CXXFLAGS=-m32 CFLAGS=-m32 cmake -DCMAKE_INSTALL_PREFIX=/i386 $TABLIB_BUILD_OPTS && \
    make install

#####################################################################################################
FROM base-taglib as build-arm

RUN echo "Build static taglib for Linux ARMv6 and v7" && \
    cd /tmp/taglib-src && \
    cmake \
        -DCMAKE_INSTALL_PREFIX=/arm $TABLIB_BUILD_OPTS \
        -DCMAKE_C_COMPILER=arm-linux-gnueabi-gcc \
        -DCMAKE_CXX_COMPILER=arm-linux-gnueabi-g++ && \
    make install

#####################################################################################################
FROM base-taglib as build-arm64

RUN echo "Build static taglib for Linux ARM64" && \
    cd /tmp/taglib-src && \
    cmake \
        -DCMAKE_INSTALL_PREFIX=/arm64 $TABLIB_BUILD_OPTS \
        -DCMAKE_C_COMPILER=aarch64-linux-gnu-gcc \
        -DCMAKE_CXX_COMPILER=aarch64-linux-gnu-g++ && \
    make install

#####################################################################################################
FROM base-taglib as build-win32

RUN echo "Build static taglib for Windows 32" && \
    cd /tmp/taglib-src && \
    cmake  \
        $TABLIB_BUILD_OPTS -DCMAKE_INSTALL_PREFIX=/mingw32 \
        -DCMAKE_SYSTEM_NAME=Windows \
        -DCMAKE_C_COMPILER=i686-w64-mingw32-gcc \
        -DCMAKE_CXX_COMPILER=i686-w64-mingw32-g++ && \
    make install

#####################################################################################################
FROM base-taglib as build-win64

RUN echo "Build static taglib for Windows 64" && \
    cd /tmp/taglib-src && \
    cmake  \
        $TABLIB_BUILD_OPTS -DCMAKE_INSTALL_PREFIX=/mingw64 \
        -DCMAKE_SYSTEM_NAME=Windows \
        -DCMAKE_C_COMPILER=x86_64-w64-mingw32-gcc \
        -DCMAKE_CXX_COMPILER=x86_64-w64-mingw32-g++ && \
    make install


#####################################################################################################
FROM base-taglib as final

LABEL maintainer="deluan@navidrome.org"

# Build TagLib for Linux64
RUN echo "Build static taglib for Linux 64" && \
    cd /tmp/taglib-src && \
    cmake -DCMAKE_INSTALL_PREFIX=/usr $TABLIB_BUILD_OPTS && \
    make install

# Install GoLang
ARG GO_VERSION
ARG GO_SHA
ENV GO_DOWNLOAD_FILE  go${GO_VERSION}.linux-amd64.tar.gz
ENV GO_DOWNLOAD_URL   https://golang.org/dl/${GO_DOWNLOAD_FILE}

RUN cd /tmp && \
    wget ${GO_DOWNLOAD_URL} && \
    echo "${GO_SHA} ${GO_DOWNLOAD_FILE}" | sha256sum -c - || exit 1; \
    tar -xf ${GO_DOWNLOAD_FILE} && \
    mv go /usr/local && \
    rm ${GO_DOWNLOAD_FILE}

ENV GOOS linux
ENV GOARCH amd64

# Install GoReleaser
ARG GORELEASER_VERSION
ARG GORELEASER_SHA
ENV GORELEASER_DOWNLOAD_FILE  goreleaser_Linux_x86_64.tar.gz
ENV GORELEASER_DOWNLOAD_URL   https://github.com/goreleaser/goreleaser/releases/download/v${GORELEASER_VERSION}/${GORELEASER_DOWNLOAD_FILE}

RUN wget ${GORELEASER_DOWNLOAD_URL}; \
    echo "${GORELEASER_SHA} ${GORELEASER_DOWNLOAD_FILE}" | sha256sum -c - || exit 1; \
    tar -xzf ${GORELEASER_DOWNLOAD_FILE} -C /usr/bin/ goreleaser; \
    rm ${GORELEASER_DOWNLOAD_FILE};

# Copy cross-compiled static libraries
COPY --from=build-linux32 /i386 /i386
COPY --from=build-arm /arm /arm
COPY --from=build-arm64 /arm64 /arm64
COPY --from=build-win32 /mingw32 /mingw32
COPY --from=build-win64 /mingw64 /mingw64
COPY --from=build-macos /darwin /darwin

# Copy OSX_NDK
COPY --from=base-macos ${OSX_NDK_X86} ${OSX_NDK_X86}

CMD ["goreleaser", "-v"]
