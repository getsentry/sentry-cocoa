# Why `@objc(ClassName)` Is Required for Stable ObjC Runtime Names

## Summary

Swift classes that inherit from `NSObject` and use `@objcMembers` are visible to Objective-C, but their **ObjC runtime class name is mangled** unless an explicit `@objc(ClassName)` annotation is added at the class level. This means hand-written ObjC headers (`@interface ClassName : NSObject`) cannot reference these classes at link time without the annotation.

## The Problem

When writing a pure-ObjC wrapper SDK (SentryObjC) that exposes Swift classes via hand-written ObjC headers, the headers declare:

```objc
@interface SentryReplayOptions : NSObject
@property (nonatomic) float sessionSampleRate;
// ...
@end
```

This compiles to a reference to the ObjC symbol `_OBJC_CLASS_$_SentryReplayOptions`. If the underlying Swift class doesn't register with that exact name, the linker fails (static linking) or the runtime crashes (dynamic lookup).

## Proof: `@objcMembers` Uses Mangled Names

### Setup

```bash
mkdir -p /tmp/objc-name-test/Sources/Lib
```

**`/tmp/objc-name-test/Package.swift`**:

```swift
// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "Test",
    targets: [.target(name: "Lib", path: "Sources/Lib")]
)
```

**`/tmp/objc-name-test/Sources/Lib/Lib.swift`**:

```swift
import Foundation

// Case 1: @objcMembers WITHOUT explicit @objc(Name) on the class
@objcMembers
public class SentryReplayOptions: NSObject {
    public var sessionSampleRate: Float = 0.0
}

// Case 2: WITH explicit @objc(Name)
@objc(SentryFeedback)
@objcMembers
public class SentryFeedback: NSObject {
    public var message: String = ""
}
```

### Generate the ObjC header

```bash
cd /tmp/objc-name-test
xcrun swiftc \
    -emit-objc-header \
    -emit-objc-header-path out.h \
    Sources/Lib/Lib.swift \
    -module-name Lib \
    -sdk $(xcrun --show-sdk-path)
```

### Inspect the output

```bash
grep 'SWIFT_CLASS\|@interface' out.h | grep -v '#'
```

**Output**:

```
SWIFT_CLASS("_TtC3Lib20SentryReplayOptions")
@interface SentryReplayOptions : NSObject
SWIFT_CLASS_NAMED("SentryFeedback")
@interface SentryFeedback : NSObject
```

### What this means

| Class                 | Annotation                               | Generated Macro                                | ObjC Runtime Name                         |
| --------------------- | ---------------------------------------- | ---------------------------------------------- | ----------------------------------------- |
| `SentryReplayOptions` | `@objcMembers` only                      | `SWIFT_CLASS("_TtC3Lib20SentryReplayOptions")` | `_TtC3Lib20SentryReplayOptions` (mangled) |
| `SentryFeedback`      | `@objc(SentryFeedback)` + `@objcMembers` | `SWIFT_CLASS_NAMED("SentryFeedback")`          | `SentryFeedback` (stable)                 |

- **`SWIFT_CLASS("_TtC3Lib20SentryReplayOptions")`** expands to `__attribute__((objc_runtime_name("_TtC3Lib20SentryReplayOptions")))`. The ObjC runtime registers the class under the mangled name. The symbol `_OBJC_CLASS_$_SentryReplayOptions` does **not** exist.

- **`SWIFT_CLASS_NAMED("SentryFeedback")`** uses the plain name. The symbol `_OBJC_CLASS_$_SentryFeedback` **does** exist.

### The mangled name includes the module name

The format is `_TtC<module_len><module><class_len><class>`:

- `_TtC3Lib20SentryReplayOptions` — module `Lib` (length 3), class `SentryReplayOptions` (length 20)
- In the real SDK: `_TtC6Sentry20SentryReplayOptions` (module `Sentry`, length 6)
- Via SPM: `_TtC11SentrySwift20SentryReplayOptions` (module `SentrySwift`, length 11)

**The mangled name changes depending on the module name.** SPM and Xcode use different module names for the same target, so the mangled name differs between build systems.

## Link-Time Failure Demonstration

### Consumer ObjC code

```objc
// consumer.m
#import <Foundation/Foundation.h>

// Hand-written header (what SentryObjC would ship)
@interface SentryReplayOptions : NSObject
@property (nonatomic) float sessionSampleRate;
@end

int main(void) {
    SentryReplayOptions *opts = [[SentryReplayOptions alloc] init];
    opts.sessionSampleRate = 0.5;
    return 0;
}
```

### What happens at link time

The compiler generates:

```
objc_msgSend(objc_getClass("SentryReplayOptions"), @selector(alloc))
```

At link time (static) or runtime (dynamic), `objc_getClass("SentryReplayOptions")` returns `nil` because the class is registered as `_TtC6Sentry20SentryReplayOptions`. The `alloc` message is sent to `nil`, and the program silently does nothing (or crashes on subsequent property access).

## Solutions

### Option A: Add `@objc(ClassName)` to the original Swift class

```swift
@objc(SentryReplayOptions)  // forces stable ObjC name
@objcMembers
public class SentryReplayOptions: NSObject { ... }
```

**Pro**: Simple, one line per class.
**Con**: Modifies existing SDK source files.

### Option B: Create a wrapper class in a compat layer

```swift
// In a separate SentryObjCCompat target
@_implementationOnly import Sentry

@objc(SentryReplayOptions)
public class SentryReplayOptionsCompat: NSObject {
    let wrapped: Sentry.SentryReplayOptions

    init(wrapping original: Sentry.SentryReplayOptions) {
        self.wrapped = original
        super.init()
    }

    @objc public var sessionSampleRate: Float {
        get { Float(wrapped.sessionSampleRate) }
        set { wrapped.sessionSampleRate = Double(newValue) }
    }
}
```

**Pro**: Zero modifications to existing SDK files. Clean separation of concerns.
**Con**: More boilerplate. Every property/method must be delegated.

No collision occurs because the original class uses the mangled name (`_TtC6Sentry20SentryReplayOptions`) while the wrapper claims the plain name (`SentryReplayOptions`). Two distinct ObjC classes, no conflict.

## Affected Classes in sentry-cocoa

Classes with `@objcMembers` but no class-level `@objc(Name)` (mangled ObjC names):

| Swift Class                 | File                                                                 | Mangled ObjC Name                        |
| --------------------------- | -------------------------------------------------------------------- | ---------------------------------------- |
| `SentryReplayOptions`       | `Sources/Swift/Integrations/SessionReplay/SentryReplayOptions.swift` | `_TtC6Sentry20SentryReplayOptions`       |
| `SentryFeedback`            | `Sources/Swift/Integrations/UserFeedback/SentryFeedback.swift`       | `_TtC6Sentry15SentryFeedback`            |
| `SentryAttribute`           | `Sources/Swift/Protocol/SentryAttribute.swift`                       | `_TtC6Sentry15SentryAttribute`           |
| `SentryLog`                 | `Sources/Swift/Protocol/SentryLog.swift`                             | `_TtC6Sentry9SentryLog`                  |
| `SentryExperimentalOptions` | `Sources/Swift/SentryExperimentalOptions.swift`                      | `_TtC6Sentry26SentryExperimentalOptions` |

Classes that already have stable ObjC names (no wrapper needed):

| Swift Class            | Annotation                 | Stable ObjC Name       |
| ---------------------- | -------------------------- | ---------------------- |
| `SentrySDK`            | `@objc public final class` | `SentrySDK`            |
| `Options`              | `@objc(SentryOptions)`     | `SentryOptions`        |
| `SentryLogger`         | `@objc public final class` | `SentryLogger`         |
| `SentryEnvelope`       | `@objc public final class` | `SentryEnvelope`       |
| `SentryEnvelopeHeader` | `@objc public final class` | `SentryEnvelopeHeader` |
| `SentryEnvelopeItem`   | `@objc public final class` | `SentryEnvelopeItem`   |
