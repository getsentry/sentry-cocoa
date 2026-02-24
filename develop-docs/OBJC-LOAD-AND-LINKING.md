# Objective-C +load, Linking, and Build Configuration

> [!NOTE]
> This document has been co-written with Cursor's AI.
> It has been reviewed by human maintainers for quality standards and accuracy, but may contain errors.

This document explains how the Objective-C `+load` mechanism interacts with the SDK's different distribution formats, build configurations, and preprocessor guards. Understanding these interactions is essential for diagnosing issues that only appear in specific build or distribution scenarios.

## Background: Objective-C +load

The Objective-C runtime automatically calls `+load` on every class that implements it, as soon as the binary image containing that class is mapped into the process. This happens before `main()` runs and before any `SentrySDK.start` call. The runtime discovers classes with `+load` via the `__objc_nlclslist` (non-lazy class list) section in the Mach-O binary.

The SDK uses `+load` in several classes for early initialization:

| Class                                     | Purpose                                                       |
| ----------------------------------------- | ------------------------------------------------------------- |
| `SentryProfiler`                          | Starts app launch profiling via `sentry_startLaunchProfile()` |
| `SentryAppStartTrackerHelper`             | Captures runtime init timestamp and checks prewarm status     |
| `SentrySysctlObjC`                        | Captures runtime init timestamp for launch profiles           |
| `SentryCrashDefaultMachineContextWrapper` | Captures main thread ID                                       |

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

Defined in `Package.swift` as a chain of source targets (`SentryObjc` -> `SentrySwift` -> `_SentryPrivate` -> `SentryHeaders`):

```swift
products.append(.library(name: "SentrySPM", targets: ["SentryObjc"]))
```

This target is compiled from source by SPM as part of the consumer's build. The build configuration depends on how the consumer invokes `swift build`:

| Command                        | Configuration | `DEBUG` defined? |
| ------------------------------ | ------------- | ---------------- |
| `swift build`                  | Debug         | Yes              |
| `swift build -c release`       | Release       | No               |
| Xcode Debug scheme             | Debug         | Yes              |
| Xcode Release scheme / Archive | Release       | No               |

## The Test Guard in SentryProfiler +load

The `SentryProfiler` `+load` method contains a compile-time guard that limits launch profiling to the SDK's own UI tests:

```objc
+ (void)load
{
#if defined(SENTRY_TEST) || defined(SENTRY_TEST_CI)
    if (NSProcessInfo.processInfo.environment[@"--io.sentry.ui-test.test-name"] == nil) {
        return;  // Early return: launch profiling is skipped in unit tests
    }
    // ... wipe-data handling for UI tests ...
#endif

    sentry_startLaunchProfile();
}
```

The guard uses only `SENTRY_TEST` and `SENTRY_TEST_CI`, which are scoped to the SDK's test targets. When neither is defined (any consumer app), `sentry_startLaunchProfile()` always runs. This ensures launch profiling behaves consistently across debug and release builds for SPM consumers:

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
$ nm .build/release/cli-with-spm | grep "+\[.*load\]"
00000001004af708 t +[SentryCrashDefaultMachineContextWrapper load]
00000001004cebcc t +[SentryProfiler load]
00000001004db5f8 t +[SentrySysctlObjC load]
```

### Confirming +load execution at runtime

Set the `OBJC_PRINT_LOAD_METHODS` environment variable to trace which `+load` methods the runtime invokes:

```bash
$ OBJC_PRINT_LOAD_METHODS=YES .build/release/cli-with-spm 2>&1 | grep -i "sentry"
objc[10982]: LOAD: class 'SentryCrashDefaultMachineContextWrapper' scheduled for +load
objc[10982]: LOAD: class 'SentryProfiler' scheduled for +load
objc[10982]: LOAD: class 'SentrySysctlObjC' scheduled for +load
objc[10982]: LOAD: +[SentryCrashDefaultMachineContextWrapper load]
objc[10982]: LOAD: +[SentryProfiler load]
objc[10982]: LOAD: +[SentrySysctlObjC load]
```

### Comparing compiled code paths

In consumer builds (where `SENTRY_TEST` and `SENTRY_TEST_CI` are not defined), the guard block is compiled out entirely. Both debug and release builds compile to a single branch:

```bash
$ objdump -d --disassemble-symbols="+[SentryProfiler load]" .build/debug/cli-with-spm

.build/debug/cli-with-spm:      file format mach-o arm64

00000001009e2ec0 <+[SentryProfiler load]>:
1009e2ec0: 17ff481e     b       0x1004a0c44 <_sentry_startLaunchProfile>
```

In SDK test builds (SENTRY_TEST or SENTRY_TEST_CI defined), the method includes the environment variable lookup and early return logic.

## Implications for Issue Investigation

When investigating bugs related to app launch behavior, keep in mind:

1. Both the pre-built XCFramework (`Sentry` product) and the source-built SPM target (`SentrySPM` product) run launch profiling code in `+load` for all consumer builds (debug and release).
2. The `+load` methods run before `SentrySDK.start`, so `SentryOptions.debug` and `SentryOptions.diagnosticLevel` have no effect on log output from these early code paths. Error messages printed during `+load` cannot be suppressed by SDK configuration.
3. The `DYLD_PRINT_INITIALIZERS` environment variable shows C/C++ initializers but does not cover Objective-C `+load` calls. Use `OBJC_PRINT_LOAD_METHODS` instead.
