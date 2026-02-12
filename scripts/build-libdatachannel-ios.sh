#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_ROOT="${BUILD_ROOT:-$ROOT_DIR/build}"
JOBS=$(sysctl -n hw.ncpu 2>/dev/null || echo 4)
DEPLOYMENT_TARGET="${IOS_DEPLOYMENT_TARGET:-13.0}"

build_datachannel() {
    local arch=$1
    local sysroot=$2
    local label=$3

    echo "=== Building libdatachannel — $label ($arch) ==="

    cmake -B "$BUILD_ROOT/datachannel-$label" -S "$ROOT_DIR" \
        -DCMAKE_SYSTEM_NAME=iOS \
        -DCMAKE_OSX_ARCHITECTURES="$arch" \
        -DCMAKE_OSX_DEPLOYMENT_TARGET="$DEPLOYMENT_TARGET" \
        ${sysroot:+-DCMAKE_OSX_SYSROOT=$sysroot} \
        -DUSE_MBEDTLS=ON \
        -DCMAKE_PREFIX_PATH="$BUILD_ROOT/mbedtls-install-$label" \
        -DCMAKE_FIND_ROOT_PATH="$BUILD_ROOT/mbedtls-install-$label" \
        -DNO_MEDIA=ON \
        -DNO_WEBSOCKET=ON \
        -DNO_TESTS=ON \
        -DNO_EXAMPLES=ON \
        -DBUILD_SHARED_LIBS=OFF \
        -DCMAKE_CXX_FLAGS="-DMBEDTLS_SSL_DTLS_SRTP"

    cmake --build "$BUILD_ROOT/datachannel-$label" --target datachannel-static -j"$JOBS"
}

build_datachannel arm64  ""               ios
build_datachannel arm64  iphonesimulator  sim-arm64
build_datachannel x86_64 iphonesimulator  sim-x64

echo "=== libdatachannel done ==="
