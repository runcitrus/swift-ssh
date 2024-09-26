#!/bin/sh

set -e

cd `dirname $0`

LIBSSH2="libssh2-1.11.0"

curl -sL https://github.com/libssh2/libssh2/releases/download/$LIBSSH2/$LIBSSH2.tar.gz | tar -zxf -
cd $LIBSSH2

mkdir -p ../{include,lib}
cp -r include/* ../include

build() {
    ARCH=$1

    mkdir build
    cd build

    cmake \
        -DCMAKE_OSX_ARCHITECTURES=$ARCH \
        -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
        -DBUILD_SHARED_LIBS=OFF \
        -DBUILD_EXAMPLES=OFF \
        -DBUILD_TESTING=OFF \
        -DCRYPTO_BACKEND=OpenSSL \
        ..
    make

    cp src/libssh2.a ../../lib/libssh2_$ARCH.a
    cd ..
    rm -rf build
}

build arm64
build x86_64

cd ..
rm -rf $LIBSSH2

cd lib
lipo -create libssh2_x86_64.a libssh2_arm64.a -output libssh2.a
rm libssh2_x86_64.a libssh2_arm64.a
