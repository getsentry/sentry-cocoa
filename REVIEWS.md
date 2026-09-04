# Code Review — Agent Instructions

> Applies to all review agents. Follow [root instructions](AGENTS.md) and the applicable nested `AGENTS.md`.

## Review Priorities

In order of importance:

1. **Thread safety** — SDK runs on arbitrary queues; check for data races, unprotected shared state, missing synchronization
2. **Memory management** — retain cycles, leaks in ObjC code, strong reference cycles in closures/blocks
3. **Public API surface** — backward compatibility, nullability annotations, `NS_SWIFT_NAME` correctness, SPI vs public visibility
4. **Cross-platform correctness** — `#if os(...)` guards, `@available` annotations, platform-specific imports
5. **Error handling** — silent failures, swallowed errors, missing fallback paths (the SDK must never crash the host app)
6. **Performance** — hot path allocations, unnecessary main thread work, serialization overhead

## SDK-Specific Concerns

- **Never crash the host app** — all public entry points must be defensive; prefer graceful degrade / no-op when a path cannot safely run (including older OS versions)
- **`SentrySDK.start()` can be called from any thread** — initialization must be thread-safe
- **Swizzling** — must be idempotent and check for prior swizzling
- **C/C++ code** (SentryCrash) — buffer overflows, null pointer dereferences, signal safety
- **Session Replay** — privacy-sensitive; verify redaction/masking logic; default to masking sensitive content
- **PII and sensitive data** — auto-instrumentation must not attach PII without explicit opt-in (`sendDefaultPii` or equivalent). Flag new default logging/sending of bodies, full URLs with secrets, paths, or device identifiers; attachments need size limits and must not be on-by-default when sensitive
- **Never capture SDK-own exceptions** — do not capture exceptions thrown inside the SDK or user callbacks (`beforeSend`, samplers, and similar). Swallow and log at error level; capturing here can loop. See [Never capture your own exceptions](https://develop.sentry.dev/sdk/getting-started/principles/#never-capture-your-own-exceptions)
- **Tracing** — spans started must be finished (including error paths). Automated spans set valid `sentry.origin` (`[a-zA-Z0-9_.]`) and `sentry.op` (lowercase snake_case / `.`-delimited); see [origin](https://develop.sentry.dev/sdk/telemetry/traces/trace-origin/) and [ops](https://develop.sentry.dev/sdk/telemetry/traces/span-operations/). Automated structured logs set `sentry.origin`. Prefer attributes known at start time on span start so sampling sees full context
- **Instrumentation error handling** — prefer letting user errors propagate. Flag swallowing without capture, and capture that double-reports an error still delivered to the app. When capturing user/app errors, set mechanism `handled` + stable `type` when the API supports it
- **Dependencies and defaults** — flag new baseline runtime dependencies on the core SDK path; prefer safe auto-enable of integrations over required config; avoid heavy in-SDK wire-format transforms when rawer data + server processing would do
- **Support floor drops** — raising min OS/SDK versions or dropping a platform needs explicit docs/changelog/migration notes
- **Envelope serialization** — correct byte ordering, length prefixes, JSON encoding
- **SentryObjC wrapper** — any new public API must also be exposed in `SentryObjC` / `SentryObjCCompat`; see [`develop-docs/SENTRY-OBJC.md`](develop-docs/SENTRY-OBJC.md) for the wrapper pattern and naming convention
- **Specification compliance** — for changes covered by an SDK specification, verify `sentry-spec-compliance.json` accurately reflects the implementation and follows [`develop-docs/SPEC_COMPLIANCE.md`](develop-docs/SPEC_COMPLIANCE.md)

## Conventions to Enforce

- Test names: `test<Function>_when<Condition>_should<Expected>()`
- New/changed code must have corresponding tests that prove behavior, not merely coverage or "did not throw"
- `feat`-style changes: prefer integration/E2E coverage of the new behavior when practical
- `fix`-style changes: prefer a regression test that fails without the fix and passes with it
- Flag likely flakes: sleeps/timeouts instead of signals; wait-after-act instead of register-wait-then-act; multi-event waits that assume a hard order
- `guard case` over `if case` for pattern matching in tests
- `XCTUnwrap` + `element(at:)` for safe array access (not direct subscript)
- File renames preserve git history (`git mv`)
- No AI assistant references in commits or PR descriptions
- ObjC uses `[[Class alloc] init]`, not `[Class new]`
- No redundant comments on internal code (see [Sources/AGENTS.md](Sources/AGENTS.md)); only _why_-comments and public headerdocs

## What NOT to Flag

- **Style/formatting** — handled by pre-commit hooks (SwiftLint, clang-format, dprint)
- **Test verbosity** — tests follow DAMP (not DRY); duplicate test code is acceptable
- **`// -- Arrange --` / `// -- Act --` / `// -- Assert --`** — required test pattern
- **Conventional commit format** — validated by CI
- **Speculative refactors** — cleanup with no clear user benefit or linked motivation
- **Idiomatic swizzling/hooks** — do not flag solely for being brittle; flag when unsafe, non-idempotent, or host-harmful

## PR Description Expectations

- Non-changelog changes include `#skip-changelog`
- Breaking changes clearly documented, including silent default/sampling/telemetry shape changes
- Support floor drops (min OS/version/platform) explicitly called out with migration notes
- Untestable error paths documented
