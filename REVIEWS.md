# Code Review — Agent Instructions

> Instructions for LLM agents. Keep edits minimal (headers + bullets). Use `/agents-md` skill when editing.

Applies to all review agents (human-assisted, Bugbot, code-review skill). Review bots should verify changes align with the nested AGENTS.md files: [Sources/AGENTS.md](Sources/AGENTS.md), [Tests/AGENTS.md](Tests/AGENTS.md), [scripts/AGENTS.md](scripts/AGENTS.md), [.github/AGENTS.md](.github/AGENTS.md), [Samples/AGENTS.md](Samples/AGENTS.md), [develop-docs/AGENTS.md](develop-docs/AGENTS.md).

## Review Priorities

In order of importance:

1. **Thread safety** — SDK runs on arbitrary queues; check for data races, unprotected shared state, missing synchronization
2. **Memory management** — retain cycles, leaks in ObjC code, strong reference cycles in closures/blocks
3. **Public API surface** — backward compatibility, nullability annotations, `NS_SWIFT_NAME` correctness, SPI vs public visibility
4. **Cross-platform correctness** — `#if os(...)` guards, `@available` annotations, platform-specific imports
5. **Error handling** — silent failures, swallowed errors, missing fallback paths (the SDK must never crash the host app)
6. **Performance** — hot path allocations, unnecessary main thread work, serialization overhead

## SDK-Specific Concerns

- **Never crash the host app** — all public entry points must be defensive
- **`SentrySDK.start()` can be called from any thread** — initialization must be thread-safe
- **Swizzling** — must be idempotent and check for prior swizzling
- **C/C++ code** (SentryCrash) — buffer overflows, null pointer dereferences, signal safety
- **Session Replay** — privacy-sensitive; verify redaction/masking logic
- **Envelope serialization** — correct byte ordering, length prefixes, JSON encoding

## Conventions to Enforce

- Test names: `test<Function>_when<Condition>_should<Expected>()`
- New/changed code must have corresponding tests
- `guard case` over `if case` for pattern matching in tests
- `XCTUnwrap` + `element(at:)` for safe array access (not direct subscript)
- File renames preserve git history (`git mv`)
- No AI assistant references in commits or PR descriptions
- ObjC uses `[[Class alloc] init]`, not `[Class new]`

## What NOT to Flag

- **Style/formatting** — handled by pre-commit hooks (SwiftLint, clang-format, dprint)
- **Test verbosity** — tests follow DAMP (not DRY); duplicate test code is acceptable
- **`// -- Arrange --` / `// -- Act --` / `// -- Assert --`** — required test pattern
- **Conventional commit format** — validated by CI

## PR Description Expectations

- Non-changelog changes include `#skip-changelog`
- Breaking changes clearly documented
- Untestable error paths documented
