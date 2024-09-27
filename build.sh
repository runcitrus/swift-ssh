#!/bin/sh

set -e

OPENSSL="openssl-3.3.2"
LIBSSH2="libssh2-1.11.0"

cd `dirname $0`
TMPDIR="$PWD/tmp"
INCDIR="$TMPDIR/include"
LIBDIR="$TMPDIR/lib"
OUTDIR="$PWD/Frameworks"

#
# openssl
#

mkdir -p $INCDIR $LIBDIR

curl -sL https://github.com/openssl/openssl/releases/download/$OPENSSL/$OPENSSL.tar.gz | tar -zxf -
cd $OPENSSL

cp -r include/openssl $INCDIR

build_openssl() {
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

    cp libcrypto.a $LIBDIR/libcrypto_$ARCH.a
    make clean
}

build_openssl arm64
build_openssl x86_64

cd ..
rm -rf $OPENSSL

lipo -create $LIBDIR/libcrypto_x86_64.a $LIBDIR/libcrypto_arm64.a -output $LIBDIR/libcrypto.a
rm $LIBDIR/libcrypto_x86_64.a $LIBDIR/libcrypto_arm64.a

xcodebuild -create-xcframework \
    -library $LIBDIR/libcrypto.a \
    -headers $INCDIR \
    -output $OUTDIR/Clibcrypto.xcframework

rm -rf $TMPDIR

#
# libssh2
#

mkdir -p $INCDIR $LIBDIR

curl -sL https://github.com/libssh2/libssh2/releases/download/$LIBSSH2/$LIBSSH2.tar.gz | tar -zxf -
cd $LIBSSH2

cp -r include/* $INCDIR

build_libssh2() {
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

    cp src/libssh2.a $LIBDIR/libssh2_$ARCH.a
    cd ..
    rm -rf build
}

build_libssh2 arm64
build_libssh2 x86_64

cd ..
rm -rf $LIBSSH2

lipo -create $LIBDIR/libssh2_x86_64.a $LIBDIR/libssh2_arm64.a -output $LIBDIR/libssh2.a
rm $LIBDIR/libssh2_x86_64.a $LIBDIR/libssh2_arm64.a

xcodebuild -create-xcframework \
    -library $LIBDIR/libssh2.a \
    -headers $INCDIR \
    -output $OUTDIR/Clibssh2.xcframework

rm -rf $TMPDIR

cat <<EOF > $OUTDIR/Clibssh2.xcframework/macos-arm64_x86_64/Headers/module.modulemap
module Clibssh2 {
    header "libssh2.h"
    header "libssh2_sftp.h"
    header "libssh2_publickey.h"
    export *
}
EOF
