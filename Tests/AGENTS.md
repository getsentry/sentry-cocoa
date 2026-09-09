# Tests

> Scope: `Tests/**`. Also follow [root instructions](../AGENTS.md).

## Running Tests

```bash
make test-macos FOR_AGENTS=true
make test-macos FOR_AGENTS=true ONLY_TESTING=SentryTests/SentryHttpTransportTests
make test-ios FOR_AGENTS=true
make test-ios FOR_AGENTS=true ONLY_TESTING=SentryTests/SentryHttpTransportTests
make test-ios FOR_AGENTS=true ONLY_TESTING=SentryTests/SentryHttpTransportTests,SentryTests/SentryHubTests
make test-ios FOR_AGENTS=true ONLY_TESTING=SentryTests/SentryHttpTransportTests/testFlush_WhenNoInternet
make test FOR_AGENTS=true
make test-ui-critical
```

- Test classes follow `<SourceFile>Tests`
- The iOS test suite is slow, so prefer targeted macOS tests for quick iterations when the code and test support macOS
- Use iOS tests for iOS-specific or UIKit behavior and for final verification when required by the root matrix
- Use comma-separated test identifiers in `ONLY_TESTING` for multiple classes

## Test Server

- Use only for `SentryNetworkTrackerIntegrationTestServerTests`
- Start the server before the relevant test commands
- Stop the server after use, including when a test fails

```bash
make -C test-server start-debug
./scripts/sentry-xcodebuild.sh --platform iOS --command test --test-plan Sentry_TestServer
make test-macos FOR_AGENTS=true TEST_PLAN=Sentry_TestServer
make test-macos-v10 FOR_AGENTS=true TEST_PLAN=Sentry_TestServer
make -C test-server stop
```

- Run only the relevant test commands between start and stop
- Envelope snapshots in `Tests/Resources/NetworkEnvelopeSnapshots` compare all keys strictly
- On mismatch, use the printed actual envelope JSON to update the snapshot
- Payload changes usually require updating both standard and `-v10` snapshots

## SentryObjC Tests

- ObjC public API tests belong in `Tests/SentryObjCTests` and import `SentryObjC`
- Swift wrapper tests belong in `Tests/SentryObjCCompatTests` and use `@testable import SentryObjCCompat`
- Do not create implementation tests against header-only `SentryHeaders`
- Run `make test-macos FOR_AGENTS=true TEST_SCHEME=SentryObjCTests`
- Target a class with `ONLY_TESTING=SentryObjCTests/SentryObjCOptionsTests`
- Follow [`develop-docs/SENTRY-OBJC.md`](../develop-docs/SENTRY-OBJC.md)

## Untestable Paths

- Do not add unreliable tests for paths that cannot be controlled deterministically
- Document the limitation at the source error-handling site and in the pull request
- Use the narrowest deterministic lower-level validation when available

## Style

### Arrange, Act, Assert

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

- Name tests `test<Function>_when<Condition>_should<Expected>()`
- Structure tests with the Arrange, Act, Assert markers shown above
- Prefer specific assertions such as `XCTAssertEqual`, `XCTAssertNil`, and `XCTAssertTrue` over bare `XCTAssert`
- Prefer self-contained DAMP tests over premature helper abstractions
- Use `guard case` with `XCTFail` for pattern matching
- Use `XCTUnwrap` for optional values and `element(at:)` for safe array access
- Prefer `struct` test helpers unless reference semantics are required
- Override SDK dependencies through `SentryDependencyContainer.sharedInstance()` when possible
