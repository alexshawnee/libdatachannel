#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_ROOT="${BUILD_ROOT:-$ROOT_DIR/build}"
JOBS=$(sysctl -n hw.ncpu 2>/dev/null || echo 4)
IOS_DEPLOYMENT_TARGET="${IOS_DEPLOYMENT_TARGET:-13.0}"
MACOS_DEPLOYMENT_TARGET="${MACOS_DEPLOYMENT_TARGET:-11.0}"

build_mbedtls() {
    local arch=$1
    local system_name=$2  # iOS or empty (native macOS)
    local sysroot=$3
    local deployment_target=$4
    local label=$5

    echo "=== Building mbedTLS — $label ($arch) ==="

    cmake -S "$ROOT_DIR/deps/mbedtls" -B "$BUILD_ROOT/mbedtls-$label" \
        -DCMAKE_SYSTEM_NAME="$system_name" \
        -DCMAKE_OSX_ARCHITECTURES="$arch" \
        -DCMAKE_OSX_DEPLOYMENT_TARGET="$deployment_target" \
        ${sysroot:+-DCMAKE_OSX_SYSROOT=$sysroot} \
        -DENABLE_TESTING=OFF \
        -DENABLE_PROGRAMS=OFF \
        -DCMAKE_C_FLAGS="-DMBEDTLS_SSL_DTLS_SRTP"

    cmake --build "$BUILD_ROOT/mbedtls-$label" -j"$JOBS"
    cmake --install "$BUILD_ROOT/mbedtls-$label" --prefix "$BUILD_ROOT/mbedtls-install-$label"
}

# --- iOS ---
build_mbedtls arm64  iOS ""               "$IOS_DEPLOYMENT_TARGET" ios
build_mbedtls arm64  iOS iphonesimulator  "$IOS_DEPLOYMENT_TARGET" sim-arm64
build_mbedtls x86_64 iOS iphonesimulator  "$IOS_DEPLOYMENT_TARGET" sim-x64

# --- macOS ---
build_mbedtls arm64  "" "" "$MACOS_DEPLOYMENT_TARGET" macos-arm64
build_mbedtls x86_64 "" "" "$MACOS_DEPLOYMENT_TARGET" macos-x64

echo "=== mbedTLS done ==="
