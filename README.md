# libdatachannel (xpoint fork)

Fork of [paullouisageneau/libdatachannel](https://github.com/paullouisageneau/libdatachannel) — a lightweight C/C++ WebRTC Data Channels library.

This fork builds **DataChannel-only** static libraries for Apple platforms (no media, no WebSocket) and publishes them as:

- **XCFramework** — `libdatachannel.xcframework` attached to GitHub Releases
- **KMP (Kotlin Multiplatform)** — `tech.xpoint:libdatachannel-kmp` published to S3 Maven repository

## Build configuration

CMake flags: `NO_MEDIA=ON`, `NO_WEBSOCKET=ON`, `NO_TESTS=ON`, `NO_EXAMPLES=ON`, `USE_MBEDTLS=ON`

Static libraries bundled per target: libdatachannel, libjuice, libusrsctp, libmbedtls, libmbedcrypto, libmbedx509.

## Targets

| Target | XCFramework | KMP |
|--------|:-----------:|:---:|
| iOS arm64 | + | + |
| iOS Simulator arm64 | + | + |
| iOS Simulator x86_64 | + | + |
| macOS arm64 | + | + |
| macOS x86_64 | + | + |

## Build & publish

Triggered by pushing a `v*-darwin` tag or manually via `workflow_dispatch`.

The CI workflow runs on `macos-latest` and does:

1. Build mbedTLS (`scripts/build-mbedtls.sh`)
2. Build libdatachannel (`scripts/build-libdatachannel.sh`)
3. Package XCFramework (`scripts/package-xcframework.sh`)
4. Package KMP .a files (`scripts/package-kmp.sh`)
5. Publish KMP to Maven (`cd kmp && ./gradlew publish`)
6. Upload XCFramework to GitHub Release

## Usage

### KMP (Kotlin Multiplatform)

```kotlin
// settings.gradle.kts
repositories {
    maven("s3://downloads.xpoint.tech/nexus/")
}

// build.gradle.kts
dependencies {
    implementation("tech.xpoint:libdatachannel-kmp:0.24.1")
}
```

### XCFramework (CocoaPods / manual)

Download `libdatachannel.xcframework.zip` from [Releases](https://github.com/alexshawnee/libdatachannel/releases).

## Upstream

Based on [libdatachannel](https://github.com/paullouisageneau/libdatachannel) by Paul-Louis Ageneau. Licensed under [MPL 2.0](LICENSE).
