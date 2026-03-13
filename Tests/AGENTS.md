# Tests

> Instructions for LLM agents. Keep edits minimal (headers + bullets). Use `/agents-md` skill when editing.

## Running Tests

Test classes follow naming pattern `<SourceFile>Tests`. Default to iOS (fastest).

```bash
make test-ios                                                  # all iOS tests
make test-ios ONLY_TESTING=SentryHttpTransportTests             # single class
make test-ios ONLY_TESTING=SentryHttpTransportTests,SentryHubTests  # multiple
make test-ios ONLY_TESTING=SentryHttpTransportTests/testFlush_WhenNoInternet  # single method
make test                                                      # all platforms
make test-ui-critical                                          # important UI tests
```

**Scope assessment:**

- Specific feature → run related test classes
- Core SDK (`SentryHub`, `SentryClient`, `SentrySDK`) → `make test-ios`
- Multiple areas or unsure → `make test-ios` or `make test`

### Test Server

Only needed for `SentryNetworkTrackerIntegrationTestServerTests` (3 tests). Most tests run without it.

```bash
make run-test-server
./scripts/sentry-xcodebuild.sh --platform iOS --command test --test-plan Sentry_TestServer
make stop-test-server   # always stop after use
```

## Naming Convention

Pattern: `test<Function>_when<Condition>_should<Expected>()`

- `testAdd_whenSingleItem_shouldAppendToStorage()`
- `testCapture_whenEmptyBuffer_shouldDoNothing()`

## Code Style

### Arrange-Act-Assert

```swift
func testExample() {
    // -- Arrange --
    let input = "test"

    // -- Act --
    let result = transform(input)

    // -- Assert --
    XCTAssertEqual(result, "TEST")
}
```

### Prefer Specific Assertions Over `XCTAssert`

Never use bare `XCTAssert()` — it produces poor failure messages. Use the most specific assertion available:

| Instead of                | Use                           |
| ------------------------- | ----------------------------- |
| `XCTAssert(a == b)`       | `XCTAssertEqual(a, b)`        |
| `XCTAssert(a != b)`       | `XCTAssertNotEqual(a, b)`     |
| `XCTAssert(a === b)`      | `XCTAssertIdentical(a, b)`    |
| `XCTAssert(a !== b)`      | `XCTAssertNotIdentical(a, b)` |
| `XCTAssert(x)` (any Bool) | `XCTAssertTrue(x)`            |
| `XCTAssert(!x)`           | `XCTAssertFalse(x)`           |
| `XCTAssert(x == nil)`     | `XCTAssertNil(x)`             |
| `XCTAssert(x != nil)`     | `XCTAssertNotNil(x)`          |

### DAMP Over DRY

Prefer self-contained, readable tests. Duplicate test code if it improves clarity. Use helpers only for complex setup, shared fixtures, or genuinely reusable assertion logic.

### Pattern Matching

Use `guard case` with early return over `if case`:

```swift
guard case .string(let value) = result else {
    return XCTFail("Expected .string case")
}
XCTAssertEqual(value, "test")
```

### Optional Precision Assertions

Use `XCTUnwrap` when `XCTAssertEqual` requires non-optional (e.g., `accuracy:` parameter):

```swift
XCTAssertEqual(try XCTUnwrap(result as? Double), 3.14, accuracy: 0.00001)
```

For arrays, use `element(at:)` (returns nil on out-of-bounds) instead of direct subscript:

```swift
let array = try XCTUnwrap(result as? [Double])
XCTAssertEqual(try XCTUnwrap(array.element(at: 0)), 1.1, accuracy: 0.00001)
XCTAssertEqual(array.count, 2)
```

## Test Helpers

- Prefer `struct` over `class` unless reference semantics are needed (shared mutable state, `AnyObject` protocols, mock observation)

## Untestable Error Paths

When an error path cannot be reliably tested (hardcoded valid params, resource exhaustion, `DYLD_INTERPOSE` limitations):

1. Remove the broken test
2. Document why in the test file
3. Comment at the error handling site in source
4. Note in PR description
