# Coding Conventions

**Analysis Date:** 2026-03-19

## Naming Patterns

**Files:**

- Swift files use PascalCase with descriptive names: `SentryClient.swift`, `SentryHubTests.swift`
- Objective-C files: `SentrySDK.m`, `SentryHub.m`
- Test files follow pattern: `<SourceClassName>Tests.swift`
- Mock/Fixture classes in SentryTestUtils use `Test<Name>` prefix: `TestTransport.swift`, `TestHub.swift`, `TestFileManager.swift`

**Functions:**

- Swift: `camelCase` following Swift API Design Guidelines
- Test methods: `test<Function>_when<Condition>_should<Expected>()` pattern
  - Example: `testCapture_whenEmptyBuffer_shouldDoNothing()`
  - Alternative: `testCaptureMessage()`, `testClientIsEnabled()`
- Objective-C: Messaging style, e.g., `-[SentryHub captureMessage:]`

**Variables and Properties:**

- Local variables: `camelCase` (e.g., `messageAsString`, `fileManager`)
- Instance properties: `camelCase`
- Private properties: `camelCase` (use `private` keyword)
- Constants (module-level): `camelCase` (e.g., `sentryAutoTransactionMaxDuration`)
- Test fixtures: Lowercase descriptive names: `fixture`, `sut`, `message`, `event`

**Types:**

- Classes, protocols, structs, enums: `PascalCase`
- Example: `SentryClient`, `Options`, `Transport`, `SentrySession`

**Test Class Members:**

- Fixture class (nested `private class Fixture`): Holds test setup and dependencies
- `sut` (System Under Test): Subject being tested in a test method
- Test methods are `func` declarations (not private) at class scope

## Code Style

**Formatting:**

- SwiftLint configuration: `.swiftlint.yml` enforces style rules
- Line length: 1000 character limit (configured in `.swiftlint.yml`)
- Indentation: 4 spaces (Clang format: `IndentWidth: 4`)
- Brace style: WebKit style (from `.clang-format`)
- C/C++ code: Formatted per `.clang-format` (BasedOnStyle: WebKit, ColumnLimit: 100)

**Linting Rules:**

- Enabled via `.swiftlint.yml`: `only_rules` list includes 88+ rules
- Key rules:
  - `force_unwrapping`: Error on force unwrap `!`
  - `force_cast`: Error on force cast `as!`
  - `force_try`: Error on force try `try!`
  - `class_delegate_protocol`: Enforce delegate protocol design
  - `missing_docs`: Error on public API without documentation
  - `cyclomatic_complexity`: Limit function/method complexity
  - `file_length`: Limit file size
  - `function_body_length`: Limit function size
  - `type_body_length`: Limit type size
  - `identifier_name`: 1-50 character limit (warning at 50, error at 50)
  - `type_name`: 2-60 character limit
  - Custom rule `no_try_optional_in_tests`: Error on `try?` in test files (use `try XCTUnwrap(...)` instead)

**Doc Comments:**

- Public API requires documentation (enforced by `missing_docs` rule)
- Headerdocs format: Three slashes for Swift doc comments
- Objective-C headers: Documented with standard headerdoc format

## Import Organization

**Order:**

1. Framework imports: `import Foundation`, `import UIKit`
2. Module imports: `import Sentry`
3. Test utilities: `import SentryTestUtils`
4. SPI imports: `@_spi(Private) import Sentry`
5. XCTest (in test files): `import XCTest`

**Path Aliases:**

- Not used; full module paths used throughout
- Example: `SentrySDKInternal.currentHub()`, `SentryDependencyContainer.sharedInstance()`

**Test Imports (pattern in test files):**

```swift
@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest
```

## Error Handling

**Patterns:**

- `do/catch` blocks wrap operations that can throw
- Log errors via `SentrySDKLog.error()` or `SentrySDKLog.warning()` in public entry points
- Never let SDK crash the host app—wrap entry points in error handling
- Prefer optional returns or `Result<T, Error>` for internal APIs
- Example from `Options.swift`:
  ```swift
  do {
      self.parsedDsn = try SentryDsn(string: dsn)
  } catch {
      self.parsedDsn = nil
      self.dsn = nil
      SentrySDKLog.error("Could not parse the DSN: \(error)")
  }
  ```

## Logging

**Framework:** `SentrySDKLog` or `SentryLog`

- Logging module: `Sources/Swift/` provides `SentrySDKLog`
- Called with `.error()`, `.warning()`, `.debug()`, `.info()` methods
- Only used in debug paths and error handling

**Patterns:**

- Log errors during DSN parsing: `SentrySDKLog.error("Could not parse the DSN: \(error)")`
- Log configuration warnings: `SentrySDKLog.warning("...")`
- No `print()` or `NSLog()` in production code—use `SentrySDKLog`

## Comments

**When to Comment:**

- Complex logic, non-obvious algorithms
- Important gotchas or assumptions
- Signal handler code restrictions (async-signal-safe limitations in `SentryCrash/`)
- Thread safety considerations

**JSDoc/TSDoc:**

- Swift uses standard documentation comments: `///`
- Objective-C uses standard Xcode headerdoc format
- Public API must be documented (enforced by linter)
- Comments precede declarations

## Function Design

**Size:**

- Functions limited by `function_body_length` rule (configured in `.swiftlint.yml`)
- Large test files (like `SentryClientTests.swift`) use `swiftlint:disable file_length` comment at top

**Parameters:**

- Named parameters for clarity
- Use trailing closures for callback patterns
- Capture lists required when capturing `self`: `[weak self]` with `guard let self` or `guard let self =`

**Return Values:**

- Explicit return type declarations
- Prefer optional returns over throwing for internal APIs
- Test methods return `Void` (no return value)

## Module Design

**Exports:**

- Public API marked with `@objc` for Objective-C compatibility
- Private SPI marked with `@_spi(Private)` for hybrid SDK consumption (React Native, Flutter, .NET, Unity)
- Internal classes marked `final` unless designed for subclassing
- Private properties/methods: use `private` keyword (prefer over `fileprivate`)

**Access Control:**

- Default to `internal` — only mark `public` what is part of SDK's public API
- `public` members require documentation
- Test types use private/internal nested classes for fixtures

**Barrel Files:**

- Not used—imports reference specific types

## Objective-C Specific

**Initialization:**

- Use `[[Class alloc] init]` pattern, never `[Class new]`
- Wrap headers: `NS_ASSUME_NONNULL_BEGIN` / `NS_ASSUME_NONNULL_END`
- Mark nullable parameters/properties explicitly with `nullable`

**Thread Safety (ObjC):**

- Core types (`SentryScope`, `SentryHub`, `SentryClient`) use `@synchronized(self)`
- Session replay uses `NSLock`
- File manager uses `pthread_mutex`

## Swift Specific

**Access Control:**

- Mark classes `final` unless explicitly designed for subclassing
- Use `private` over `fileprivate` unless sibling types need access
- Wrap entry points in `do/catch` to prevent crashes

**Closures:**

- Always use explicit capture lists: `[weak self]`
- Guard unwrap after capture: `guard let self else { return }`
- Alternative syntax: `guard let self = self` (earlier Swift style)

**Protocols:**

- Protocol-oriented design preferred for testability and composition
- Multiple protocol adoption with default extensions
- Generic constraints reduce init/method signatures
- Example pattern from codebase:
  ```swift
  protocol ItemProtocol { var id: String { get } }
  protocol StorageProtocol<Item> { associatedtype Item; func append(_ item: Item) }
  extension Enricher {
      func enrich<Item: ItemProtocol>(_ item: inout Item) { /* default */ }
  }
  extension Scope: Enricher {}
  ```

## Special Markers and Attributes

**@_spi(Private):**

- Marks APIs for hybrid SDK consumption only
- Must not appear in public headers
- Tests use `@_spi(Private) @testable import Sentry`

**@testable:**

- Enables test access to internal symbols
- Combined with `@_spi(Private)` in test files

**@objc:**

- All public API must be accessible from Objective-C
- Use `@objc(customName)` or `NS_SWIFT_NAME` for idiomatic naming

**SENTRY_NO_INIT:**

- Marker (macro) on types that should not be publicly instantiated

---

_Convention analysis: 2026-03-19_
