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

## The DEBUG Guard in SentryProfiler +load

The `SentryProfiler` `+load` method contains a compile-time guard that fundamentally changes its behavior:

```objc
+ (void)load
{
#if defined(SENTRY_TEST) || defined(SENTRY_TEST_CI) || defined(DEBUG)
    if (NSProcessInfo.processInfo.environment[@"--io.sentry.ui-test.test-name"] == nil) {
        return;  // Early return: launch profiling is skipped entirely
    }
    // ... wipe-data handling for UI tests ...
#endif

    sentry_startLaunchProfile();
}
```

When `DEBUG` is defined and the `--io.sentry.ui-test.test-name` environment variable is not set, the method returns early without calling `sentry_startLaunchProfile()`.

The practical consequence is that any code path triggered by `sentry_startLaunchProfile()` will only execute in release-mode builds (or in debug builds with the UI test env var). This includes file system access for launch profile configuration.

### Scope of the DEBUG guard

The intent of this guard is to prevent launch profiling from running during the SDK's own unit tests while still allowing it during UI tests (identified by the env var). The `SENTRY_TEST` and `SENTRY_TEST_CI` macros are scoped to the SDK's test targets and correctly limit the guard to the SDK's own test suite.

However, `DEBUG` is not Sentry-specific. SPM passes `-DDEBUG` to all targets (including dependencies) when building in debug configuration. This means the guard activates for **every consumer app** that builds `SentrySPM` from source in a debug scheme — not just the SDK's own tests. In practice, launch profiling is silently disabled for all SPM users during development:

| Scenario                                                              | Launch profiling runs? |
| --------------------------------------------------------------------- | ---------------------- |
| Pre-built XCFramework (`Sentry` product), any build config            | Yes                    |
| `SentrySPM`, consumer debug build (default)                           | **No**                 |
| `SentrySPM`, consumer release build / archive                         | Yes                    |
| `SentrySPM`, debug build with `--io.sentry.ui-test.test-name` env var | Yes                    |

This is likely unintended. The guard should probably use only `SENTRY_TEST || SENTRY_TEST_CI` (without `DEBUG`) to scope it to the SDK's own test runs, or use a different mechanism to distinguish "Sentry's own test builds" from "a customer's debug build."

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

Disassemble the `+load` method to verify which code paths are included:

```bash
$ objdump -d --disassemble-symbols="+[SentryProfiler load]" .build/debug/cli-with-spm  

.build/debug/cli-with-spm:      file format mach-o arm64

Disassembly of section __TEXT,__text:

00000001009e2ec0 <+[SentryProfiler load]>:
1009e2ec0: d10203ff     sub     sp, sp, #0x80
1009e2ec4: a9077bfd     stp     x29, x30, [sp, #0x70]
1009e2ec8: 9101c3fd     add     x29, sp, #0x70
1009e2ecc: aa0103e8     mov     x8, x1
1009e2ed0: f81f83a0     stur    x0, [x29, #-0x8]
1009e2ed4: f81f03a8     stur    x8, [x29, #-0x10]
1009e2ed8: b0002d88     adrp    x8, 0x100f93000 <_writev+0x100f93000>
1009e2edc: f944a100     ldr     x0, [x8, #0x940]
1009e2ee0: 940d2150     bl      0x100d2b420 <_objc_msgSend$processInfo>
1009e2ee4: aa1d03fd     mov     x29, x29
1009e2ee8: 940d04aa     bl      0x100d24190 <_writev+0x100d24190>
1009e2eec: f9401fe1     ldr     x1, [sp, #0x38]
1009e2ef0: f81d03a0     stur    x0, [x29, #-0x30]
1009e2ef4: 940d12eb     bl      0x100d27aa0 <_objc_msgSend$environment>
1009e2ef8: f81d83a0     stur    x0, [x29, #-0x28]
1009e2efc: 14000001     b       0x1009e2f00 <+[SentryProfiler load]+0x40>
1009e2f00: f85d83a0     ldur    x0, [x29, #-0x28]
1009e2f04: aa1d03fd     mov     x29, x29
1009e2f08: 940d04a2     bl      0x100d24190 <_writev+0x100d24190>
1009e2f0c: f9401fe1     ldr     x1, [sp, #0x38]
...
```

In a **release** build (no `DEBUG`), the method compiles down to a single branch instruction:

```bash
$ objdump -d --disassemble-symbols="+[SentryProfiler load]" .build/release/cli-with-spm

.build/release/cli-with-spm:    file format mach-o arm64

Disassembly of section __TEXT,__text:

00000001004cebcc <+[SentryProfiler load]>:
1004cebcc: 17ff481e     b       0x1004a0c44 <_sentry_startLaunchProfile>
```

In a **debug** build (with `DEBUG`), the method includes the full environment variable lookup and early return logic, producing ~50 instructions.

## Implications for Issue Investigation

When investigating bugs related to app launch behavior, keep in mind:

1. The pre-built XCFramework (`Sentry` product) always runs launch profiling code in `+load`. The source-built SPM target (`SentrySPM` product) only does so in release builds.
2. Reproducing launch-related issues with the SPM target requires building in release mode (`swift build -c release`) to match the behavior of the pre-built binary.
3. The `+load` methods run before `SentrySDK.start`, so `SentryOptions.debug` and `SentryOptions.diagnosticLevel` have no effect on log output from these early code paths. Error messages printed during `+load` cannot be suppressed by SDK configuration.
4. The `DYLD_PRINT_INITIALIZERS` environment variable shows C/C++ initializers but does not cover Objective-C `+load` calls. Use `OBJC_PRINT_LOAD_METHODS` instead.
