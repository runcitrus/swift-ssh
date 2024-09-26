#!/bin/sh

set -e

cd `dirname $0`

OPENSSL="openssl-3.3.2"

curl -sL https://github.com/openssl/openssl/releases/download/$OPENSSL/$OPENSSL.tar.gz | tar -zxf -
cd $OPENSSL

mkdir -p ../{include,lib}
cp -r include/openssl ../include

build() {
    ARCH=$1

    export MACOSX_DEPLOYMENT_TARGET=14.0
    ./Configure \
        no-asm \
        no-shared \
        no-ssl3 \
        no-comp \
        no-tests \
        no-filenames \
        no-dso \
        darwin64-$ARCH-cc

    make build_generated
    make -j4 libcrypto.a

    cp libcrypto.a ../lib/libcrypto_$ARCH.a
    make clean
}

build arm64
build x86_64

cd ..
rm -rf $OPENSSL

cd lib
lipo -create libcrypto_x86_64.a libcrypto_arm64.a -output libcrypto.a
rm libcrypto_x86_64.a libcrypto_arm64.a
