# Tests — Agent Instructions

## Testing Instructions

### Impact-Driven Testing

Before running tests, analyze which test classes are affected by your changes and run those specific tests first.

**Quick Commands:**

```bash
# Run all iOS tests (fastest platform, recommended for development)
make test-ios

# Run specific test class (when you know which tests are affected)
make test-ios ONLY_TESTING=SentryHttpTransportTests

# Run multiple test classes
make test-ios ONLY_TESTING=SentryHttpTransportTests,SentryHubTests

# Run specific test method
make test-ios ONLY_TESTING=SentryHttpTransportTests/testFlush_WhenNoInternet

# Run all platform tests
make test

# Run important UI tests
make test-ui-critical
```

**Determining Which Tests to Run:**

1. **Identify affected test classes** — Test classes follow the naming pattern `<SourceFile>Tests`
   - Changed `SentryHttpTransport.swift` → Run `ONLY_TESTING=SentryHttpTransportTests`
   - Changed `SentryHub.m` → Run `ONLY_TESTING=SentryHubTests`
   - Changed files in `SessionReplay/` → Run `ONLY_TESTING=SentrySessionReplayTests,SentryOnDemandReplayTests`

2. **Platform selection** — Default to iOS unless changing platform-specific code
   - Most changes → `make test-ios` (fastest)
   - macOS-specific → `make test-macos`
   - Cross-platform → Run specific platform or all platforms

3. **Scope assessment:**
   - **Specific feature changes** → Run related test classes
   - **Core SDK changes** (`SentryHub`, `SentryClient`, `SentrySDK`) → Run `make test-ios` (broader impact)
   - **Multiple feature areas** → Run `make test-ios` or `make test`

**General Guidelines:**

- Find the CI plan in the .github/workflows folder
- Fix any test or type errors until the whole suite is green
- Add or update tests for the code you change, even if nobody asked

### Test Server Requirements

The test server is **only required** for a small subset of network integration tests using the `Sentry_TestServer` xctestplan. The main test suite runs without it by design.

- **Most unit tests do NOT require the test server**
- **Only 3 specific tests need it** — Tests in `SentryNetworkTrackerIntegrationTestServerTests` that verify HTTP request tracking with a real server
- **Separate in CI** — These tests run in a dedicated `unit-tests-with-test-server` job with the `Sentry_TestServer` xctestplan
- **Impact analysis first** — Before running test server tests, evaluate if your changes affect network tracking or HTTP request functionality
- **Always stop the server after use** — The test server runs in the background and must be manually stopped to avoid port conflicts

```bash
# Only run if changes impact network tracking
make run-test-server

# Run specific test plan using the sentry-xcodebuild.sh wrapper
./scripts/sentry-xcodebuild.sh --platform iOS --command test --test-plan Sentry_TestServer

# IMPORTANT: Always stop the test server after use
make stop-test-server
```

## Naming Convention

Use the pattern `test<Function>_when<Condition>_should<Expected>()` for test method names.

**Examples:**

- `testAdd_whenSingleItem_shouldAppendToStorage()`
- `testAdd_whenMaxItemCountReached_shouldFlushImmediately()`
- `testCapture_whenEmptyBuffer_shouldDoNothing()`
- `testAdd_whenBeforeSendItemReturnsNil_shouldDropItem()`

## Prefer Structs Over Classes

When creating test helpers, mocks, or test data structures, prefer `struct` over `class`:

```swift
// Prefer
private struct TestItem: TelemetryBufferItem {
    var body: String
}

// Avoid (unless reference semantics are required)
private class TestItem: TelemetryBufferItem {
    var body: String
}
```

**When to use classes:**

- When reference semantics are required (e.g., shared mutable state that needs to be observed from tests)
- When conforming to protocols that require reference types (e.g., `AnyObject` protocols)
- When creating mock objects that need to be passed by reference to observe changes

## Code Style

### Arrange-Act-Assert Pattern

All tests should follow the AAA pattern with explicit comment markers:

```swift
func testExample() {
    // -- Arrange --
    let input = "test"
    let expected = "TEST"

    // -- Act --
    let result = transform(input)

    // -- Assert --
    XCTAssertEqual(result, expected)
}
```

### DAMP Tests (Descriptive And Meaningful Phrases)

Prefer self-contained, readable tests over DRY (Don't Repeat Yourself). It's acceptable to duplicate test code if it makes tests more understandable.

**Prefer (DAMP):**

```swift
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
```

**When to use helper methods:**

- Complex test setup that would obscure the test's intent
- Test fixtures or mock objects used across many tests
- Assertion logic that's truly complex and used consistently

### Prefer `guard case` Over `if case`

When pattern matching in tests, prefer `guard case` with early return over `if case`:

```swift
// Prefer
guard case .string(let value) = result else {
    return XCTFail("Expected .string case")
}
XCTAssertEqual(value, "test")

// Avoid
if case .string(let value) = result {
    XCTAssertEqual(value, "test")
} else {
    XCTFail("Expected .string case")
}
```

### Use `XCTUnwrap` for Optional Assertions with Precision

When using `XCTAssertEqual` with the `accuracy` parameter, the assertion does not accept optionals. Use `XCTUnwrap` to unwrap the optional first.

```swift
// Prefer
XCTAssertEqual(try XCTUnwrap(result as? Double), 3.14, accuracy: 0.00001)

// Avoid — Compiler error: optional not accepted
XCTAssertEqual(result as? Double, 3.14, accuracy: 0.00001)
```

For array assertions with precision, prefer `element(at:)` with `XCTUnwrap` instead of direct subscript access:

```swift
// Prefer — safer access, element(at:) returns nil for out-of-bounds
let array = try XCTUnwrap(result as? [Double])
XCTAssertEqual(try XCTUnwrap(array.element(at: 0)), 1.1, accuracy: 0.00001)
XCTAssertEqual(try XCTUnwrap(array.element(at: 1)), 2.2, accuracy: 0.00001)
XCTAssertEqual(array.count, 2)

// Avoid — direct subscript crashes on out-of-bounds
let array = try XCTUnwrap(result as? [Double])
XCTAssertEqual(array.count, 2)
XCTAssertEqual(array[0], 1.1, accuracy: 0.00001)
XCTAssertEqual(array[1], 2.2, accuracy: 0.00001)
```

## Testing Error Handling Paths

**Testable Error Paths:**

- **File operation failures**: Use invalid/non-existent paths, closed file descriptors, or permission-restricted paths
- **Directory operation failures**: Use invalid directory paths
- **Network operation failures**: Use invalid addresses or closed sockets

**Example test pattern:**

```objc
- (void)testFunction_HandlesOperationFailure
{
    // -- Arrange --
    // Setup to trigger error (e.g., invalid path, closed fd, etc.)

    // -- Act --
    bool result = functionName(/* parameters that will cause error */);

    // -- Assert --
    XCTAssertFalse(result, @"functionName should fail with error condition");
}
```

**Untestable Error Paths:**

Some error paths cannot be reliably tested:

- **System calls with hardcoded valid parameters**: Cannot pass invalid parameters to trigger failures
- **Resource exhaustion scenarios**: System limits may not be enforceable in test environments
- **Function interposition limitations**: `DYLD_INTERPOSE` only works for dynamically linked symbols

When an error path cannot be reliably tested:

1. Remove the test if one was attempted but couldn't be made to work
2. Add documentation in the test file explaining why there's no test
3. Add a comment in the source code at the error handling location
4. Update PR description to document untestable error paths

**Test Comment Best Practices:**

- Avoid line numbers in test comments — they become outdated when code changes
- Reference function names and file names instead
- Document the error condition being tested (e.g., "when open() fails")
- Explain verification approach rather than capturing implementation details
