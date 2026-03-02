# BUGBOT.md

Instructions for Cursor Bugbot when reviewing pull requests on this repository.

## Repository Context

This is the Sentry Cocoa SDK — a multi-platform Apple SDK supporting iOS, macOS, tvOS, watchOS, and visionOS. It contains Objective-C, Swift, and C/C++ code.

## Review Priorities

Focus review on these areas, in order of importance:

1. **Thread safety** — SDK runs on arbitrary queues; check for data races, unprotected shared state, missing synchronization
2. **Memory management** — retain cycles, leaks in ObjC code, strong reference cycles in closures/blocks
3. **Public API surface** — backward compatibility, nullability annotations, `NS_SWIFT_NAME` correctness, SPI vs public visibility
4. **Cross-platform correctness** — `#if os(...)` guards, availability annotations (`@available`), platform-specific imports
5. **Error handling** — silent failures, swallowed errors, missing fallback paths in SDK code (the SDK must never crash the host app)
6. **Performance** — hot path allocations, unnecessary work on main thread, serialization overhead

## What NOT to Flag

- **Style/formatting** — handled by pre-commit hooks (SwiftLint, clang-format, dprint)
- **Test verbosity** — tests intentionally follow DAMP (not DRY) style; duplicate test code is acceptable
- **`// -- Arrange --` / `// -- Act --` / `// -- Assert --` markers** — required test pattern, not noise
- **`[[Class alloc] init]` over `[Class new]`** — this is the project convention, not a mistake
- **Conventional commit format** — validated by CI, not a review concern

## Conventions to Enforce

- Test names follow `test<Function>_when<Condition>_should<Expected>()`
- New/changed code must have corresponding tests
- `guard case` preferred over `if case` for pattern matching in tests
- `XCTUnwrap` + `element(at:)` for safe array access in tests (not direct subscript)
- File renames must preserve git history (`git mv`)
- No AI assistant references in commits or PR descriptions

## SDK-Specific Concerns

- **The SDK must never crash the host app** — all public entry points must be defensive
- **SentrySDK.start() can be called from any thread** — initialization must be thread-safe
- **Swizzling** — method swizzling must be idempotent and check for prior swizzling
- **C/C++ code** (SentryCrash) — review for buffer overflows, null pointer dereferences, signal safety
- **Session Replay** — privacy-sensitive; verify redaction/masking logic
- **Envelope serialization** — check for correct byte ordering, length prefixes, and JSON encoding

## PR Description Expectations

- Non-changelog changes should include `#skip-changelog` in the description
- Breaking changes must be clearly documented
- Untestable error paths should be documented in the PR description
