# Needs to derive from an old Linux to be able to generate binaries compatible with old kernels
FROM debian:stretch

LABEL maintainer="deluan@navidrome.org"

# Set basic env vars
ENV GOROOT  /usr/local/go
ENV GOPATH  /go
ENV PATH    ${GOPATH}/bin:${GOROOT}/bin:${PATH}

WORKDIR ${GOPATH}

# Install tools
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update && \
    apt-get install -y automake autogen \
    libtool libxml2-dev uuid-dev libssl-dev bash \
    patch cmake make tar xz-utils bzip2 gzip zlib1g-dev sed cpio \
    git apt-transport-https ca-certificates wget ssh python \
    gcc-multilib g++-multilib clang llvm-dev --no-install-recommends || exit 1; \
    rm -rf /var/lib/apt/lists/*;

#####################################################################################################
# Install macOS cross-compiling toolset
ENV OSX_SDK_VERSION 	10.12
ENV OSX_SDK     		MacOSX$OSX_SDK_VERSION.sdk
ENV OSX_NDK_X86 		/usr/local/osx-ndk-x86
ENV OSX_SDK_PATH 		/$OSX_SDK.tar.gz

COPY $OSX_SDK.tar.gz /go

RUN git clone https://github.com/tpoechtrager/osxcross.git && \
    git -C osxcross checkout d39ba022313f2d5a1f5d02caaa1efb23d07a559b || exit 1; \
    mv $OSX_SDK.tar.gz osxcross/tarballs/ && \
    UNATTENDED=yes SDK_VERSION=${OSX_SDK_VERSION} OSX_VERSION_MIN=10.10 osxcross/build.sh || exit 1; \
    mv osxcross/target $OSX_NDK_X86; \
    rm -rf osxcross;

ENV PATH              $OSX_NDK_X86/bin:$PATH
ENV LD_LIBRARY_PATH   $OSX_NDK_X86/lib:$LD_LIBRARY_PATH

RUN mkdir -p /root/.ssh; \
    chmod 0700 /root/.ssh; \
    ssh-keyscan github.com > /root/.ssh/known_hosts;

#####################################################################################################
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
# Install build & runtime dependencies	
    pkg-config libtag1-dev \	
    libtag1-dev:i386 \	
    libtag1-dev:arm64 \	
    libtag1-dev:armel \
    || exit 1; rm -rf /var/lib/apt/lists/*;

# Fix support for 386 (Linux 32bits) platform
# From https://stackoverflow.com/a/38751292
RUN ln -s /usr/include/asm-generic /usr/include/asm

#####################################################################################################
# Install/compile taglib for various platforms

# Download latest source
ENV TAGLIB_VERSION=1.11.1
RUN cd /tmp && \
    wget https://taglib.github.io/releases/taglib-$TAGLIB_VERSION.tar.gz

RUN echo "Build static taglib for Linux 64" && \
    cd /tmp && \
    tar xvfz taglib-$TAGLIB_VERSION.tar.gz && \
    cd taglib-$TAGLIB_VERSION && \
    cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release -DWITH_MP4=ON -DWITH_ASF=ON && \
    make install && \
    cd .. && \
    rm -rf taglib-$TAGLIB_VERSION

RUN echo "Build static taglib for Linux 32" && \
    cd /tmp && \
    tar xvfz taglib-$TAGLIB_VERSION.tar.gz && \
    cd taglib-$TAGLIB_VERSION && \
    CXXFLAGS=-m32 CFLAGS=-m32 cmake -DCMAKE_BUILD_TYPE=Release -DWITH_MP4=ON -DWITH_ASF=ON && \
    make && \
    cp taglib/libtag.a /usr/lib/i386-linux-gnu && \
    cd .. && \
    rm -rf taglib-$TAGLIB_VERSION

RUN echo "Build static taglib for macOS" && \
    cd /tmp && \
    tar xvfz taglib-$TAGLIB_VERSION.tar.gz && \
    cd taglib-$TAGLIB_VERSION && \
    cmake  \
        -DCMAKE_INSTALL_PREFIX=/darwin -DCMAKE_BUILD_TYPE=Release -DWITH_MP4=ON -DWITH_ASF=ON \
        -DCMAKE_C_COMPILER=/usr/local/osx-ndk-x86/bin/o64-clang \
        -DCMAKE_CXX_COMPILER=/usr/local/osx-ndk-x86/bin/o64-clang++ \
        -DCMAKE_RANLIB=/usr/local/osx-ndk-x86/bin/x86_64-apple-darwin16-ranlib \
        -DCMAKE_AR=/usr/local/osx-ndk-x86/bin/x86_64-apple-darwin16-ar && \
    make install && \
    cd .. && \
    rm -rf taglib-$TAGLIB_VERSION

RUN echo "Build static taglib for Linux ARM" && \
    cd /tmp && \
    tar xvfz taglib-$TAGLIB_VERSION.tar.gz && \
    cd taglib-$TAGLIB_VERSION && \
    cmake \
        -DCMAKE_BUILD_TYPE=Release -DWITH_MP4=ON -DWITH_ASF=ON \
        -DCMAKE_C_COMPILER=arm-linux-gnueabi-gcc \
        -DCMAKE_CXX_COMPILER=arm-linux-gnueabi-g++ && \
    make && \
    cp taglib/libtag.a /usr/lib/arm-linux-gnueabi && \
    cd .. && \
    rm -rf taglib-$TAGLIB_VERSION

RUN echo "Build static taglib for Linux ARM64" && \
    cd /tmp && \
    tar xvfz taglib-$TAGLIB_VERSION.tar.gz && \
    cd taglib-$TAGLIB_VERSION && \
    cmake \
        -DCMAKE_BUILD_TYPE=Release -DWITH_MP4=ON -DWITH_ASF=ON \
        -DCMAKE_C_COMPILER=aarch64-linux-gnu-gcc \
        -DCMAKE_CXX_COMPILER=aarch64-linux-gnu-g++ && \
    make && \
    cp taglib/libtag.a /usr/lib/aarch64-linux-gnu && \
    cd .. && \
    rm -rf taglib-$TAGLIB_VERSION

RUN echo "Build static taglib for Windows 32" && \
    cd /tmp && \
    tar xvfz taglib-$TAGLIB_VERSION.tar.gz && \
    cd taglib-$TAGLIB_VERSION && \
    cmake  \
        -DCMAKE_INSTALL_PREFIX=/mingw32 -DCMAKE_BUILD_TYPE=Release -DWITH_MP4=ON -DWITH_ASF=ON \
        -DBUILD_SHARED_LIBS=OFF -DCMAKE_SYSTEM_NAME=Windows \
        -DCMAKE_C_COMPILER=i686-w64-mingw32-gcc \
        -DCMAKE_CXX_COMPILER=i686-w64-mingw32-g++ && \
    make install && \
    cd .. && \
    rm -rf taglib-$TAGLIB_VERSION

RUN echo "Build static taglib for Windows 64" && \
    cd /tmp && \
    tar xvfz taglib-$TAGLIB_VERSION.tar.gz && \
    cd taglib-$TAGLIB_VERSION && \
    cmake  \
        -DCMAKE_INSTALL_PREFIX=/mingw64 -DCMAKE_BUILD_TYPE=Release -DWITH_MP4=ON -DWITH_ASF=ON \
        -DBUILD_SHARED_LIBS=OFF -DCMAKE_SYSTEM_NAME=Windows \
        -DCMAKE_C_COMPILER=x86_64-w64-mingw32-gcc \
        -DCMAKE_CXX_COMPILER=x86_64-w64-mingw32-g++ && \
    make install && \
    cd .. && \
    rm -rf taglib-$TAGLIB_VERSION

#####################################################################################################
# Install GoLang and Go tools

# Install GoLang
ENV GO_VERSION 1.16.2

RUN cd /tmp && \
    wget https://golang.org/dl/go${GO_VERSION}.linux-amd64.tar.gz && \
    tar -xf go*.tar.gz && \
    mv go /usr/local

# Install GoReleaser
ENV GORELEASER_VERSION        0.139.0
ENV GORELEASER_SHA            6b37a8a1125b8878020a4c222bb74c199e89b6fbc5699678c9e06bbebf41b3df
ENV GORELEASER_DOWNLOAD_FILE  goreleaser_Linux_x86_64.tar.gz
ENV GORELEASER_DOWNLOAD_URL   https://github.com/goreleaser/goreleaser/releases/download/v${GORELEASER_VERSION}/${GORELEASER_DOWNLOAD_FILE}

RUN  wget ${GORELEASER_DOWNLOAD_URL}; \
    echo "$GORELEASER_SHA $GORELEASER_DOWNLOAD_FILE" | sha256sum -c - || exit 1; \
    tar -xzf $GORELEASER_DOWNLOAD_FILE -C /usr/bin/ goreleaser; \
    rm $GORELEASER_DOWNLOAD_FILE;

CMD ["goreleaser", "-v"]
