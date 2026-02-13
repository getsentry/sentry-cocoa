# Testing Patterns

**Analysis Date:** 2026-02-13

## Test Framework

**Runner:**

- XCTest (built-in to Xcode)
- Test plans in `Plans/` directory (e.g., `Plans/iOS-Swift_Base.xctestplan`)
- Run via Makefile commands or `xcodebuild test`

**Assertion Library:**

- XCTest built-in assertions (XCTAssert, XCTAssertEqual, etc.)
- Custom assertion extension: `SentryId.assertIsNotEmpty()` and `.assertIsEmpty()`

**Run Commands:**

```bash
make test                          # Run all platform tests
make test-ios                      # Run iOS tests (fastest, recommended)
make test-ios ONLY_TESTING=<Class> # Run specific test class
make test-macos                    # Run macOS tests
make test-tvos                     # Run tvOS tests
make test-watchos                  # Run watchOS tests
make test-visionos                 # Run visionOS tests
make test-ui-critical              # Run critical UI tests
make run-test-server               # Start test server (rarely needed)
make stop-test-server              # Stop test server
```

## Test File Organization

**Location Pattern:**

- Swift tests: `Tests/SentryTests/<Feature>/<Module>Tests.swift`
- Objective-C tests: `Tests/SentryTests/<Feature>/<Module>Tests.m`
- Test utilities: `SentryTestUtils/Sources/` and `SentryTestUtilsTests/`

**Examples:**

- `Tests/SentryTests/SentryClientTests.swift` - Main client tests
- `Tests/SentryTests/Transaction/SentryTracer+Test.m` - Tracer test helpers
- `Tests/SentryTests/Transaction/SentryTracerTests.swift` - Tracer tests
- `SentryTestUtils/Sources/TestTransport.swift` - Reusable test mock

**Naming Convention:**

- Test files: `<SourceFile>Tests.swift` or `<SourceFile>Tests.m`
- Test methods: `test<Function>_when<Condition>_should<Expected>()`

**Directory Structure:**

```
Tests/SentryTests/
├── SentryClientTests.swift
├── Transaction/
│   ├── SentryTracerTests.swift
│   ├── SentryTracer+Test.m
│   └── SentrySpanTests.swift
├── Integrations/
├── Performance/
└── ... (organized by feature/module)

SentryTestUtils/
├── Sources/
│   ├── TestTransport.swift
│   ├── TestClient.swift
│   ├── TestFileManager.swift
│   └── ... (test utilities and mocks)
└── Package.swift
```

## Test Structure

**Suite Organization - Fixture Pattern (Primary):**

All test classes use the Fixture inner class pattern for setup and dependency management:

```swift
class SentryClientTests: XCTestCase {

    private class Fixture {
        let transport: TestTransport
        let transportAdapter: TestTransportAdapter
        let dateProvider = TestCurrentDateProvider()
        let debugImageProvider = TestDebugImageProvider()
        let fileManager: TestFileManager

        // Setup data
        let messageAsString = "message"
        let message: SentryMessage
        let user: User

        init() throws {
            // Initialize all dependencies
            message = SentryMessage(formatted: messageAsString)
            user = User()
            user.email = "someone@sentry.io"

            // Setup test file manager
            let options = Options()
            options.dsn = SentryClientTests.dsn
            fileManager = try XCTUnwrap(
                TestFileManager(options: options, dateProvider: dateProvider)
            )

            transport = TestTransport()
            transportAdapter = TestTransportAdapter(transports: [transport], options: options)
        }

        // Factory methods for system-under-test
        func getSut() -> SentryClientInternal {
            getSut(configureOptions: { _ in })
        }

        func getSut(configureOptions: (Options) -> Void) -> SentryClientInternal {
            let options = try SentryOptionsInternal.initWithDict(["dsn": SentryClientTests.dsn])
            configureOptions(options)
            return SentryClientInternal(/* params */)
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
}
```

**Arrange-Act-Assert Pattern (Required):**

All tests follow explicit AAA structure with comment markers:

```swift
func testCaptureMessage() throws {
    // -- Arrange --
    let sut = fixture.getSut()
    let messageAsString = fixture.messageAsString

    // -- Act --
    let eventId = sut.capture(message: messageAsString)

    // -- Assert --
    eventId.assertIsNotEmpty()
    let actual = try lastSentEvent()
    XCTAssertEqual(SentryLevel.info, actual.level)
    XCTAssertEqual(fixture.message, actual.message)
}
```

**Benefits:**

- Clear phase separation
- Easy to understand test purpose and expectations
- Consistent structure across all tests
- Facilitates test modification and debugging

## Mocking

**Framework:** Custom mocking patterns using protocol conformance

**Patterns:**

**1. Test Mock Classes:**
Located in `SentryTestUtils/Sources/`:

- Name: `Test<Name>` (e.g., `TestTransport`, `TestClient`, `TestFileManager`)
- Typically conform to protocols that real implementations use
- Record invocations and mocked return values

```swift
@_spi(Private) public class TestTransport: SentryTransport {
    public var sentEventsCount = 0
    public var sentEnvelopes: [SentryEnvelope] = []

    public func send(_ event: Event, attachmentPaths: [String]) -> SentryId {
        sentEventsCount += 1
        return SentryId()
    }
}
```

**2. Invocation Recording Pattern:**

```swift
public class TestInfoPlistWrapper: SentryInfoPlistWrapperProvider {
    public var getAppValueStringInvocations = Invocations<String>()
    private var mockedGetAppValueStringReturnValue: [String: Result<String, Error>] = [:]

    public func mockGetAppValueStringReturnValue(forKey key: String, value: String) {
        mockedGetAppValueStringReturnValue[key] = .success(value)
    }

    public func getAppValueString(for key: String) throws -> String {
        getAppValueStringInvocations.record(key)
        guard let result = mockedGetAppValueStringReturnValue[key] else {
            XCTFail("No mocked return value set for key: \(key)")
            return "<not set>"
        }
        switch result {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        }
    }
}
```

**3. Preferred Pattern - Structs for Test Data:**
Prefer `struct` over `class` for test helpers (unless reference semantics required):

```swift
// Good - test data struct
private struct TestItem: TelemetryBufferItem {
    var body: String
    // ...
}

// Avoid unless needed
private class TestItem: TelemetryBufferItem {
    var body: String
}
```

**When Reference Semantics Are Required:**
Use `class` for mocks that need to be observed or modified from tests:

```swift
// MockStorage must be class - stores state shared across test
private class MockStorage: BatchStorage {
    var appendedItems: [TestItem] = []
    func append(_ item: TestItem) {
        appendedItems.append(item)
    }
}
```

**What to Mock:**

- External dependencies: network transports, file systems, date providers
- Side effects: logging, notifications, database operations
- Platform-specific code: UIApplication, NSApplication, device info

**What NOT to Mock:**

- Business logic being tested
- Simple data structures (use real objects)
- Pure functions (no side effects)
- The code under test itself

## Fixtures and Factories

**Test Data:**

Reusable test data via `TestData` utility:

```swift
// From test files
let event = TestData.event
let debugImage = TestData.debugImage
let dataAttachment = TestData.dataAttachment
let timestamp = TestData.timestamp
```

**Test Data Creation Pattern:**

```swift
let event = Event()
event.message = SentryMessage(formatted: "test message")
event.level = SentryLevel.warning
event.exceptions = [Exception(value: "", type: "")]
```

**Factory Methods in Fixtures:**

```swift
private class Fixture {
    var scope: Scope {
        let scope = Scope()
        scope.setEnvironment("TestEnvironment")
        scope.setTag(value: "value", key: "key")
        scope.addAttachment(TestData.dataAttachment)
        return scope
    }

    var eventWithCrash: Event {
        let event = TestData.event
        event.level = .fatal
        let exception = Exception(value: "value", type: "type")
        let mechanism = Mechanism(type: "mechanism")
        mechanism.handled = false
        exception.mechanism = mechanism
        event.exceptions = [exception]
        return event
    }
}
```

**Location:**

- Reusable test utilities: `SentryTestUtils/Sources/`
- Test-specific fixtures: Inner `Fixture` classes in test files
- Shared test data: `SentryTestUtils/Sources/TestData.swift` or similar

## Coverage

**Requirements:**

- No enforced global coverage target
- Expected practice: Test all public APIs and critical code paths
- Focus on behavior coverage, not line coverage

**View Coverage:**

```bash
# Coverage data available in Xcode test results
# View via Xcode: Product > Scheme > Edit Scheme > Test > Code Coverage
# Or via command line through xcodebuild logs
```

**Coverage Strategy:**

- Unit tests: >80% for core functionality
- Integration tests: Key workflows and error conditions
- E2E tests: Critical user flows

## Test Types

**Unit Tests (Primary):**

- Location: `Tests/SentryTests/`
- Scope: Single class or function with mocked dependencies
- Speed: Milliseconds per test
- Tools: XCTest with custom mocks
- Example: `SentryClientTests.swift`, `SentrySpanTests.swift`

**Integration Tests:**

- Location: `Tests/SentryTests/` (marked with comments or organization)
- Scope: Multiple classes working together
- Speed: Tens to hundreds of milliseconds
- Example: Transaction + Tracer + Span interactions
- Mocks: Minimal; real implementations where practical

**E2E/UI Tests:**

- Framework: XCTest UI testing
- Location: `Tests/` with UI-specific subdirectories
- Run: `make test-ui-critical`
- Scope: User workflows, screen transitions
- Example: Session replay validation, crash handling flows
- Speed: Seconds per test (slow)

**Test Server Tests:**

- Location: Dedicated test plan `Sentry_TestServer.xctestplan`
- Scope: Network request tracking with real HTTP server
- Run: `make run-test-server && make test` (with specific test plan)
- Note: Only ~3 tests require this; run separately in CI

## Common Patterns

**Async Testing:**

```swift
func testAsyncOperation() throws {
    // -- Arrange --
    let expectation = expectation(description: "Operation completes")
    let sut = fixture.getSut()

    // -- Act --
    sut.performAsyncOperation { result in
        // -- Assert --
        XCTAssertNotNil(result)
        expectation.fulfill()
    }

    // Wait for completion
    waitForExpectations(timeout: 5.0)
}
```

**Error Testing with XCTUnwrap:**

Always use `try XCTUnwrap()` instead of `try?` in tests (enforced by SwiftLint):

```swift
func testCaptureEventWithCrash() throws {
    // -- Arrange --
    let event = Event()
    event.exceptions = [Exception(value: "", type: "")]

    // -- Act --
    fixture.getSut().capture(event: event, scope: fixture.scope)

    // -- Assert --
    let actual = try lastSentEventWithAttachment()  // Returns unwrapped or throws
    XCTAssertNotNil(actual.threads)
}
```

**Optional Assertions with Precision:**

For assertions with `accuracy` parameter, unwrap first using `XCTUnwrap`:

```swift
func testDoubleValue() throws {
    // -- Arrange --
    let value = 3.14159

    // -- Act --
    let result = roundValue(value)

    // -- Assert --
    XCTAssertEqual(try XCTUnwrap(result as? Double), 3.14, accuracy: 0.01)
}
```

**Array Element Access with Precision:**

Use `element(at:)` with `XCTUnwrap` instead of direct subscript:

```swift
func testArrayElements() throws {
    // -- Arrange --
    let sut = fixture.getSut()

    // -- Act --
    let result = sut.getDoubleArray()

    // -- Assert --
    let array = try XCTUnwrap(result as? [Double])
    XCTAssertEqual(try XCTUnwrap(array.element(at: 0)), 1.1, accuracy: 0.00001)
    XCTAssertEqual(try XCTUnwrap(array.element(at: 1)), 2.2, accuracy: 0.00001)
    XCTAssertEqual(array.count, 2)  // Verify no extra elements
}
```

**Guard Case Pattern in Assertions:**

Use `guard case` over `if case` for early exit and cleaner code:

```swift
func testEnumCase() throws {
    // -- Arrange --
    let sut = fixture.getSut()

    // -- Act --
    let result = sut.getResult()

    // -- Assert --
    guard case .success(let value) = result else {
        return XCTFail("Expected .success case")
    }
    XCTAssertEqual(value, "expected")
}
```

**DAMP Principle - Descriptive and Meaningful Phrases:**

Prefer self-contained, readable tests over DRY extraction (per AGENTS.md):

```swift
// Good - DAMP: Each test is self-contained and readable
func testBytesDescription() {
    // -- Arrange --
    let baseValue: UInt = 1

    // -- Act --
    let result = formatter.format(baseValue)

    // -- Assert --
    XCTAssertEqual("1 bytes", result)
}

func testKBDescription() {
    // -- Arrange --
    let baseValue: UInt = 1_024

    // -- Act --
    let result = formatter.format(baseValue)

    // -- Assert --
    XCTAssertEqual("1 KB", result)
}

// Avoid - Overly DRY: Test logic hidden in helper
func testBytesDescription() {
    assertDescription(baseValue: 1, expected: "1 bytes")
}

private func assertDescription(baseValue: UInt, expected: String) {
    // Complex logic hidden - need to jump to understand test
}
```

**Testing Error Paths:**

Only test error paths that can be reliably triggered. Document untestable paths:

```swift
func testFunction_HandlesOperationFailure() {
    // -- Arrange --
    // This test verifies that functionName handles errors correctly when operation() fails.
    // The error handling code path exists in SourceFile.c and is verified through code review.

    let invalidPath = "/nonexistent/path"

    // -- Act --
    let result = functionName(path: invalidPath)

    // -- Assert --
    // Verify function fails gracefully (error handling path executes)
    XCTAssertFalse(result)
}
```

**Test Teardown:**

Always use `clearTestState()` in tearDown to clean up global state:

```swift
override func tearDown() {
    super.tearDown()
    clearTestState()  // Clears SDK state, resets dependencies
}
```

## Test Configuration

**Xcode Test Plans:**

- Location: `Plans/` directory
- Examples:
  - `Plans/iOS-Swift_Base.xctestplan` - Base iOS Swift tests
  - `Plans/iOS-SwiftUI_Base.xctestplan` - SwiftUI-specific tests
  - `Plans/iOS-Benchmarking_Base.xctestplan` - Performance benchmarks
  - `Plans/Sentry_TestServer.xctestplan` - Network tracking tests (with test server)

**Build Settings for Tests:**

- Test configuration: Debug
- Simulator: iOS 18.4 on iPhone 16 Pro (configurable via Makefile)
- Test discovery: Automatic via XCTest

**Swift/Objective-C Mix:**

- Tests mix Swift and Objective-C based on what's being tested
- Swift preferred for new tests (better syntax, easier to read)
- Objective-C retained for testing ObjC-specific behavior

## Best Practices Summary

1. **Use Fixture Pattern** - Inner `Fixture` class for setup and factories
2. **Arrange-Act-Assert** - Three explicit phases with comment markers
3. **Self-Contained** - Each test readable without jumping to helpers (DAMP)
4. **Never Use try?** - Use `try XCTUnwrap()` for optionals in tests
5. **Clear Names** - `test<Function>_when<Condition>_should<Expected>()`
6. **Clean Teardown** - Call `clearTestState()` in tearDown
7. **Mock Appropriately** - Mock external dependencies, not business logic
8. **Early Exit** - Use `guard case` over `if case` for pattern matching
9. **Document Gaps** - Explain why error paths aren't tested (if applicable)
10. **Run Relevant Tests** - Use `make test-ios ONLY_TESTING=<Class>` for fast feedback

---

_Testing analysis: 2026-02-13_
