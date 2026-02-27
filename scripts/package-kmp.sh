#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_ROOT="${BUILD_ROOT:-$ROOT_DIR/build}"
KMP_LIBS="$BUILD_ROOT/kmp-libs"

echo "=== Preparing .a files for KMP ==="

merge_libs() {
    local label=$1
    local target_dir=$2

    mkdir -p "$KMP_LIBS/$target_dir"

    echo "  Merging $label → kmp-libs/$target_dir/libdatachannel.a"

    libtool -static -o "$KMP_LIBS/$target_dir/libdatachannel.a" \
        "$BUILD_ROOT/datachannel-$label/libdatachannel-static.a" \
        "$BUILD_ROOT/datachannel-$label/deps/libjuice/libjuice-static.a" \
        "$BUILD_ROOT/datachannel-$label/deps/usrsctp/usrsctplib/libusrsctp.a" \
        "$BUILD_ROOT/mbedtls-install-$label/lib/libmbedtls.a" \
        "$BUILD_ROOT/mbedtls-install-$label/lib/libmbedcrypto.a" \
        "$BUILD_ROOT/mbedtls-install-$label/lib/libmbedx509.a"
}

merge_libs ios         iosArm64
merge_libs sim-arm64   iosSimulatorArm64
merge_libs sim-x64     iosX64
merge_libs macos-arm64 macosArm64
merge_libs macos-x64   macosX64

echo "=== .a files ready in $KMP_LIBS ==="
echo ""
echo "To publish locally:  cd kmp && ./gradlew publishToMavenLocal"
echo "To publish to repo:  cd kmp && ./gradlew publish"
