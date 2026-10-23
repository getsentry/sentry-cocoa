# Swift and Objective-C

Rules for the mixed-language SDK, and for converting a public type in `Sources/Sentry/Public` to Swift without breaking callers. SDK Swift belongs in `Sources/Swift`.

## Glossary

- **`Sentry`** — The framework users import. The Xcode target `Sentry` in `Sentry.xcodeproj` builds `Sentry.framework` from source.
- **`SentrySwift`** — SwiftPM target for `Sources/Swift`. Compiled into `Sentry`.
- **`SentryObjCInternal`** — SwiftPM target for the Objective-C and C implementation under `Sources/Sentry`.
- **`SentryHeaders`** — Public Objective-C headers in `Sources/Sentry/Public`. Umbrella: `Sentry.h` in `Sources/Resources/Sentry.modulemap`.
- **`_SentryPrivate`** — Private Objective-C headers for SDK Swift. List: `Sources/Sentry/include/SentryPrivate.h`. Users do not import this module.
- **`SentrySwift.h`** — Shim at `Sources/Sentry/include/SentrySwift.h`. Objective-C imports this to call Swift.
- **`SentryObjC`** — Separate Objective-C client API. Update a wrapper only when a converted type is mirrored. See [SENTRY-OBJC.md](./SENTRY-OBJC.md).

Depending on how you interact with building the SDK, it's likely that you'll typically only build `Sentry` from within the `.xcodeproj` file. The list above is mainly meant to help navigate the different moving parts of migrating Objective-C code to Swift.

## Rules

- Objective-C makes Swift code callable to itself with `#import "SentrySwift.h"`. This is a shim that forwards to the generated Swift header.
- Swift can call private (or rather, internal to the SDK) Objective-C with `internal import _SentryPrivate`, after the header is added to `SentryPrivate.h`. Use `internal import`. A plain import breaks prebuilt XCFrameworks with `no such module '_SentryPrivate'`.
- Headers in `SentryPrivate.h` cannot depend on public interfaces.
- A type from `_SentryPrivate` may be used in Swift code. However, it must not appear in a public signature. Convert private types before using them in public Swift signatures.
- A public `.h` referenced through `Sentry.h` must not contain code that uses a Swift type. Doing so will lead to Swift seeing a duplicate definition of the Swift type which breaks the import.
- `@objc` signatures in Swift cannot use generics, structs, Swift enums, tuples, or non-`@objc` protocols. Using these features is fine on internal Swift and on public API that is already Swift-only.
- This migration keeps `@objc` on converted public types and does not change the API they expose. Declare classes `open`. Do not use `final`. Nothing here is gated on `SDK_V10`.
- Members from a `+Private.h` that `.m` files call become `@_spi(Private) @objc public`. Leave public API unmarked. Hybrid SPI is described in [`Sources/AGENTS.md`](../Sources/AGENTS.md).
- Tests find `_SentryPrivate` through `HEADER_SEARCH_PATHS` in `Tests/Configuration/SentryTests.xcconfig`. Leave that path off `SentrySwiftUI`.

## Converting a public type

The examples below outline aspects of migrating an Objective-C class named `SentryUser`, with a Swift name of `User`. First, check that `SentryUser` is no longer referenced in any public Objective-C headers. If some headers still leverage the class you're migrating, those types must be converted first.

Internal headers that reference a converted type are not deleted to unblock the conversion. Instead, those headers name the Swift type as `id` through `SENTRY_SWIFT_MIGRATION_ID`, shown further down.

When naming your Swift class, you should keep the old names whenever possible. The Objective-C name stays on `@objc`, and the Swift name stays the one `NS_SWIFT_NAME` already declared. A new Swift-friendly name is allowed only when the old name still compiles, through `typealias`, `@objc`, or `NS_SWIFT_NAME`. New Swift classes should be `open` by default. Do not use `final`.

```objc
NS_SWIFT_NAME(User)
@interface SentryUser : NSObject
```

```swift
@objc(SentryUser)
open class User: NSObject {}
```

Delete the public header `Sources/Sentry/Public/SentryUser.h`. Both umbrella headers import that file, so delete the matching line from each one.

```objc
// Sources/Sentry/Public/Sentry.h
#    import <Sentry/SentryUser.h>
```

```objc
// Sources/Sentry/Public/SentryWithoutUIKit.h
#    import <SentryWithoutUIKit/SentryUser.h>
```

Members from `SentryUser+Private.h` that `.m` files call become `@_spi(Private) @objc public`:

```objc
- (instancetype)initWithDictionary:(NSDictionary *)dictionary;
```

```swift
@_spi(Private)
@objc
public init(dictionary: NSDictionary) {}
```

Internal headers that Swift can see must not name the Swift class. Move those declarations to a `+SwiftPrivate.h` header and type them with `SENTRY_SWIFT_MIGRATION_ID`, which is `id`. This declaration is in `Sources/Sentry/include/SentryHub.h`:

```objc
// Sources/Sentry/include/SentryHub.h
- (void)setUser:(SentryUser *_Nullable)user;
```

Move it to `Sources/Sentry/include/SentryHub+SwiftPrivate.h`:

```objc
// Sources/Sentry/include/SentryHub+SwiftPrivate.h
- (void)setUser:(SENTRY_SWIFT_MIGRATION_ID(SentryUser))user;
```

When the value comes back to Swift, cast it in one extension for that class. Use `as?`.

```swift
guard let user = scope.userObject as? User else { return }
```

`userObject` is in `Sources/Sentry/include/SentryScope+PrivateSwift.h`. After that property uses the macro, the cast above is how Swift reads it.

Run `make generate-public-api`. In `sdk_api.json` and `sdk_api_objc.json`, `User` keeps `objc_name` `SentryUser`. The diff should be that declaration moving from the Objective-C header to Swift, with no public members renamed or removed. Existing test plans still pass.

Build `SentryObjC` and `SentryObjCCompat`. When the type is mirrored, the wrapper delegates to it. Updating that wrapper is a side effect of the conversion, not a separate goal. Update an example project only when it imports the deleted header. The wrapper for `User` looks like this:

```swift
@objc(SentryObjCUser) public final class SentryObjCUser: NSObject {
    internal let wrapped: User

    @objc public var userId: String? {
        get { wrapped.userId }
        set { wrapped.userId = newValue }
    }
}
```

### Accepted exceptions

- Objective-C can no longer subclass a converted class, because Objective-C cannot subclass a Swift class. Swift subclassing still works because the class is `open`. `SentryCrashExceptionApplication` stays Objective-C so Objective-C apps can keep subclassing it.
- Public C functions and constants get Swift equivalents and are deprecated, so callers see a warning. Removing the deprecated C API is a follow-up. A plain type conversion has no changelog entry. Deprecating a C function or constant, or adding a renamed typealias, does.
- Block typedefs in `SentryDefines.h` get new Swift names. The old names stay as deprecated aliases. Both names must build under Xcode, SwiftPM, and CocoaPods.

### Out of scope

- `Sources/Sentry/include` and `Utils/SwiftConversion`. See [Internal conversions](#internal-conversions).
- Hybrid headers `PrivateSentrySDKOnly`, `PrivatesHeader`, `SentryAppStartMeasurement`, and `SentrySessionReplayHybridSDK`.
- Removing `@objc`, deleting the remaining public headers, or changing the `SentryObjC` product.
- Stripping `@objc` from types that are already Swift, including the V10 `SentrySDK` pattern.
- `SentryDefines.h` and `SentryProfilingConditionals.h`, which are macro-only.
- `SentryError.h` and `SentrySpanStatus.h`. They stay Objective-C while C functions take those enums.
- Internal classes that only need the `id` seam: `SentryHubInternal`, `SentryClientInternal`, `SentrySDKInternal`, `SentryTracer`, and `SentrySpanInternal`.

## Internal conversions

`make generate-swift-conversion-diagram` orders private headers in `Sources/Sentry/include` only. It skips headers whose names contain `+` and does not order `Sources/Sentry/Public`. A private type used in one of those headers has to become Swift before the header that exposes it, because `internal import` cannot put that type on a public signature.
