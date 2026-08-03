# Tests

> Instructions for LLM agents. Keep edits minimal (headers + bullets). Use `/agents-md` skill when editing.

## Running Tests

Test classes follow naming pattern `<SourceFile>Tests`. Default to iOS (fastest). Use `FOR_AGENTS=true` to reduce platform test output. If reduced output does not explain a failure, inspect updated `raw-*-output.log` files in the repository root.

```bash
make test-ios FOR_AGENTS=true                                                  # all iOS tests
make test-ios FOR_AGENTS=true ONLY_TESTING=SentryTests/SentryHttpTransportTests  # single class
make test-ios FOR_AGENTS=true ONLY_TESTING=SentryTests/SentryHttpTransportTests,SentryTests/SentryHubTests  # multiple
make test-ios FOR_AGENTS=true ONLY_TESTING=SentryTests/SentryHttpTransportTests/testFlush_WhenNoInternet  # single method
make test FOR_AGENTS=true                                                      # all platforms
make test-ui-critical                                          # important UI tests
```

**Scope assessment:**

- Specific feature → run related test classes with `FOR_AGENTS=true`
- Core SDK (`SentryHub`, `SentryClient`, `SentrySDK`) → `make test-ios FOR_AGENTS=true`
- Multiple areas or unsure → `make test-ios FOR_AGENTS=true` or `make test FOR_AGENTS=true`

### Test Server

Only needed for `SentryNetworkTrackerIntegrationTestServerTests` (5 tests). Most tests run without it.

```bash
make run-test-server
./scripts/sentry-xcodebuild.sh --platform iOS --command test --test-plan Sentry_TestServer
make stop-test-server   # always stop after use
```

Some of these tests compare full envelopes against JSON snapshots in `Tests/Resources/NetworkEnvelopeSnapshots`. The comparison is strict in both directions, so unexpected new keys fail too. On mismatch the failure lists every difference and prints the actual envelope JSON to update the snapshot from.

V10 uses the `-v10` variant of each snapshot, selected automatically. Payload changes usually need both files updated. Run each variant with a test plan:

```bash
make run-test-server
make test-macos TEST_PLAN=Sentry_TestServer      # v9 snapshots
make test-macos-v10 TEST_PLAN=Sentry_TestServer  # -v10 snapshots
make stop-test-server
```

## Test Location for SentryObjC Targets

SPM does not support mixed ObjC/Swift sources in one target. Two test targets exist:

| Test language | Target                  | Path                          | Has access to                                                   |
| ------------- | ----------------------- | ----------------------------- | --------------------------------------------------------------- |
| ObjC          | `SentryObjCTests`       | `Tests/SentryObjCTests`       | `@import SentryObjC` — public ObjC API (headers/"promise")      |
| Swift         | `SentryObjCCompatTests` | `Tests/SentryObjCCompatTests` | `@testable import SentryObjCCompat` — Swift wrappers/"delivery" |

**When to use which:**

- **`SentryObjCTests`** — verifies the public ObjC surface works from an ObjC consumer's perspective. Tests are `.m` files using `@import SentryObjC; @import XCTest;`. Use for property getters/setters, ObjC-visible initializers, and ObjC-only behavior
- **`SentryObjCCompatTests`** — verifies Swift `@objc` wrapper internals (enum conversions, metric bridging, internal-only initializers). Tests are `.swift` files using `@testable import SentryObjCCompat`. Use when you need access to `internal` symbols or Swift-only test patterns (generics, `Invocations<T>`)

**Rules:**

- Do **not** create test targets that depend on `SentryHeaders` for implementations — it is header-only (see [`develop-docs/SENTRY-OBJC.md`](../develop-docs/SENTRY-OBJC.md))
- Both targets are in the `SentryObjCTests` scheme and `SentryObjC_Base.xctestplan`
- Run via: `make test-macos FOR_AGENTS=true TEST_SCHEME=SentryObjCTests`
- Targeted class: `make test-macos FOR_AGENTS=true TEST_SCHEME=SentryObjCTests ONLY_TESTING=SentryObjCTests/SentryObjCOptionsTests`

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
- Prefer dependency overrides through `SentryDependencyContainer.sharedInstance()` over `PrivateSentrySDKOnly` hooks

## Untestable Error Paths

When an error path cannot be reliably tested (hardcoded valid params, resource exhaustion, `DYLD_INTERPOSE` limitations):

1. Remove the broken test
2. Document why in the test file
3. Comment at the error handling site in source
4. Note in PR description
