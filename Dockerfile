FROM golang:1.14.7

LABEL maintainer="deluan@navidrome.org"

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

# macOS cross compile setup
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

# Install GoReleaser
ENV GORELEASER_VERSION        0.139.0
ENV GORELEASER_SHA            6b37a8a1125b8878020a4c222bb74c199e89b6fbc5699678c9e06bbebf41b3df
ENV GORELEASER_DOWNLOAD_FILE  goreleaser_Linux_x86_64.tar.gz
ENV GORELEASER_DOWNLOAD_URL   https://github.com/goreleaser/goreleaser/releases/download/v${GORELEASER_VERSION}/${GORELEASER_DOWNLOAD_FILE}

RUN  wget ${GORELEASER_DOWNLOAD_URL}; \
    echo "$GORELEASER_SHA $GORELEASER_DOWNLOAD_FILE" | sha256sum -c - || exit 1; \
    tar -xzf $GORELEASER_DOWNLOAD_FILE -C /usr/bin/ goreleaser; \
    rm $GORELEASER_DOWNLOAD_FILE;

# Install other cross-compiling tools and dependencies
RUN dpkg --add-architecture armhf && \
    dpkg --add-architecture arm64 && \
    dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y \
# Install Windows toolset
    gcc-mingw-w64 g++-mingw-w64 \
# Install ARM toolset
    gcc-arm-linux-gnueabihf g++-arm-linux-gnueabihf libc6-dev-armhf-cross \
    gcc-aarch64-linux-gnu g++-aarch64-linux-gnu libc6-dev-arm64-cross \
# Install build & runtime dependencies
    libtag1-dev \
    libtag1-dev:i386 \
    libtag1-dev:arm64 \
    libtag1-dev:armhf \
    || exit 1; rm -rf /var/lib/apt/lists/*;

# Install extra tools used by the build
RUN go get -u github.com/go-bindata/go-bindata/...

# Fix support for 386 (Linux 32bits) platform
# From https://stackoverflow.com/a/38751292
RUN ln -s /usr/include/asm-generic /usr/include/asm

#####################################################################################################
# Install/compile taglib for various platforms

# Download and install static taglib for Windows
RUN cd /tmp && \
    wget https://repo.msys2.org/mingw/x86_64/mingw-w64-x86_64-taglib-1.11.1-1-any.pkg.tar.xz && \
    tar xvf mingw-w64-x86_64-taglib-1.11.1-1-any.pkg.tar.xz && \
    mv mingw64/ / && \
    rm mingw-w64-x86_64-taglib-1.11.1-1-any.pkg.tar.xz

RUN cd /tmp && \
    wget https://repo.msys2.org/mingw/i686/mingw-w64-i686-taglib-1.11.1-1-any.pkg.tar.xz && \
    tar xvf mingw-w64-i686-taglib-1.11.1-1-any.pkg.tar.xz && \
    mv mingw32/ / && \
    rm mingw-w64-i686-taglib-1.11.1-1-any.pkg.tar.xz

RUN cd /tmp && \
    wget https://taglib.github.io/releases/taglib-1.11.1.tar.gz

# Build static taglib for Linux 64
RUN cd /tmp && \
    tar xvfz taglib-1.11.1.tar.gz && \
    cd taglib-1.11.1 && \
    cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release -DWITH_MP4=ON -DWITH_ASF=ON && \
    make install && \
    cd .. && \
    rm -rf taglib-1.11.1

# Build static taglib for Linux 32
RUN cd /tmp && \
    tar xvfz taglib-1.11.1.tar.gz && \
    cd taglib-1.11.1 && \
    CXXFLAGS=-m32 CFLAGS=-m32 cmake -DCMAKE_BUILD_TYPE=Release -DWITH_MP4=ON -DWITH_ASF=ON && \
    make && \
    cp taglib/libtag.a /usr/lib/i386-linux-gnu && \
    cd .. && \
    rm -rf taglib-1.11.1

# Build static taglib for macOS
RUN cd /tmp && \
    tar xvfz taglib-1.11.1.tar.gz && \
    cd taglib-1.11.1 && \
    cmake  \
        -DCMAKE_INSTALL_PREFIX=/darwin -DCMAKE_BUILD_TYPE=Release -DWITH_MP4=ON -DWITH_ASF=ON \
        -DCMAKE_C_COMPILER=/usr/local/osx-ndk-x86/bin/o64-clang \
        -DCMAKE_CXX_COMPILER=/usr/local/osx-ndk-x86/bin/o64-clang++ \
        -DCMAKE_RANLIB=/usr/local/osx-ndk-x86/bin/x86_64-apple-darwin16-ranlib \
        -DCMAKE_AR=/usr/local/osx-ndk-x86/bin/x86_64-apple-darwin16-ar && \
    make install && \
    cd .. && \
    rm -rf taglib-1.11.1

# Build static taglib for Linux ARMHF
RUN cd /tmp && \
    tar xvfz taglib-1.11.1.tar.gz && \
    cd taglib-1.11.1 && \
    cmake \
        -DCMAKE_BUILD_TYPE=Release -DWITH_MP4=ON -DWITH_ASF=ON \
        -DCMAKE_C_COMPILER=arm-linux-gnueabihf-gcc \
        -DCMAKE_CXX_COMPILER=arm-linux-gnueabihf-g++ && \
    make && \
    cp taglib/libtag.a /usr/lib/arm-linux-gnueabihf && \
    cd .. && \
    rm -rf taglib-1.11.1

# Build static taglib for Linux ARM64
RUN cd /tmp && \
    tar xvfz taglib-1.11.1.tar.gz && \
    cd taglib-1.11.1 && \
    cmake \
        -DCMAKE_BUILD_TYPE=Release -DWITH_MP4=ON -DWITH_ASF=ON \
        -DCMAKE_C_COMPILER=aarch64-linux-gnu-gcc \
        -DCMAKE_CXX_COMPILER=aarch64-linux-gnu-g++ && \
    make && \
    cp taglib/libtag.a /usr/lib/aarch64-linux-gnu && \
    cd .. && \
    rm -rf taglib-1.11.1

CMD ["goreleaser", "-v"]


##############################################################################################################################
# Notes for self: https://dh1tw.de/2019/12/cross-compiling-golang-cgo-projects/

# RUN echo "alias ll='ls -l $LS_OPTIONS'" >> /root/.bashrc
# ENV TEST="go get github.com/nicksellen/audiotags/audiotags"
# ENV T go build -o a386 -ldflags="-extldflags '-static -lz'" ./audiotags

# ENV GOOS=linux
# ENV GOARCH=x64
# ENV CGO_ENABLED=1
# -ldflags="-extldflags '-static -lz'"

# ENV GOOS=linux
# ENV GOARCH=386
# ENV CGO_ENABLED=1
# ENV PATH="/go/bin/${GOOS}_${GOARCH}:${PATH}"

# ENV GOOS=darwin
# ENV GOARCH=amd64
# ENV CGO_ENABLED=1
# ENV CC=o64-clang
# ENV CXX=o64-clang++
# ENV AR=x86_64-apple-darwin16-ar
# ENV RANLIB=x86_64-apple-darwin16-ranlib
# ENV PATH="/go/bin:/usr/local/go/bin:${PATH}"
# ENV PKG_CONFIG_PATH=/darwin/lib/pkgconfig

# ENV GOOS=windows
# ENV GOARCH=amd64
# ENV CGO_ENABLED=1
# ENV CC=x86_64-w64-mingw32-gcc
# ENV CXX=x86_64-w64-mingw32-g++
# ENV PATH="/go/bin:/usr/local/go/bin:${PATH}"
# ENV PKG_CONFIG_PATH=/mingw64/lib/pkgconfig

# ENV GOOS=windows
# ENV GOARCH=386
# ENV CGO_ENABLED=1
# ENV CC=i686-w64-mingw32-gcc
# ENV CXX=i686-w64-mingw32-g++
# ENV PATH="/go/bin:/usr/local/go/bin:${PATH}"
# ENV PKG_CONFIG_PATH=/mingw32/lib/pkgconfig

# ENV GOOS=linux
# ENV GOARCH=arm
# ENV CGO_ENABLED=1
# ENV CC=arm-linux-gnueabihf-gcc
# ENV CXX=arm-linux-gnueabihf-g++
# ENV PATH="/go/bin/${GOOS}_${GOARCH}:${PATH}"

# ENV GOOS=linux
# ENV GOARCH=arm64
# ENV CGO_ENABLED=1
# ENV CC=aarch64-linux-gnu-gcc
# ENV CXX=aarch64-linux-gnu-g++
# ENV PATH="/go/bin/${GOOS}_${GOARCH}:${PATH}"

