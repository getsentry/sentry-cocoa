# AGENTS.md

Comprehensive guidance for AI coding agents working with the Sentry Cocoa SDK repository. Detailed, directory-scoped instructions live in nested `AGENTS.md` files:

| Path                                     | Scope                                                   |
| ---------------------------------------- | ------------------------------------------------------- |
| [`Tests/AGENTS.md`](Tests/AGENTS.md)     | Testing conventions, naming, code style, error handling |
| [`Sources/AGENTS.md`](Sources/AGENTS.md) | Objective-C and Swift coding conventions                |
| [`.github/AGENTS.md`](.github/AGENTS.md) | Workflow naming, concurrency strategy, file filters     |
| [`Samples/AGENTS.md`](Samples/AGENTS.md) | Sample app structure, build, and regeneration           |

## Agent Responsibilities

- **Continuous Learning**: Whenever you discover new patterns, conventions, or best practices that aren't documented here, add them to the appropriate `AGENTS.md` file (root or nested).
- **Context Management**: When using compaction, re-read the relevant `AGENTS.md` files afterwards to ensure guidelines remain in context.

## MCP Servers

This repository includes pre-configured [MCP servers](https://modelcontextprotocol.io/) in `.mcp.json`:

- **XcodeBuildMCP** — build, run, and test in the iOS simulator. Requires [Node.js](https://nodejs.org/).
- **sentry** — query production errors, search issues, and read Sentry docs. Authenticates via OAuth on first use.

You can use the `sentry` MCP server to validate that events still arrive in Sentry after your changes. Use `search_events` to find specific telemetry data, then inspect the event JSON to verify payloads match expectations.

Read-only MCP tools are pre-approved in `.claude/settings.json`. Mutating tools (build, boot, tap, launch, stop, etc.) require per-developer approval in `.claude/settings.local.json`, except for XcodeBuildMCP's `session_set_defaults` and `session_clear_defaults` tools, which are globally approved as a limited exception for managing per-session defaults.

## Compilation & Cross-Platform

Before forming a commit, ensure compilation succeeds for all platforms: iOS, macOS, tvOS, watchOS and visionOS. This should hold for:

- the SDK framework targets
- the sample apps
- the test targets for the SDK framework and sample apps

Before submitting a branch for a PR, ensure there are no new issues being introduced for:

- static analysis
- runtime analysis, using thread, address and undefined behavior sanitizers
- cross platform dependencies: React Native, Flutter, .NET, Unity

While preparing changes, ensure that relevant documentation is added/updated in:

- headerdocs and inline comments
- readmes and maintainer markdown docs
- our docs repo and web app onboarding
- our cli and integration wizard

## Commit Guidelines

### Pre-commit Hooks

This repository uses pre-commit hooks. If a commit fails because files were changed during the commit process (e.g., by formatting hooks), automatically retry the commit with the updated files.

### File Renaming and Git History Preservation

**Always preserve git history when renaming files.** Use `git mv` for renaming — never use file system operations followed by `git add`.

```bash
# Correct — preserves history
git mv old-name.swift new-name.swift

# Wrong — breaks history tracking
mv old-name.swift new-name.swift
git add new-name.swift
```

After renaming, verify that git recognizes the rename:

```bash
git status                        # Should show "renamed: old -> new"
git log --follow new-name.swift   # Should show full history including old name
```

### Conventional Commits

This project uses [Conventional Commits 1.0.0](https://www.conventionalcommits.org/).

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

**Line Length Limits:**

- **Subject line:** Maximum 50 characters (including type prefix)
- **Body lines:** Maximum 72 characters per line

**Types that appear in CHANGELOG:**

- `feat:` — A new feature (MINOR in SemVer)
- `fix:` — A bug fix (PATCH in SemVer)
- `impr:` — An improvement to existing functionality

**Other Allowed Types** (require `#skip-changelog` in PR description):

- `build:`, `chore:`, `ci:`, `docs:`, `style:`, `refactor:` (or `ref:`), `perf:`, `test:`

**Breaking Changes:** Add `!` after type/scope (`feat!:`) or use footer `BREAKING CHANGE: description`.

### No AI References

**NEVER mention AI assistant names (Claude, ChatGPT, Cursor, etc.) in commit messages or PR descriptions.** No Co-Authored-By tags, no Generated-with footers. Keep messages focused on the technical changes.

## Makefile

Prefer Makefile commands over custom shell commands. Run `make help` to see all available targets.

**Helpful Commands:**

- format code: `make format`
- run static analysis: `make analyze`
- run unit tests: `make test`
- run important UI tests: `make test-ui-critical`
- start test server (rarely needed): `make run-test-server`
- stop test server: `make stop-test-server`
- build the XCFramework deliverables: `make build-xcframework`
- build all sample apps: `make build-samples`
- regenerate sample Xcode projects: `make xcode-ci`
- lint pod deliverable: `make pod-lint`

## Shell Script Conventions

- **Use named parameters** (`--since`, `--output`) over positional parameters (`$1`, `$2`) to prevent wrong parameters being passed as scripts evolve
- **Extract complex logic** into separate scripts (e.g., Python for data processing) rather than inlining via heredocs, to enable IDE support and testing

## Resources & Documentation

- **Main Documentation**: [docs.sentry.io/platforms/apple](https://docs.sentry.io/platforms/apple/)
  - **Docs Repo**: [sentry-docs](https://github.com/getsentry/sentry-docs)
- **SDK Developer Documentation**: [develop.sentry.dev/sdk/](https://develop.sentry.dev/sdk/)

### `sentry-cocoa` Maintainer Documentation

- **README**: @README.md
- **Contributing**: @CONTRIBUTING.md
- **Developer README**: @develop-docs/README.md
- **Sample App collection README**: @Samples/README.md

## Related Repositories

- [sentry-cli](https://github.com/getsentry/sentry-cli): uploading dSYMs for symbolicating stack traces
- [sentry-wizard](https://github.com/getsentry/sentry-wizard): automatically injecting SDK initialization code
- [sentry-cocoa onboarding](https://github.com/getsentry/sentry/blob/master/static/app/utils/gettingStartedDocs/apple.tsx): web app onboarding instructions
- [sentry-unity](https://github.com/getsentry/sentry-unity): depends on sentry-cocoa
- [sentry-dart](https://github.com/getsentry/sentry-dart): depends on sentry-cocoa
- [sentry-react-native](https://github.com/getsentry/sentry-react-native): depends on sentry-cocoa
- [sentry-dotnet](https://github.com/getsentry/sentry-dotnet): depends on sentry-cocoa
