# SentryObjC Build Process

How `SentryObjC-Static.xcframework` and `SentryObjC-Dynamic.xcframework` are built and distributed. For the wrapper architecture itself, see [SENTRY-OBJC.md](SENTRY-OBJC.md).

## Why a dedicated pipeline?

The main Sentry SDK xcframeworks (Sentry-Dynamic, Sentry-Static, SentrySwiftUI) are built via the generic `build-xcframework-slice.sh` → `assemble-xcframework.sh` pipeline, which archives an Xcode project scheme and produces `.framework` bundles.

SentryObjC cannot use this pipeline because:

1. **SPM dependency chain.** The SentryObjC SPM product resolves as `SentryObjC → SentryObjCCompat → SentryObjCInternal`, where `SentryObjCInternal` compiles the full SDK from source. The Xcode project scheme builds `SentryObjC.framework` as a thin shell with `SentryObjCCompat.framework` as an embedded dependency, but does not re-export its symbols — so consumers get linker errors for all `SentryObjC*` wrapper classes.

2. **Single-binary requirement.** The design goal ([SENTRY-OBJC.md §Design Goals](SENTRY-OBJC.md#design-goals)) is a single library to link. Building via SPM and merging all object files into one static library achieves this without framework embedding or re-export flags.

## Build flow

### Local

```
make build-xcframework-sentryobjc-static SDKS=iphonesimulator
```

Calls `scripts/build-xcframework-sentryobjc.sh`, which loops over SDKs sequentially:

```
for each SDK:
  scripts/build-static-library-sentryobjc.sh --sdk <sdk>
    → xcodebuild archive (via SPM, resolves full dependency chain)
    → find .o files in xcarchive
    → libtool -static → libSentryObjC.a

scripts/assemble-xcframework-sentryobjc.sh
  → xcodebuild -create-xcframework -library ... -headers ...
  → SentryObjC-Static.xcframework
```

### CI (release workflow)

Same scripts, but the per-SDK builds run as **parallel GitHub Actions jobs**:

```
build-sentryobjc-slices (parallel per SDK)
  ├─ iphoneos:        build-static-library-sentryobjc.sh → upload libSentryObjC.a
  │                   build-dynamic-framework-sentryobjc.sh → upload SentryObjC.framework + dSYM
  ├─ iphonesimulator: (same)
  ├─ macosx:          (same)
  ├─ maccatalyst:     (same)
  └─ ...

assemble-sentryobjc-static-xcframework (single job, depends on all slices)
  → download all libSentryObjC.a artifacts
  → assemble-xcframework-sentryobjc.sh
  → validate + sign + compress
  → upload SentryObjC-Static.xcframework.zip

assemble-sentryobjc-dynamic-xcframework (single job, depends on all slices)
  → download all SentryObjC.framework artifacts
  → assemble-xcframework-sentryobjc.sh
  → validate + sign + compress
  → upload SentryObjC-Dynamic.xcframework.zip
```

## Scripts

| Script                                  | Purpose                                                                                  |
| --------------------------------------- | ---------------------------------------------------------------------------------------- |
| `build-static-library-sentryobjc.sh`    | Build one SDK slice: SPM archive → collect `.o` → `libtool -static` → `libSentryObjC.a`  |
| `build-dynamic-framework-sentryobjc.sh` | Build one SDK slice: `.a` → `swiftc -emit-library` → `.framework` bundle                 |
| `assemble-xcframework-sentryobjc.sh`    | Assemble xcframework from per-SDK static libraries or framework bundles + public headers |
| `build-xcframework-sentryobjc.sh`       | Local orchestrator: loops over SDKs, calls the above scripts sequentially                |

## Workflows

| Workflow                                      | Purpose                                                                                            |
| --------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| `build-sentryobjc-slices.yml`                 | CI: builds static + dynamic framework per SDK in parallel                                          |
| `assemble-sentryobjc-static-xcframework.yml`  | CI: downloads static slices, runs `assemble-xcframework-sentryobjc.sh`, validates, signs, uploads  |
| `assemble-sentryobjc-dynamic-xcframework.yml` | CI: downloads pre-built dynamic framework slices, assembles xcframework, validates, signs, uploads |

## How it works

1. **SPM archive.** `xcodebuild archive -workspace <repo-root> -scheme SentryObjC` builds the full SPM dependency chain. Because SPM library products without an explicit type archive as per-target Mach-O object files (not frameworks), the archive contains `.o` files under `Products/`.

2. **Object merging.** `libtool -static` combines all `.o` files from SentryObjC, SentryObjCCompat, and SentryObjCInternal into a single `libSentryObjC.a`. This is why all wrapper class symbols (`SentryObjCSDK`, `SentryObjCBreadcrumb`, etc.) end up in one binary.

3. **Static XCFramework assembly.** `xcodebuild -create-xcframework` takes the per-SDK `.a` files and the public headers from `Sources/SentryObjC/Public/` to produce `SentryObjC-Static.xcframework`.

4. **Dynamic re-linking.** `swiftc -emit-library -force_load` re-links each per-SDK `libSentryObjC.a` as a dynamic library. The result is packaged as a `.framework` bundle with headers, modulemap, and Info.plist.

5. **Dynamic XCFramework assembly.** `xcodebuild -create-xcframework` takes the per-SDK `.framework` bundles to produce `SentryObjC-Dynamic.xcframework`.

## Makefile targets

| Target                                          | Description                                                              |
| ----------------------------------------------- | ------------------------------------------------------------------------ |
| `build-xcframework-sentryobjc-static SDKS=...`  | Build static xcframework via SPM pipeline                                |
| `build-xcframework-sentryobjc-dynamic SDKS=...` | Build dynamic xcframework (static slices → re-link as dylibs → assemble) |

## Relationship to the generic pipeline

The generic pipeline (`generate_release_matrix.sh` → `build-xcframework-variant-slices.yml` → `assemble-xcframework-variant.yml`) handles Sentry, SentrySwiftUI, and Sentry-WithoutUIKitOrAppKit. SentryObjC is **not** in the generic matrix — it has its own parallel jobs in `release.yml` that run alongside the generic variants.

The release artifact naming follows the same convention (`xcframework-${{sha}}-sentryobjc-static`, `xcframework-${{sha}}-sentryobjc-dynamic`) so the `job_release` step picks it up via the `xcframework-${{sha}}-*` glob pattern.
