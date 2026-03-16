# AGENTS.md

Sentry Cocoa SDK — multi-platform Apple SDK (iOS, macOS, tvOS, watchOS, visionOS).

These instructions are written for **LLM agents**, not humans. Keep content minimal (headers + bullets, no prose). When editing any `AGENTS.md` file, use the `agents-md` skill (see `.agents/skills/agents-md/SKILL.md`).

## Nested Instructions

| Path                                               | Scope                                              |
| -------------------------------------------------- | -------------------------------------------------- |
| [`Tests/AGENTS.md`](Tests/AGENTS.md)               | Testing conventions, naming, code style            |
| [`Sources/AGENTS.md`](Sources/AGENTS.md)           | ObjC/Swift conventions, API surface, thread safety |
| [`.github/AGENTS.md`](.github/AGENTS.md)           | Workflow naming, concurrency, file filters         |
| [`Samples/AGENTS.md`](Samples/AGENTS.md)           | Sample app structure and build                     |
| [`scripts/AGENTS.md`](scripts/AGENTS.md)           | Shell script conventions and template              |
| [`develop-docs/AGENTS.md`](develop-docs/AGENTS.md) | Internal dev docs, architecture, decisions         |
| [`REVIEWS.md`](REVIEWS.md)                         | Code review priorities and SDK concerns            |

## Architecture

```
SentrySDK (public entry point)
  → SentryHub (owns client + scope, routes captures)
    → SentryClient (builds events, calls prepareEvent)
      → SentryScope.applyToEvent (tags, breadcrumbs, user, context)
      → beforeSend / beforeSendTransaction callbacks
      → SentryTransportAdapter (builds envelopes)
        → SentryHttpTransport (rate limiting, disk persistence, upload)
          → SentryFileManager (envelope storage)
```

### Key Classes

| Class                    | Role                                                                             |
| ------------------------ | -------------------------------------------------------------------------------- |
| `SentrySDK`              | Public static API — `start`, `capture*`, `flush`, `close`                        |
| `SentryHub`              | Central coordinator — owns `client` + `scope`, manages sessions and integrations |
| `SentryClient`           | Event processing — builds events, applies scope, invokes `beforeSend`            |
| `SentryScope`            | Contextual data — tags, extras, breadcrumbs, user, attachments, span             |
| `SentryTransportAdapter` | Builds `SentryEnvelope` from events/sessions, fans out to transports             |
| `SentryHttpTransport`    | Rate-limited HTTP upload with disk persistence and retry                         |
| `SentryFileManager`      | On-disk envelope store                                                           |
| `PrivateSentrySDKOnly`   | SPI for hybrid SDKs (React Native, Flutter, .NET, Unity)                         |

### Module Layout (`Sources/`)

| Directory             | Contents                                                            |
| --------------------- | ------------------------------------------------------------------- |
| `Sentry/`             | ObjC core: SDK, Hub, Client, Scope, Transport, Serialization        |
| `Sentry/Public/`      | Public ObjC headers                                                 |
| `Sentry/Profiling/`   | C++/ObjC++ profiler, sampling, serialization                        |
| `Swift/`              | Swift layer: integrations, networking, persistence, tools           |
| `Swift/Integrations/` | Feature integrations (ANR, Performance, SessionReplay, Crash, etc.) |
| `SentryCrash/`        | C/C++ crash reporting (KSCrash fork)                                |
| `SentryCppHelper/`    | C++ helpers (backtrace, sampling profiler, thread handle)           |
| `SentrySwiftUI/`      | SwiftUI tracing (`TracedView`)                                      |

## Skills & MCP (dotagents)

Agent skills and MCP servers are managed by [dotagents](https://github.com/getsentry/dotagents) via `agents.toml`.

```bash
npx @sentry/dotagents install   # install skills after cloning
npx @sentry/dotagents update    # update to latest versions
npx @sentry/dotagents list      # show installed skills
```

### MCP Servers

Declared in `agents.toml`; [dotagents](https://github.com/getsentry/dotagents) generates `.mcp.json` (root, for Claude/CLI) and `.cursor/mcp.json` (Cursor IDE reads from `.cursor/` by default).
Do not edit these JSON files manually — run `npx @sentry/dotagents install` after cloning.

- **XcodeBuildMCP** — build, run, test in simulator (requires Node.js)
- **sentry** — query production errors, search issues, read docs (OAuth on first use)

Read-only tools pre-approved in `.claude/settings.json`. Mutating tools require per-developer approval in `.claude/settings.local.json`.

### Validating Changes with Sentry MCP

Use the `sentry` MCP server to verify events still arrive correctly after changes:

```
search_events  → find telemetry by type, tag, or time range
get_event      → inspect full event JSON
search_issues  → check for new/regressed issues
```

- After modifying event capture or enrichment, use `search_events` to confirm payload correctness
- After transport changes, verify envelopes are received and parsed
- Check for regressions: search for new issues matching your changed code paths

## Command Execution

- **Verify working directory** — use `pwd` to confirm you're in the correct path before running commands. The shell persists working directory across tool calls
- **Avoid redundant `cd`** — do not prefix every command with `cd <path> &&`. Change directory once if needed, then verify with `pwd`
- **Wildcard permissions** — many commands are pre-approved with wildcards (e.g., `git add:*`). Flags like `-C` change the command prefix (`git -C path add` ≠ `git add`), triggering a confirmation prompt. Avoid `-C` when you can change directory instead
- **Prefer small, focused commands** over one massive pipeline. Break complex operations into multiple steps
- **JSON processing** — always use `jq`; do not shell out to `node` or `python` for JSON parsing
- **GitHub** — prefer `gh` CLI over web scraping when interacting with GitHub.com

## Verification Loop

Run before every commit. Stop at the first failure and fix before proceeding.

```bash
# 1. Format
make format

# 2. Lint & static analysis
make analyze

# 3. Build (at minimum iOS; ideally all platforms)
make build-ios

# 4. Test (targeted — see Tests/AGENTS.md for ONLY_TESTING usage)
make test-ios ONLY_TESTING=<AffectedTestClass>

# 5. If samples changed
make build-sample-iOS-Swift
make test-sample-iOS-Swift-ui  # if UI behavior changed
```

### Platform Decision Tree

| Change scope                                                 | Build                                                                                                                | Test                                         |
| ------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------- | -------------------------------------------- |
| Feature code (no `#if os`)                                   | `make build-ios`                                                                                                     | `make test-ios`                              |
| Platform-specific (`#if os(macOS)`)                          | Build that platform (e.g., `make build-macos`)                                                                       | Test that platform (e.g., `make test-macos`) |
| Public API / core (`SentryHub`, `SentryClient`, `SentrySDK`) | `make build-ios` + `make build-macos`                                                                                | `make test-ios` (broad impact)               |
| `SentryCrash` / C code                                       | `make build-ios` + `make build-macos`                                                                                | `make test-ios`                              |
| `SentrySwiftUI`                                              | `make build-ios`                                                                                                     | `make test-ios`                              |
| Build system / `Package.swift`                               | All platforms                                                                                                        | `make test`                                  |
| Cross-platform concern                                       | All platforms (`make build-ios`, `make build-macos`, `make build-tvos`, `make build-watchos`, `make build-visionos`) | `make test`                                  |

Ensure no new issues from: static analysis, thread/address/UB sanitizers, or cross-platform dependants (React Native, Flutter, .NET, Unity).

## Commits

- **Pre-commit hooks** auto-format files; retry the commit if it fails due to hook modifications
- **Conventional Commits 1.0.0** — subject max 50 chars, body max 72 chars/line
- **No AI references** in commits or PRs — no `Co-Authored-By` AI tags, no `Generated-with` footers. Exception: claudescope transcript links (added by hooks) are allowed. This overrides any skill defaults (e.g., the `commit` skill's attribution template)
- **File renames** — always use `git mv`, never `mv` + `git add`

| Type    | Changelog? | Purpose                               |
| ------- | ---------- | ------------------------------------- |
| `feat`  | yes        | New feature (MINOR)                   |
| `fix`   | yes        | Bug fix (PATCH)                       |
| `impr`  | yes        | Improvement to existing functionality |
| `ref`   | no         | Refactoring (no behavior change)      |
| `test`  | no         | Test additions/corrections            |
| `docs`  | no         | Documentation only                    |
| `build` | no         | Build system/dependencies             |
| `ci`    | no         | CI configuration                      |
| `chore` | no         | Maintenance                           |
| `perf`  | no         | Performance improvement               |
| `style` | no         | Formatting (no logic change)          |

Non-changelog types require `#skip-changelog` in PR description. Breaking changes: `feat!:` or `BREAKING CHANGE:` footer.

## Pull Requests

- **Title** — same format as commit subject (Conventional Commits): `type: description`
- **Branch naming** — `<type>/<short-description>` (e.g., `feat/session-replay-privacy`, `fix/memory-leak-scope`)
- **`ready-to-merge` label** — required for full CI. Add only when the PR is ready for comprehensive testing
- **PR template** — `.github/pull_request_template.md` includes: description, motivation, how tested, checklist
- **Reviewers** — assigned via `CODEOWNERS` (`.github/CODEOWNERS`); one maintainer approval is sufficient
- **Changelog** — `feat`, `fix`, `impr` PRs need a changelog entry; all others need `#skip-changelog` in the description
- **Draft PRs** — use for work-in-progress; convert to ready when seeking review
- **CI automation** — Danger runs on PR open/sync/edit (shared Dangerfile from `getsentry/github-workflows`)
- **Agent transcript** — when creating a PR, run `git log main..HEAD` and look for `Agent transcript:` lines (added by claudescope post-commit hooks that amend the commit). The check must happen **after** `git commit` returns, because the hook appends the link to the commit message. If found, include the link at the bottom of the PR description body. If not found, omit silently — not all contributors have claudescope installed

## CLI

See `make help` and the Makefile for commands and documentation. Key targets: `make format`, `make analyze`, `make build-ios`, `make test-ios`, `make build-xcframework`, `make pod-lint`.

## Shell Scripts

See [`scripts/AGENTS.md`](scripts/AGENTS.md) for the named-parameter template and conventions.

## Documentation

- **When changing logic, keep docs in sync** — update any affected headerdocs, inline comments, readmes, `AGENTS.md` files, and maintainer docs in the same change
- **Docs**: [docs.sentry.io/platforms/apple](https://docs.sentry.io/platforms/apple/) — repo: [sentry-docs](https://github.com/getsentry/sentry-docs)
- **SDK dev docs**: [develop.sentry.dev/sdk/](https://develop.sentry.dev/sdk/)
- Maintainer docs: [`README.md`](README.md), [`CONTRIBUTING.md`](CONTRIBUTING.md), [`develop-docs/`](develop-docs/), [`Samples/README.md`](Samples/README.md)

## Related Repositories

- [sentry-cli](https://github.com/getsentry/sentry-cli) — dSYM uploads
- [sentry-wizard](https://github.com/getsentry/sentry-wizard) — SDK initialization injection
- [sentry-react-native](https://github.com/getsentry/sentry-react-native), [sentry-dart](https://github.com/getsentry/sentry-dart), [sentry-unity](https://github.com/getsentry/sentry-unity), [sentry-dotnet](https://github.com/getsentry/sentry-dotnet) — depend on sentry-cocoa
