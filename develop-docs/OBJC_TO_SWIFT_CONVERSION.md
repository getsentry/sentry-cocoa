# Objective-C to Swift Conversion Guide

This document provides reusable instructions for coding agents to perform 1:1 conversions of individual Objective-C files to Swift in the Sentry Cocoa SDK.

## Prerequisites

- Read [SWIFT.md](./SWIFT.md) for Swift/ObjC interoperability patterns
- Read [AGENTS.md](../AGENTS.md) for project conventions, testing, and commit guidelines
- Ensure the target file has existing unit tests (required for verification)

## Conversion Process

### 1. Create the Swift File

- **Location**: Place the Swift file in `Sources/Swift/` mirroring the ObjC path structure
  - ObjC: `Sources/Sentry/Tools/SentryFoo.m` → Swift: `Sources/Swift/Tools/SentryFoo.swift`
- **Class visibility**: Use `@objc(ClassName)` and `public` for ObjC interop
- **Internal-only classes**: Add `@_spi(Private)` if the class is not part of the public API

### 2. Method Translation

| ObjC Pattern                                | Swift Equivalent                                           |
| ------------------------------------------- | ---------------------------------------------------------- |
| `- (ReturnType *)method:(ParamType *)param` | `public func method(_ param: ParamType) -> ReturnType`     |
| `- (Type)method:(NSError **)error`          | `func method(_ error: NSErrorPointer) -> Type`             |
| `- (Type)methodWithError:(NSError **)error` | `func method() throws -> Type` + `@objc(methodWithError:)` |
| `[self helperMethod:arg]`                   | `helperMethod(arg)`                                        |
| `NSString *`                                | `String`                                                   |
| `NSArray *`                                 | `[Type]` or `NSArray`                                      |
| `NSMutableArray`                            | `var array: [Type] = []`                                   |
| `id` / `NSObject *`                         | `Any` or specific type with `as?` cast                     |
| `nil`                                       | `nil`                                                      |
| `@""`                                       | `""`                                                       |

**NSErrorPointer**: Call with `var error: NSError?` and `&error`. Only set `error.pointee` when `error != nil` to avoid crashes.

### 3. Foundation Type Mappings

| ObjC Type                              | Swift Type                                     |
| -------------------------------------- | ---------------------------------------------- |
| `NSCompoundPredicateType`              | `NSCompoundPredicate.LogicalType`              |
| `NSCompoundPredicateType` (and/or/not) | `.and`, `.or`, `.not`                          |
| `NSPredicateOperatorType`              | `NSComparisonPredicate.Operator`               |
| `NSExpression.ExpressionType`          | `.constantValue`, `.aggregate`, `.conditional` |
| `NSExpression.trueExpression`          | `expression.\`true\`` (Swift keyword escape)   |
| `NSExpression.falseExpression`         | `expression.\`false\`` (Swift keyword escape)  |

### 4. C Typedefs and Low-Level Types

- **ObjC typedefs** (e.g., `SentryRAMBytes` for `mach_vm_size_t`): Swift can use the underlying type directly (e.g., `mach_vm_size_t`) to avoid `@_implementationOnly` visibility issues with C headers.
- **Keep typedef in ObjC**: Move the typedef to a shared header (e.g., `SentryProfilerDefines.h`) if ObjC consumers still need it. Swift does not need to import it.

### 5. Test Doubles (TestSentryFoo)

If the ObjC class has a test double in `SentryTestUtils/Sources/`:

1. **Convert the test double to Swift** alongside the main class.
2. **Override struct**: Use Swift types (e.g., `mach_vm_size_t` not `SentryRAMBytes`) in override properties.
3. **Convenience init**: Add `override init(param: Type = default)` so `TestSentryFoo()` works without arguments.
4. **Visibility**: Keep the test double internal (not `public`) so it can subclass `@_spi(Private)` types.
5. **Add unit tests** that use the test double to verify override and error-handling behavior. Use `test<Function>_when<Condition>_should<Expected>()` naming and Arrange-Act-Assert. Example: `testMemoryFootprint_whenErrorOverride_shouldSetErrorAndReturnZero`.

### 6. Swift-Specific Adaptations

- **Dead code removal**: ObjC may check `[predicate isKindOfClass:[NSExpression class]]` for `NSPredicate`—this is impossible (unrelated types). Remove or document as dead code.
- **Keyword conflicts**: ObjC properties `trueExpression`/`falseExpression` are imported as `true`/`false` in Swift. Use backticks: `` expression.`true` ``
- **Optional handling**: Use `guard let` for early returns, `if let` for optional binding
- **String formatting**: Use `"\(expr)"` or `"\(a) \(b)"` instead of `[NSString stringWithFormat:@"%@ %@", a, b]`
- **Collections**: Use `array.joined(separator: sep)` instead of `[array componentsJoinedByString:sep]`
- **Switch exhaustiveness**: Add `@unknown default` for future-proof enum handling

**Architecture-specific code**: Use `#if arch(arm64) || arch(arm)` for ARM-only APIs (e.g., `task_info` with `TASK_POWER_INFO_V2`). Tests for these methods need the same guard. Use `@objc(originalSelector:)` when the Swift name differs from the ObjC selector (e.g., `@objc(cpuUsageWithError:)` for `func cpuUsage() throws`).

### 7. SwiftLint Compliance

- Add `// swiftlint:disable cyclomatic_complexity` above functions with large switch statements (e.g., operator type mapping)
- Add `// swiftlint:disable missing_docs` at file level if the class has a doc comment but methods don't
- Or add `// swiftlint:disable:next cyclomatic_complexity` for a single function

### 8. Project File Updates

**Remove ObjC implementation from build:**

1. Remove the `.m` or `.mm` file from the Sources build phase in `Sentry.xcodeproj/project.pbxproj`
2. Remove the `.h` file from the Headers build phase
3. Remove both from the group (e.g., Tools group)
4. Remove the `PBXBuildFile` and `PBXFileReference` entries for the `.m`/`.mm` file

**Update imports:**

1. Remove `#import "SentryFoo.h"` from any ObjC files that use the class (e.g., `SentryCoreDataTracker.m`)
2. Remove `#import "SentryFoo.h"` from `Tests/SentryTests/SentryTests-Bridging-Header.h`
3. Remove from `SentryTestUtils/Headers/SentryTestUtils-ObjC-BridgingHeader.h` if present
4. The Swift-generated `Sentry-Swift.h` (via `SentrySwift.h`) provides the interface to ObjC

**Test target:**

- Add `@_spi(Private) @testable import Sentry` to test files that need to access the converted class
- Add `@_spi(Private) @testable import SentryTestUtils` when tests use a test double (e.g., `TestSentryFoo`)

### 9. Delete ObjC Files

- Delete the `.m` or `.mm` implementation file
- Delete the `.h` header file (the Swift-generated header replaces it)

## Verification Loop

Run these commands after conversion:

```bash
make build-macos
make format
make analyze
```

**Running tests**: Tests may live in different targets (e.g., `SentryProfilerTests` vs `SentryTests`). `make test-macos ONLY_TESTING=SentryFooTests` targets SentryTests. If tests are in another target, use:

```bash
xcodebuild -workspace Sentry.xcworkspace -scheme Sentry -only-testing:SentryProfilerTests/SentryFooTests -configuration Test -destination platform=macOS test
```

For full test suite:

```bash
make test-macos
```

## Common Pitfalls

1. **Duplicate interface definition**: If both the ObjC `.h` and Swift-generated header define the class, remove the explicit `#import "SentryFoo.h"` from ObjC files—`SentrySwift.h` provides the interface.

2. **Missing space in compound predicates**: For single subpredicates (e.g., NOT), the format is `"NOT " + expression`, not `"NOT" + expression`. Ensure a space between the type and the expression.

3. **Bridging header**: Test bridging headers must not import headers for classes now implemented in Swift; remove them to avoid duplicate symbol errors.

4. **Orphaned references**: After removing files from the project, remove `PBXFileReference` entries for deleted files to keep the project clean.

5. **Wrong test target**: If `make test-macos ONLY_TESTING=SentryFooTests` runs 0 tests, the tests may be in a different target (e.g., SentryProfilerTests). Use `xcodebuild -only-testing:SentryProfilerTests/SentryFooTests` with the correct target.

6. **Stale analyzer output**: After removing ObjC files, old static analyzer plist files (e.g., `analyzer/.../SentryFoo.plist`) may remain. These are harmless; the analyzer will regenerate as needed.

## Examples

### SentryPredicateDescriptor

Reference conversion: `SentryPredicateDescriptor.m` → `SentryPredicateDescriptor.swift`

- **Before**: ObjC class in `Sources/Sentry/`, header in `Sources/Sentry/include/`
- **After**: Swift class in `Sources/Swift/Tools/`, no separate header
- **Consumers**: `SentryCoreDataTracker.m` uses `SentryPredicateDescriptor`; gets interface from `SentrySwift.h`
- **Tests**: `SentryPredicateDescriptorTests.swift` uses `@_spi(Private) @testable import Sentry`

### SentrySystemWrapper

Reference conversion: `SentrySystemWrapper.mm` → `SentrySystemWrapper.swift`

- **Before**: ObjC class in `Sources/Sentry/`, header in `Sources/Sentry/include/`
- **After**: Swift class in `Sources/Swift/Helper/`, no separate header
- **C typedefs**: `SentryRAMBytes` moved to `SentryProfilerDefines.h`; Swift uses `mach_vm_size_t` directly
- **Test double**: `TestSentrySystemWrapper` in SentryTestUtils; override struct uses `mach_vm_size_t`
- **Architecture**: `cpuEnergyUsage()` only on `#if arch(arm64) || arch(arm)`; tests use same guard
- **Error methods**: `memoryFootprintBytes(_ error: NSErrorPointer)`; `cpuUsage() throws` with `@objc(cpuUsageWithError:)`
- **Test target**: Tests in `SentryProfilerTests`, not SentryTests—use `xcodebuild -only-testing:SentryProfilerTests/SentrySystemWrapperTests`
- **Test double tests**: Added `testMemoryFootprint_whenErrorOverride_shouldSetErrorAndReturnZero`, `testCPUUsage_whenUsageOverride_shouldReturnOverride`, etc.
