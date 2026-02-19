#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_ROOT="${BUILD_ROOT:-$ROOT_DIR/build}"
JOBS=$(sysctl -n hw.ncpu 2>/dev/null || echo 4)
IOS_DEPLOYMENT_TARGET="${IOS_DEPLOYMENT_TARGET:-13.0}"
MACOS_DEPLOYMENT_TARGET="${MACOS_DEPLOYMENT_TARGET:-11.0}"

build_datachannel() {
    local arch=$1
    local system_name=$2
    local sysroot=$3
    local deployment_target=$4
    local label=$5

    echo "=== Building libdatachannel — $label ($arch) ==="

    cmake -B "$BUILD_ROOT/datachannel-$label" -S "$ROOT_DIR" \
        -DCMAKE_SYSTEM_NAME="$system_name" \
        -DCMAKE_OSX_ARCHITECTURES="$arch" \
        -DCMAKE_OSX_DEPLOYMENT_TARGET="$deployment_target" \
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

# --- iOS ---
build_datachannel arm64  iOS ""               "$IOS_DEPLOYMENT_TARGET" ios
build_datachannel arm64  iOS iphonesimulator  "$IOS_DEPLOYMENT_TARGET" sim-arm64
build_datachannel x86_64 iOS iphonesimulator  "$IOS_DEPLOYMENT_TARGET" sim-x64

# --- macOS ---
build_datachannel arm64  Darwin "" "$MACOS_DEPLOYMENT_TARGET" macos-arm64
build_datachannel x86_64 Darwin "" "$MACOS_DEPLOYMENT_TARGET" macos-x64

echo "=== libdatachannel done ==="
