# SentrySDK.internal

`SentrySDK.internal` exposes SDK functionality used by hybrid SDKs such as React Native, Flutter, .NET, and Unity.

## Entry Points

The Swift entry point is `SentrySDK.internal`. Its extension is defined in [`Sources/Swift/Helper/SentrySDK+Internal.swift`](../Sources/Swift/Helper/SentrySDK+Internal.swift), and the root API type is defined in [`Sources/Swift/HybridSDK/SentryInternalApi.swift`](../Sources/Swift/HybridSDK/SentryInternalApi.swift).

Objective-C consumers use `SentryObjCSDK.internal`. Its declaration is in [`Sources/SentryObjC/Public/SentryObjCSDK.h`](../Sources/SentryObjC/Public/SentryObjCSDK.h), and its implementation is in [`Sources/SentryObjCCompat/SentryObjCSDK.swift`](../Sources/SentryObjCCompat/SentryObjCSDK.swift).

## Finding an API

Swift APIs are grouped by integration area in [`Sources/Swift/HybridSDK/`](../Sources/Swift/HybridSDK/). Start with `SentryInternalApi.swift` to find the relevant sub-API, then open the corresponding `SentryInternal*Api.swift` file for its implementation and documentation.

Each Swift API exposed to Objective-C has two matching files:

- `Sources/SentryObjC/Public/SentryObjCInternal*Api.h` defines the Objective-C interface.
- `Sources/SentryObjCCompat/SentryObjCInternal*Api.swift` delegates to the Swift API.

Keep the Swift API, Objective-C declaration, and Objective-C wrapper aligned when changing an API used by Objective-C hybrid SDKs.

## Architecture

```text
SentrySDK.internal
  -> SentryInternalApi
    -> SentryInternal*Api
      -> SDK internals and dependency providers

SentryObjCSDK.internal
  -> SentryObjCInternalApi
    -> SentryObjCInternal*Api
      -> SentryInternal*Api
```

The Swift API types use dependency-provider protocols backed by `SentryDependencyContainer` when dependencies need to be isolated in tests. `SentrySDK.internal` is available before and after `SentrySDK.start()` and is reset when the SDK closes.

Platform-specific APIs must keep their Swift compilation guards, Objective-C availability macros, and wrapper guards aligned.

## Tests

- Swift unit and integration tests are in [`Tests/SentryTests/HybridSDK/`](../Tests/SentryTests/HybridSDK/).
- Objective-C wrapper tests are in [`Tests/SentryObjCTests/`](../Tests/SentryObjCTests/) and follow the `SentryObjCInternal*ApiTests` naming pattern.
