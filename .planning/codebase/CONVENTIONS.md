# Coding Conventions

**Analysis Date:** 2026-02-13

## Naming Patterns

**Files:**

- Swift files: PascalCase (e.g., `SentryClient.swift`, `Options.swift`)
- Objective-C files: PascalCase with prefixes (e.g., `SentryTracer+Test.m`, `SentryCrashWrapper.swift`)
- Test files: `<SourceFile>Tests.swift` or `<SourceFile>Tests.m` (e.g., `SentryClientTests.swift`)
- Test utilities/mocks: `Test<Name>.swift` (e.g., `TestTransport`, `TestFileManager`)

**Functions/Methods:**

- Swift: camelCase with descriptive action verbs (e.g., `capture(event:)`, `getCurrentThreads()`)
- Objective-C: Objective-C standard with descriptive names (e.g., `setMeasurement:value:`)
- Test methods: `test<Function>_when<Condition>_should<Expected>()` per AGENTS.md
- Examples: `testCaptureMessage()`, `testInit_CallsDeleteOldEnvelopeItemsInvocations()`, `testAdd_whenMaxItemCountReached_shouldFlushImmediately()`

**Variables:**

- Local variables and properties: camelCase (e.g., `dsn`, `fileManager`, `transportAdapter`)
- Test fixture properties: camelCase with descriptive purpose (e.g., `dateProvider`, `debugImageProvider`, `threadInspector`)
- Constants: camelCase or CONSTANT_CASE depending on context (e.g., `defaultEnvironment`, `SentrySDKLog`)

**Types:**

- Classes/Structs: PascalCase (e.g., `SentryClient`, `Options`, `SentryTracer`)
- Protocols: PascalCase ending with "ing" when behavioral (e.g., `SentryThreadInspecting`)
- Enums: PascalCase (e.g., `SentryLevel`)
- Type aliases: PascalCase
- SwiftLint enforces max 60 characters for type names (error level)

## Code Style

**Formatting:**

- Swift: Automated via `make format-swift` using SwiftLint
- Objective-C/C/C++: Automated via `make format-clang` using clang-format
- Markdown/JSON/YAML: Formatted via `dprint` (invoked by pre-commit hooks)

**Line Length:**

- Swift: No hard limit enforced by SwiftLint (configured to 1000), but follows good practices for readability
- Code should remain readable; extremely long lines should be split logically

**Indentation:**

- 4 spaces for all languages (enforced by formatters)

**Linting:**

- Tool: SwiftLint for Swift code (configured in `.swiftlint.yml`)
- Config location: `/Users/itaybrenner/sentry/sentry-cocoa/.swiftlint.yml`
- Run: `make lint-swift` or `make lint-staged` (for pre-commit)
- Key enabled rules: `cyclomatic_complexity`, `force_cast`, `force_try`, `force_unwrapping`, `todo`, `trailing_comma`, `void_return`, `line_length`
- Custom rules: `no_try_optional_in_tests` - prohibits `try?` in test files; use `try XCTUnwrap(...)` instead

**Identifier Constraints:**

- Minimum length: 1 character (allowed: `i`, `_`)
- Maximum length: 50 characters (enforced as error level)
- Type name minimum: 2-1 characters, maximum 60 (error level)

## Import Organization

**Order:**

1. Special imports with attributes (`@_implementationOnly`, `@_spi(Private)`, `@testable`)
2. Framework imports (`import Sentry`, `import Foundation`, `import UIKit`)
3. Standard library imports (`import Darwin`, `import XCTest`)
4. Conditional imports (`#if os(...)`)

**Examples from codebase:**

```swift
// SentryClient.swift
@_implementationOnly import _SentryPrivate
import Foundation

// SentryClientTests.swift
@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

// Options.swift
// swiftlint:disable file_length
import Foundation  // (after swiftlint directive)
```

**Path Aliases:**

- Not heavily used; imports are direct
- Test utilities imported with `@_spi(Private)` for explicit access control

**Barrel Files:**

- Not used; imports are explicit to specific types

## Error Handling

**Patterns:**

- Prefer `guard let` with early return over nested `if` statements
- Use `try`/`catch` for throwable operations (not `try?` in tests)
- Test error paths: Use `try XCTUnwrap()` for optional assertions (see AGENTS.md)
- Handle errors explicitly; avoid silent failures
- Log errors at appropriate level: `.error()`, `.warning()`, `.debug()`

**Examples:**

```swift
// Guard pattern for optionals
guard let helper = SentryClientInternal(options: options) else {
    return nil
}

// Try-catch for throwable code
do {
    let options = try SentryOptionsInternal.initWithDict(["dsn": dsn])
    // use options
} catch {
    XCTFail("Options could not be created")
}

// Error logging
SentrySDKLog.error("Could not parse the DSN: \(error)")
```

## Logging

**Framework:** `SentrySDKLog` (custom logging system, not `print` or `NSLog`)

**Patterns:**

- Use `SentrySDKLog.debug()`, `.warning()`, `.error()` for appropriate severity levels
- Debug logs: `SentrySDKLog.debug("message")`
- Warnings: `SentrySDKLog.warning("message")`
- Errors: `SentrySDKLog.error("message")`
- Logs only appear when SDK debug mode is enabled
- In crash-critical code (SentryCrash), use `SENTRY_ASYNC_SAFE_LOG` macro to avoid non-async-safe logging

**Examples:**

```swift
SentrySDKLog.error("Could not parse the DSN: \(error)")
SentrySDKLog.warning("Only instances of NSString are supported in tracePropagationTargets.")
SentrySDKLog.debug("Dropping attachment, because the size is bigger than \(maxAttachmentSize) bytes.")
```

## Comments

**When to Comment:**

- Document non-obvious behavior or complex logic
- Explain why a decision was made, not what the code does (code should be self-documenting)
- Mark workarounds or temporary solutions with `// TODO:`, `// FIXME:`, or `// HACK:`
- Document platform-specific code with `#if os(...)` rationales

**Documentation Comments (Swift):**

- Use `///` for public API documentation
- Include description, parameters, return value, notes
- Use `@objc` attributes for Objective-C bridge documentation
- Link related types with backticks

**Examples:**

```swift
/// The DSN tells the SDK where to send the events to. If this value is not provided, the SDK will
/// not send any events.
@objc public var dsn: String? {
    didSet {
        // Parse DSN when set
    }
}

/// Captures a manually created event and sends it to Sentry.
/// - Parameter event: The event to send to Sentry.
/// - Returns: The `SentryId` of the event or `SentryId.empty` if the event is not sent.
@discardableResult @objc(captureEvent:) public func capture(event: Event) -> SentryId {
    // implementation
}
```

**Test Comments:**

- Use `// -- Arrange --`, `// -- Act --`, `// -- Assert --` markers per AGENTS.md
- Avoid line numbers in comments (they become outdated)
- Reference function names and file names instead
- Document why error paths cannot be tested (if applicable)

## Function Design

**Size Guidelines:**

- Keep functions focused on a single responsibility
- SwiftLint: `function_body_length` rule enabled (typical files < 200 lines)
- If a function becomes too large, refactor into smaller focused functions

**Parameters:**

- Use descriptive names
- Limit to 5-7 parameters; use structs/objects if more are needed
- Use parameter labels for clarity: `func capture(event: Event, scope: Scope)`
- Omit parameter label for single parameters: `func capture(_:)`

**Return Values:**

- Declare return type explicitly
- Use `@discardableResult` for functions whose return value can be safely ignored
- Return optionals only when absence is a valid state
- Prefer returning concrete types over optionals when possible

**Examples:**

```swift
@discardableResult @objc(captureEvent:) public func capture(event: Event) -> SentryId

public func capture(event: Event, scope: Scope) -> SentryId

@objc public var isEnabled: Bool
```

## Module Design

**Exports:**

- Public API uses `@objc` annotation for Objective-C bridge compatibility
- Internal APIs use `@_spi(Private)` for explicit private access
- Test utilities use `@_spi(Private) public` to allow test access without public API exposure

**Example structure:**

```swift
@_spi(Private) @testable import Sentry        // Test file imports
@_spi(Private) import SentryTestUtils         // Internal test utilities

@objc(SentryClient) public final class SentryClient: NSObject {  // Public API
    @_spi(Private) public let helper: SentryClientInternal     // Internal exposure for tests
}
```

**Type Qualifiers:**

- `final` on classes that should not be subclassed (common practice in this codebase)
- `private` for internal implementation details
- `public` for public API
- `@_spi(Private)` for APIs intended for internal/test use

## Test-Specific Conventions

**Test Classes:**

- Use `Fixture` inner class for test setup and factory methods
- Fixtures hold test data, mocks, and helper methods
- Each test method is self-contained and readable (DAMP principle per AGENTS.md)
- Use `setUpWithError()` and `tearDown()` for lifecycle management

**Test Structure Pattern:**

```swift
class SomeTests: XCTestCase {
    private class Fixture {
        let dependency = TestDependency()

        func getSut() -> SomeClass {
            return SomeClass(dependency: dependency)
        }
    }

    private var fixture: Fixture!

    override func setUpWithError() throws {
        try super.setUpWithError()
        fixture = try Fixture()
    }

    override func tearDown() {
        super.tearDown()
        clearTestState()
    }

    func testSomething() {
        // -- Arrange --
        let sut = fixture.getSut()

        // -- Act --
        let result = sut.doSomething()

        // -- Assert --
        XCTAssertEqual(result, expected)
    }
}
```

**Mock/Test Classes:**

- Prefer `struct` over `class` for test data (unless reference semantics needed)
- Use `Test<Name>` naming for mocks (e.g., `TestTransport`, `TestClient`)
- Record invocations with `Invocations<T>` pattern
- Mock return values can be set via methods: `mockGetValueReturnValue(_:)`

## Attribute Patterns

**Common Attributes:**

- `@objc` - Exposes to Objective-C runtime
- `@_spi(Private)` - Marks as private SPI (Seriousness Public Interface)
- `@_implementationOnly` - Implementation-only import for internal frameworks
- `@testable` - Allows test access to internal types
- `@discardableResult` - Allows return value to be ignored without compiler warning
- `final` - Prevents subclassing

**Example Usage:**

```swift
@_implementationOnly import _SentryPrivate

@_spi(Private) @testable import Sentry

@objc public final class SentryClient: NSObject {
    @discardableResult @objc(captureEvent:)
    public func capture(event: Event) -> SentryId
}
```

## File Organization

**Typical File Structure:**

1. Imports (organized by type as per Import Organization section)
2. SwiftLint directives if needed (`// swiftlint:disable file_length`)
3. Type definition (class, struct, enum)
4. Properties (organized: stored, computed, lazy)
5. Initializers
6. Methods (organized by responsibility or functionality)
7. Nested types (Fixture classes, enums, etc.)
8. SwiftLint re-enables (`// swiftlint:enable file_length`)

**Example:**

```swift
@_implementationOnly import _SentryPrivate
import Foundation

// swiftlint:disable file_length
/// Documentation
@objc public final class SentryClient: NSObject {
    let helper: SentryClientInternal

    @objc public init?(options: Options) {
        // init
    }

    @objc public var isEnabled: Bool {
        helper.isEnabled
    }

    @discardableResult @objc(captureEvent:)
    public func capture(event: Event) -> SentryId {
        helper.capture(event: event)
    }
}
// swiftlint:enable file_length
```

---

_Convention analysis: 2026-02-13_
