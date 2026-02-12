#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_ROOT="${BUILD_ROOT:-$ROOT_DIR/build}"
JOBS=$(sysctl -n hw.ncpu 2>/dev/null || echo 4)
DEPLOYMENT_TARGET="${IOS_DEPLOYMENT_TARGET:-13.0}"

build_mbedtls() {
    local arch=$1
    local sysroot=$2
    local label=$3

    echo "=== Building mbedTLS — $label ($arch) ==="

    cmake -S "$ROOT_DIR/deps/mbedtls" -B "$BUILD_ROOT/mbedtls-$label" \
        -DCMAKE_SYSTEM_NAME=iOS \
        -DCMAKE_OSX_ARCHITECTURES="$arch" \
        -DCMAKE_OSX_DEPLOYMENT_TARGET="$DEPLOYMENT_TARGET" \
        ${sysroot:+-DCMAKE_OSX_SYSROOT=$sysroot} \
        -DENABLE_TESTING=OFF \
        -DENABLE_PROGRAMS=OFF \
        -DCMAKE_C_FLAGS="-DMBEDTLS_SSL_DTLS_SRTP"

    cmake --build "$BUILD_ROOT/mbedtls-$label" -j"$JOBS"
    cmake --install "$BUILD_ROOT/mbedtls-$label" --prefix "$BUILD_ROOT/mbedtls-install-$label"
}

build_mbedtls arm64 ""                ios
build_mbedtls arm64 iphonesimulator   sim-arm64
build_mbedtls x86_64 iphonesimulator  sim-x64

echo "=== mbedTLS done ==="
