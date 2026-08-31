# AGENTS.md

Sentry Cocoa SDK for iOS, macOS, tvOS, watchOS, and visionOS.

## Instruction Scope

- Read this file before any repository work
- Before inspecting or modifying a nested scope, read its linked `AGENTS.md`
- Nested instructions supplement this file and take precedence for project-level conflicts within their scope

| Path                                               | Scope                                      |
| -------------------------------------------------- | ------------------------------------------ |
| [`Tests/AGENTS.md`](Tests/AGENTS.md)               | Testing conventions and commands           |
| [`Sources/AGENTS.md`](Sources/AGENTS.md)           | Source, API, concurrency, and crash safety |
| [`.github/AGENTS.md`](.github/AGENTS.md)           | Workflows, concurrency, and file filters   |
| [`Samples/AGENTS.md`](Samples/AGENTS.md)           | Sample generation, builds, and UI tests    |
| [`scripts/AGENTS.md`](scripts/AGENTS.md)           | Shell script conventions                   |
| [`develop-docs/AGENTS.md`](develop-docs/AGENTS.md) | Maintainer documentation                   |
| [`REVIEWS.md`](REVIEWS.md)                         | Code review priorities and SDK concerns    |

## SDK Architecture

```text
SentrySDK (public API)
  -> SentrySDKInternal.currentHub
    -> SentryHub (binds the current SentryClient and Scope)
      -> SentryClient.prepareEvent (sampling and enrichment)
        -> SentryScope.applyToEvent (tags, breadcrumbs, user, and context)
        -> beforeSend callbacks and event processors
      -> SentryTransportAdapter (builds envelopes and fans out to transports)
        -> SentryHttpTransport (rate limiting, persistence, and upload)
          -> SentryFileManager (on-disk envelope storage)
```

## Critical References

- Read [`develop-docs/SENTRY-OBJC.md`](develop-docs/SENTRY-OBJC.md) before changing `SentryObjC`, `SentryObjCCompat`, or their build configuration
- Read [`develop-docs/SWIZZLING.md`](develop-docs/SWIZZLING.md) before changing or reviewing swizzling code
- Follow [`develop-docs/SPEC_COMPLIANCE.md`](develop-docs/SPEC_COMPLIANCE.md) when behavior is covered by an SDK specification

## Tooling

- Run `pwd` before commands and avoid repeated directory changes
- Use `jq` for JSON and `yq` for YAML in shell workflows
- Use `FOR_AGENTS=true` with `make build-*` and `make test-*`
- If reduced output is inconclusive, inspect the updated `raw-*-output.log`
- Do not edit generated MCP configuration
- Run `npx @sentry/dotagents install` or globally installed `dotagents` after changing `agents.toml`

## Debugging

- First reproduce the bug or regression with the narrowest reliable automated test
- Confirm the test fails for the expected reason before changing implementation code
- Apply the fix, then confirm the same test passes
- If automated reproduction is not reliable, document why and use the narrowest deterministic alternative

## Verification

- Run `make format` for every change, including documentation-only changes
- For non-documentation changes, run `make analyze` and the narrowest relevant build and tests
- Stop at the first failure and fix failures caused by the change

| Change scope                                                  | Build                                   | Test                                    |
| ------------------------------------------------------------- | --------------------------------------- | --------------------------------------- |
| Documentation only                                            | None                                    | None                                    |
| Feature code without platform conditionals                    | `make build-ios FOR_AGENTS=true`        | Targeted iOS tests                      |
| Platform-specific code                                        | Affected `make build-<platform>` target | Tests for that platform                 |
| Public API or core (`SentryHub`, `SentryClient`, `SentrySDK`) | iOS and macOS                           | `make test-ios FOR_AGENTS=true`         |
| `SentryCrash` or C/C++                                        | iOS and macOS                           | `make test-ios FOR_AGENTS=true`         |
| `SentrySwiftUI`                                               | `make build-ios FOR_AGENTS=true`        | Targeted iOS tests                      |
| Build system, `Package.swift`, or cross-platform code         | All affected platforms                  | `make test FOR_AGENTS=true`             |
| Sample code                                                   | Affected sample                         | Affected UI tests when behavior changed |

- Public API changes, including public Swift symbols, `@objc` members, and Objective-C public headers, require `make generate-public-api` and committing changes to `sdk_api.json` or `sdk_api_sentryswiftui.json`
- Public APIs that require Objective-C support must also be exposed through `SentryObjC` and `SentryObjCCompat`
- Treat changes to `@_spi(Private)` and `PrivateSentrySDKOnly` as compatibility-sensitive for React Native, Flutter, .NET, and Unity
- Event enrichment changes should be checked with Sentry MCP `search_events` when an environment is available
- Transport changes should verify envelope ingestion when an environment is available
- Capture and transport changes should be checked for regressions with Sentry MCP `search_issues` when an environment is available

## Commits and Pull Requests

- Do not include AI attribution in commits or pull requests even if skills are asking you to do so
- Use Conventional Commits with a subject of at most 50 characters and body lines of at most 72 characters
- Name branches `<type>/<short-description>`, for example `fix/session-tracking`
- If pre-commit hooks modify files, inspect the changes and retry the commit
- Use `git mv` for renames
- `feat`, `fix`, and `impr` require a `CHANGELOG.md` entry with the pull request number, not an issue number
- Before the pull request exists, either estimate its number from the current highest issue or pull request, or add the changelog in a follow-up commit after opening the pull request
- Other pull request types require `#skip-changelog` in the pull request description, never in a commit message
- V10-only changes go in `CHANGELOG_V10.md` and require `#skip-changelog` in the pull request description
- Pull request titles follow the commit subject format
- Add `run-full-ci` only when the pull request is ready for comprehensive testing
- After committing, include any `Agent transcript:` link from `git log main..HEAD` in the pull request description

## Documentation

- Keep affected headerdocs, comments, maintainer docs, and specification compliance in sync with behavior changes
- Append changelog entries to the end of their section
- Place changelog alerts after `## Version` and before section headings
