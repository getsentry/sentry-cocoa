# Testing Patterns

**Analysis Date:** 2026-03-19

## Test Framework

**Runner:**

- XCTest (Apple's native testing framework)
- Config: Xcode project configuration in `Sentry.xcworkspace`
- Run commands:
  ```bash
  make test-ios                                              # Run all iOS tests
  make test-ios ONLY_TESTING=SentryClientTests              # Run single test class
  make test-ios ONLY_TESTING=SentryClientTests,SentryHubTests  # Run multiple classes
  make test-ios ONLY_TESTING=SentryClientTests/testCaptureMessage  # Run single method
  make test                                                  # Run all platforms
  make test-ui-critical                                     # Important UI tests
  ```

**Assertion Library:**

- XCTest assertions: `XCTAssert`, `XCTAssertEqual`, `XCTAssertNil`, etc.
- Custom assertion helper: `XCTUnwrap` for safe unwrapping

**TestObserver Pattern:**

- `XCTestExpectation` for async assertions
- Wait with: `wait(for: [expectation], timeout: 5.0)`

## Test File Organization

**Location:**

- Test files co-located with source: `Tests/SentryTests/` mirror the source structure
- Test utilities: `SentryTestUtils/` — shared test infrastructure
- File paths:
  - Core tests: `Tests/SentryTests/<Feature>Tests.swift`
  - Integration tests: `Tests/SentryTests/Integrations/<Name>Tests.swift`
  - Transaction tests: `Tests/SentryTests/Transaction/<Name>Tests.swift`
  - Crash tests: `Tests/SentryTests/SentryCrash/<Name>Tests.swift`

**Naming:**

- Test files: `<SourceFile>Tests.swift` (e.g., `SentryClientTests.swift`)
- Test classes: `final class <SourceClass>Tests: XCTestCase`
- Test methods: `func test<Function>_when<Condition>_should<Expected>()`
  - Example: `testCapture_whenEmptyBuffer_shouldDoNothing()`
  - Simpler form also used: `testCaptureMessage()`, `testClientIsEnabled()`

**Structure:**

```
Tests/
├── SentryTests/
│   ├── SentryClientTests.swift         # Core client tests
│   ├── SentryHubTests.swift            # Hub coordination tests
│   ├── Transaction/                    # Transaction/span tests
│   ├── Integrations/                   # Integration feature tests
│   └── SentryCrash/                    # Crash reporting tests
├── SentryProfilerTests/                # Profiler-specific tests
└── DuplicatedSDKTest/                  # SDK duplication tests
```

## Test Structure

**Suite Organization:**

```swift
final class SentryClientTests: XCTestCase {

    // Private nested Fixture class
    private class Fixture {
        let transport: TestTransport
        let dateProvider = TestCurrentDateProvider()
        let session: SentrySession
        let event: Event
        // ... all dependencies

        init() throws {
            // Setup shared test data
        }

        func getSut() -> SentryClientInternal {
            // System Under Test factory
        }
    }

    private var fixture: Fixture!
    private lazy var sut = fixture.getSut()

    override func setUpWithError() throws {
        try super.setUpWithError()
        fixture = try Fixture()
        // ... clean up persistent state
    }

    override func tearDown() {
        super.tearDown()
        // ... clean up after each test
    }

    // Test methods
    func testCaptureMessage() throws { }
}
```

**Key Patterns:**

1. **Fixture Pattern:**
   - Private nested `Fixture` class holds all shared test dependencies
   - Fixture init marked `throws` to support XCTest error propagation
   - Factory method: `func getSut()` or `func getSut(_ options: Options)` creates subject under test
   - Location: `Tests/SentryTests/<Feature>Tests.swift` (examples: `SentryClientTests.swift`, `SentryHubTests.swift`)

2. **Setup/Teardown:**
   - `override func setUpWithError() throws` — runs before each test (can throw)
   - `override func tearDown()` — runs after each test (cleanup)
   - Fixture initialized in `setUpWithError()` with `try Fixture()`
   - Teardown cleans persistent state: file manager deletions, dependency container reset

3. **Arrange-Act-Assert:**
   ```swift
   func testCaptureMessage() throws {
       // -- Arrange --
       let message = "test message"
       let sut = fixture.getSut()

       // -- Act --
       let eventId = sut.capture(message: message)

       // -- Assert --
       XCTAssertNotNil(eventId)
       let capturedEvent = fixture.transport.sentEnvelopes.first
       XCTAssertNotNil(capturedEvent)
   }
   ```

## Mocking

**Framework:**

- Custom test doubles using inheritance and protocol conformance
- No external mocking library (Mockito, OCMock not used for new code)

**Patterns:**

```swift
// Invocation Recording (from SentryTestUtils/Sources/Invocations.swift)
public class Invocations<T> {
    public var invocations: [T] { /* thread-safe access */ }
    public var count: Int { /* invocation count */ }
    public func record(_ invocation: T) { /* append to list */ }
}

// Mock Transport (from SentryTestUtils/Sources/TestTransport.swift)
public class TestTransport: NSObject, Transport {
    @_spi(Private) public var sentEnvelopes = Invocations<SentryEnvelope>()

    @_spi(Private) public func send(envelope: SentryEnvelope) {
        sentEnvelopes.record(envelope)
    }
}

// Mock Hub (from SentryTestUtils/Sources/TestHub.swift)
public class TestHub: SentryHubInternal {
    public var sentFatalEvents = Invocations<Event>()

    public override func captureFatalEvent(_ event: Event) {
        sentFatalEvents.record(event)
    }
}
```

**What to Mock:**

- Transport/HTTP layer: `TestTransport`, `TestTransportAdapter`
- Hub: `TestHub` with invocation tracking
- File manager: `TestFileManager`
- Date provider: `TestCurrentDateProvider()`
- Dispatch: `TestSentryDispatchQueueWrapper`
- Random: `TestRandom(value: 0.5)`

**What NOT to Mock:**

- Core data models: `Event`, `Breadcrumb`, `Scope` — use directly
- Options/Configuration: `Options()` — construct with real class
- Scope/Session: Use actual implementations with real methods

**Testing Async Behavior:**

```swift
// Invocations are thread-safe; can check async results
let expectation = XCTestExpectation(description: "operation complete")
dispatchQueue.dispatchAsync { [weak sut] in
    sut?.someAsyncOperation()
    expectation.fulfill()
}
wait(for: [expectation], timeout: 5.0)
XCTAssertEqual(fixture.transport.sentEnvelopes.count, 1)
```

## Fixtures and Factories

**Test Data:**

- Fixture class pattern (shown above) centralizes setup
- Factory methods in Fixture: `func getSut()`, `func getSut(withMaxBreadcrumbs:)`, `func getSut(_ options:)`
- Real objects instantiated: `Options()`, `Event()`, `Scope()`
- Mock dependencies injected: `TestTransport()`, `TestFileManager()`

**Location:**

- Fixtures: Nested `private class Fixture` inside test class
- Test utilities: `SentryTestUtils/Sources/Test*.swift` (30+ helpers)
- Examples:
  - `TestTransport.swift` — mock envelope transport
  - `TestHub.swift` — mock hub with invocation tracking
  - `TestFileManager.swift` — mock persistent storage
  - `TestCurrentDateProvider.swift` — controlled time
  - `TestRandom.swift` — controlled randomness
  - `TestSentryDispatchQueueWrapper.swift` — controlled dispatch

## Coverage

**Requirements:** Not enforced by linter

**View Coverage:**

```bash
# Coverage data generated during test runs in Xcode
# View in Xcode scheme editor or run:
make test-ios  # Generates coverage reports
```

## Test Types

**Unit Tests:**

- Scope: Single class or function in isolation
- Approach: Mock all external dependencies
- Location: `Tests/SentryTests/<Feature>Tests.swift`
- Examples: `SentryClientTests.swift`, `SentryHubTests.swift`
- Dependencies mocked: Transport, FileManager, DateProvider, Dispatch

**Integration Tests:**

- Scope: Multiple components interacting
- Approach: Real objects where possible, mocks at boundaries
- Location: `Tests/SentryTests/Integrations/<Feature>Tests.swift`
- Examples: Network tracking, ANR detection, Session Replay
- May spin up real HTTP transports or use test servers

**E2E Tests:**

- Framework: Not in main test suite
- Sample app tests: `Samples/` directory includes UI tests for sample apps
- Approach: Build and run sample app, verify SDK initializes and captures events

## Common Patterns

**Async Testing:**

```swift
func testAsyncCapture() throws {
    let expectation = XCTestExpectation(description: "capture complete")

    dispatchQueue.dispatchAsync { [weak sut] in
        sut?.captureAsync()
        expectation.fulfill()
    }

    wait(for: [expectation], timeout: 5.0)
    XCTAssertEqual(fixture.transport.sentEnvelopes.count, 1)
}
```

**Error Testing:**

```swift
// Use throws in test signature
func testCaptureWithError() throws {
    // Use try XCTUnwrap for safe unwrapping
    let event = try XCTUnwrap(fixture.event)

    // Or check optional/guard pattern
    guard let sut = fixture.getSut() else {
        return XCTFail("Failed to initialize SUT")
    }

    let result = sut.capture(event)
    XCTAssertNotNil(result)
}
```

**Specific Assertions Over Generic:**

- ✅ Use: `XCTAssertEqual(a, b)`
- ✅ Use: `XCTAssertNil(value)`
- ✅ Use: `XCTAssertTrue(condition)`
- ❌ Avoid: `XCTAssert(a == b)` — poor error messages
- ❌ Avoid: `XCTAssert(value == nil)` — use `XCTAssertNil` instead

**DAMP Over DRY:**

- Prefer self-contained, readable test code
- Duplicate test setup if it improves clarity
- Use helpers only for:
  - Complex setup shared across 5+ tests
  - Genuinely reusable assertion logic
  - Fixture configuration (see `Fixture` class pattern)

**Pattern Matching in Tests:**

```swift
guard case .string(let value) = result else {
    return XCTFail("Expected .string case")
}
XCTAssertEqual(value, "test")
```

**Optional Precision Assertions:**

```swift
// When accuracy parameter needed
let array = try XCTUnwrap(result as? [Double])
XCTAssertEqual(try XCTUnwrap(array.element(at: 0)), 1.1, accuracy: 0.00001)
XCTAssertEqual(array.count, 2)
```

**SwiftLint Custom Rule:**

- Custom rule in `.swiftlint.yml`: `no_try_optional_in_tests`
- Error message: "Avoid `try?` in tests. Use `try XCTUnwrap(...)` instead."
- Enforces safe unwrapping pattern in test files

## Untestable Error Paths

When an error path cannot be reliably tested (hardcoded valid params, resource exhaustion, dynamic lookup limitations):

1. Remove the broken test
2. Document why in test file with comment block
3. Comment at error handling site in source code
4. Note in PR description: "Removed untestable error path for X because..."

Example comment:

```swift
// This error path cannot be reliably tested in normal test conditions
// because it requires resource exhaustion or specific platform state.
// See PR #XXXX for discussion.
```

## Test Server

**When Needed:**

- Only for `SentryNetworkTrackerIntegrationTestServerTests` (3 tests)
- Most tests run without it (standard pattern is using `TestTransport`)

**Start/Stop:**

```bash
make run-test-server   # Start test server
# Run specific test plan
./scripts/sentry-xcodebuild.sh --platform iOS --command test --test-plan Sentry_TestServer
make stop-test-server  # Always stop after use
```

## Linting Test Code

**SwiftLint Configuration:**

- Tests have separate `.swiftlint.yml` in `Tests/` directory
- Stricter rule: `no_try_optional_in_tests` (custom) — error on `try?`
- Must use `try XCTUnwrap(...)` for safe unwrapping in tests

---

_Testing analysis: 2026-03-19_
