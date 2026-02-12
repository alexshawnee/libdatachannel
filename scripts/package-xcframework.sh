#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_ROOT="${BUILD_ROOT:-$ROOT_DIR/build}"
OUTPUT_DIR="${OUTPUT_DIR:-$BUILD_ROOT}"

merge_libs() {
    local label=$1
    local output=$2

    echo "=== Merging static libs — $label ==="

    libtool -static -o "$output" \
        "$BUILD_ROOT/datachannel-$label/libdatachannel-static.a" \
        "$BUILD_ROOT/datachannel-$label/deps/libjuice/libjuice-static.a" \
        "$BUILD_ROOT/datachannel-$label/deps/usrsctp/usrsctplib/libusrsctp.a" \
        "$BUILD_ROOT/mbedtls-install-$label/lib/libmbedtls.a" \
        "$BUILD_ROOT/mbedtls-install-$label/lib/libmbedcrypto.a" \
        "$BUILD_ROOT/mbedtls-install-$label/lib/libmbedx509.a"
}

merge_libs ios        "$BUILD_ROOT/libdatachannel-ios-arm64.a"
merge_libs sim-arm64  "$BUILD_ROOT/libdatachannel-sim-arm64.a"
merge_libs sim-x64    "$BUILD_ROOT/libdatachannel-sim-x64.a"

echo "=== Creating fat simulator binary ==="
lipo -create \
    "$BUILD_ROOT/libdatachannel-sim-arm64.a" \
    "$BUILD_ROOT/libdatachannel-sim-x64.a" \
    -output "$BUILD_ROOT/libdatachannel-sim.a"

echo "=== Preparing headers ==="
HEADERS_DIR="$BUILD_ROOT/headers"
rm -rf "$HEADERS_DIR"
mkdir -p "$HEADERS_DIR"
cp "$ROOT_DIR/include/rtc/rtc.h" "$HEADERS_DIR/"
cp "$ROOT_DIR/include/rtc/version.h" "$HEADERS_DIR/"
cat > "$HEADERS_DIR/module.modulemap" <<'EOF'
module libdatachannel {
    header "rtc.h"
    export *
}
EOF

echo "=== Creating XCFramework ==="
rm -rf "$OUTPUT_DIR/libdatachannel.xcframework"
xcodebuild -create-xcframework \
    -library "$BUILD_ROOT/libdatachannel-ios-arm64.a" -headers "$HEADERS_DIR" \
    -library "$BUILD_ROOT/libdatachannel-sim.a" -headers "$HEADERS_DIR" \
    -output "$OUTPUT_DIR/libdatachannel.xcframework"

echo "=== Done: $OUTPUT_DIR/libdatachannel.xcframework ==="
