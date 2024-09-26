#!/bin/sh

set -e

cd `dirname $0`

MBEDTLS="mbedtls-2.28.9"

curl -sL https://github.com/Mbed-TLS/mbedtls/releases/download/$MBEDTLS/$MBEDTLS.tar.bz2 | tar -jxf -
cd $MBEDTLS

mkdir -p ../{include,lib}
cp -r include/mbedtls ../include
cp -r include/psa ../include

build() {
    ARCH=$1

    mkdir build
    cd build

    cmake \
        -DCMAKE_OSX_ARCHITECTURES=$ARCH \
        -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
        -DENABLE_TESTING=OFF \
        ..
    make -j4

    cp library/libmbedcrypto.a ../../lib/libmbedcrypto_$ARCH.a
    cd ..
    rm -rf build
}

build arm64
build x86_64

cd ..
rm -rf $MBEDTLS

cd lib
lipo -create libmbedcrypto_x86_64.a libmbedcrypto_arm64.a -output libmbedcrypto.a
rm libmbedcrypto_x86_64.a libmbedcrypto_arm64.a
