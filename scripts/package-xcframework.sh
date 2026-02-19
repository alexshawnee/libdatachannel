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

# --- iOS ---
merge_libs ios        "$BUILD_ROOT/libdatachannel-ios-arm64.a"
merge_libs sim-arm64  "$BUILD_ROOT/libdatachannel-sim-arm64.a"
merge_libs sim-x64    "$BUILD_ROOT/libdatachannel-sim-x64.a"

# --- macOS ---
merge_libs macos-arm64 "$BUILD_ROOT/libdatachannel-macos-arm64.a"
merge_libs macos-x64   "$BUILD_ROOT/libdatachannel-macos-x64.a"

echo "=== Creating fat binaries ==="

# iOS simulator: arm64 + x86_64
lipo -create \
    "$BUILD_ROOT/libdatachannel-sim-arm64.a" \
    "$BUILD_ROOT/libdatachannel-sim-x64.a" \
    -output "$BUILD_ROOT/libdatachannel-sim.a"

# macOS: arm64 + x86_64
lipo -create \
    "$BUILD_ROOT/libdatachannel-macos-arm64.a" \
    "$BUILD_ROOT/libdatachannel-macos-x64.a" \
    -output "$BUILD_ROOT/libdatachannel-macos.a"

# Rename to uniform libdatachannel.a so xcframework slices are consistent
STAGE="$BUILD_ROOT/stage"
rm -rf "$STAGE"
for src in "$BUILD_ROOT/libdatachannel-ios-arm64.a" \
           "$BUILD_ROOT/libdatachannel-sim.a" \
           "$BUILD_ROOT/libdatachannel-macos.a"; do
    name=$(basename "$src" .a)
    mkdir -p "$STAGE/$name"
    cp "$src" "$STAGE/$name/libdatachannel.a"
done

echo "=== Preparing headers ==="
HEADERS_DIR="$BUILD_ROOT/headers"
rm -rf "$HEADERS_DIR"
mkdir -p "$HEADERS_DIR"
cp "$ROOT_DIR/include/rtc/rtc.h" "$HEADERS_DIR/"
cp "$ROOT_DIR/include/rtc/version.h" "$HEADERS_DIR/"

echo "=== Creating XCFramework ==="
rm -rf "$OUTPUT_DIR/libdatachannel.xcframework"
xcodebuild -create-xcframework \
    -library "$STAGE/libdatachannel-ios-arm64/libdatachannel.a" -headers "$HEADERS_DIR" \
    -library "$STAGE/libdatachannel-sim/libdatachannel.a"       -headers "$HEADERS_DIR" \
    -library "$STAGE/libdatachannel-macos/libdatachannel.a"     -headers "$HEADERS_DIR" \
    -output "$OUTPUT_DIR/libdatachannel.xcframework"

# Add module.modulemap to each slice
for slice in "$OUTPUT_DIR/libdatachannel.xcframework"/*/; do
    [ -d "$slice/Headers" ] || continue
    mkdir -p "$slice/Modules"
    cat > "$slice/Modules/module.modulemap" <<'EOF'
module libdatachannel {
    header "../Headers/rtc.h"
    export *
}
EOF
done

echo "=== Done: $OUTPUT_DIR/libdatachannel.xcframework ==="
