# Objective-C +load, Linking, and Build Configuration

> [!NOTE]
> This document has been co-written with Cursor's AI.
> It has been reviewed by human maintainers for quality standards and accuracy, but may contain errors.

This document explains how the Objective-C `+load` mechanism interacts with the SDK's different distribution formats, build configurations, and preprocessor guards. Understanding these interactions is essential for diagnosing issues that only appear in specific build or distribution scenarios.

## Background: Objective-C +load

The Objective-C runtime automatically calls `+load` on every class that implements it, as soon as the binary image containing that class is mapped into the process. This happens before `main()` runs and before any `SentrySDK.start` call. The runtime discovers classes with `+load` via the `__objc_nlclslist` (non-lazy class list) section in the Mach-O binary.

The SDK uses `+load` in several classes for early initialization:

| Class                                     | Purpose                                                                    |
| ----------------------------------------- | -------------------------------------------------------------------------- |
| `SentrySDKInternal`                       | Starts app launch profiling via `SentryLaunchProfiling.startLaunchProfile` |
| `SentryAppStartTrackerHelper`             | Captures runtime init timestamp and checks prewarm status                  |
| `SentrySysctlObjC`                        | Captures runtime init timestamp for launch profiles                        |
| `SentryCrashDefaultMachineContextWrapper` | Captures main thread ID                                                    |

Because `+load` runs before any SDK configuration, there is no way for the user to control or suppress it via `SentryOptions` or log level settings.

## SDK Distribution Formats

The SDK ships in two primary forms through SPM, each with different implications for `+load` behavior:

### Pre-built XCFramework (`Sentry` product)

Defined in `Package.swift` as a `.binaryTarget` pointing to a release asset:

```swift
.binaryTarget(
    name: "Sentry",
    url: "https://github.com/getsentry/sentry-cocoa/releases/download/X.Y.Z/Sentry.xcframework.zip",
    checksum: "..."
)
```

This XCFramework is compiled in **Release mode**. The preprocessor macros `DEBUG`, `SENTRY_TEST`, and `SENTRY_TEST_CI` are **not defined**. All `+load` methods execute their full code paths unconditionally.

### Source-built SPM (`SentrySPM` product)

Defined in `Package.swift` as a chain of source targets (`SentryObjCInternal` -> `SentrySwift` -> `_SentryPrivate` -> `SentryHeaders`):

```swift
products.append(.library(name: "SentrySPM", targets: ["SentryObjCInternal"]))
```

This target is compiled from source by SPM as part of the consumer's build. The build configuration depends on how the consumer invokes `swift build`:

| Command                        | Configuration | `DEBUG` defined? |
| ------------------------------ | ------------- | ---------------- |
| `swift build`                  | Debug         | Yes              |
| `swift build -c release`       | Release       | No               |
| Xcode Debug scheme             | Debug         | Yes              |
| Xcode Release scheme / Archive | Release       | No               |

## The Test Guard in SentrySDKInternal +load

`SentrySDKInternal` owns the launch profiling hook. Keeping the hook in the SDK entry-point object file ensures static links retain it when they link SDK entry points.

On profiling-supported platforms, its `+load` method contains a compile-time guard that skips automatic launch profiling in SDK unit tests:

```objc
+ (void)load
{
#if defined(SENTRY_TEST) || defined(SENTRY_TEST_CI) || defined(SENTRY_UI_TEST_SUPPORT)
    if (NSProcessInfo.processInfo.environment[@"--io.sentry.ui-test.test-name"] == nil) {
        return;  // Early return: launch profiling is skipped in unit tests
    }
    // ... wipe-data handling for UI tests ...
#endif

    [SentryLaunchProfiling startLaunchProfile];
}
```

The guard uses `SENTRY_TEST`, `SENTRY_TEST_CI`, and `SENTRY_UI_TEST_SUPPORT`. When none is defined, the hook calls `SentryLaunchProfiling.startLaunchProfile`, which reads the configuration persisted for this launch. This applies to both debug and release consumer builds:

| Scenario                                                             | Launch profiling runs? |
| -------------------------------------------------------------------- | ---------------------- |
| Pre-built XCFramework (`Sentry` product), any build config           | Yes                    |
| `SentrySPM`, consumer debug build (default)                          | Yes                    |
| `SentrySPM`, consumer release build / archive                        | Yes                    |
| `SentrySPM`, SDK unit tests (SENTRY_TEST or SENTRY_TEST_CI defined)  | No                     |
| `SentrySPM`, SDK UI tests (with `--io.sentry.ui-test.test-name` env) | Yes                    |

## Verifying +load Behavior

### Listing classes with +load

Use `nm` to find all classes that implement `+load`:

```bash
nm .build/release/cli-with-spm | grep '+\[.*load\]'
```

The output must include `+[SentrySDKInternal load]`.

### Confirming +load execution at runtime

Set the `OBJC_PRINT_LOAD_METHODS` environment variable to trace which `+load` methods the runtime invokes:

```bash
OBJC_PRINT_LOAD_METHODS=YES .build/release/cli-with-spm 2>&1 | grep -i 'sentry'
```

The runtime trace must include `+[SentrySDKInternal load]`.

### Inspecting compiled code paths

Inspect the SDK-owned hook with:

```bash
objdump -d --disassemble-symbols="+[SentrySDKInternal load]" .build/debug/cli-with-spm
```

Consumer builds compile out the test guard and call `SentryLaunchProfiling.startLaunchProfile` directly. SDK test builds include the environment lookup, early return, and UI-test wipe-data handling.

## Implications for Issue Investigation

When investigating bugs related to app launch behavior, keep in mind:

1. Both the pre-built XCFramework (`Sentry` product) and the source-built SPM target (`SentrySPM` product) run launch profiling code in `+load` for all consumer builds (debug and release).
2. The `+load` methods run before `SentrySDK.start`, so `SentryOptions.debug` and `SentryOptions.diagnosticLevel` have no effect on log output from these early code paths. Error messages printed during `+load` cannot be suppressed by SDK configuration.
3. The `DYLD_PRINT_INITIALIZERS` environment variable shows C/C++ initializers but does not cover Objective-C `+load` calls. Use `OBJC_PRINT_LOAD_METHODS` instead.
