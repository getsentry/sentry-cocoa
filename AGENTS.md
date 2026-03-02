# AGENTS.md

Sentry Cocoa SDK — multi-platform Apple SDK (iOS, macOS, tvOS, watchOS, visionOS).

These instructions are written for **LLM agents**, not humans. Keep content minimal (headers + bullets, no prose). When editing any `AGENTS.md` file, use the `agents-md` skill (see `.agents/skills/agents-md/SKILL.md`).

## Nested Instructions

| Path                                     | Scope                                      |
| ---------------------------------------- | ------------------------------------------ |
| [`Tests/AGENTS.md`](Tests/AGENTS.md)     | Testing conventions, naming, code style    |
| [`Sources/AGENTS.md`](Sources/AGENTS.md) | ObjC/Swift coding conventions              |
| [`.github/AGENTS.md`](.github/AGENTS.md) | Workflow naming, concurrency, file filters |
| [`Samples/AGENTS.md`](Samples/AGENTS.md) | Sample app structure and build             |
| [`scripts/AGENTS.md`](scripts/AGENTS.md) | Shell script conventions and template      |
| [`REVIEWS.md`](REVIEWS.md)               | Code review priorities and SDK concerns    |

## Skills & MCP (dotagents)

Agent skills and MCP servers are managed by [dotagents](https://github.com/getsentry/dotagents) via `agents.toml`.

```bash
npx @sentry/dotagents install   # install skills after cloning
npx @sentry/dotagents update    # update to latest versions
npx @sentry/dotagents list      # show installed skills
```

### MCP Servers

Declared in `agents.toml`, generated into `.mcp.json` and `.cursor/mcp.json`:

- **XcodeBuildMCP** — build, run, test in simulator (requires Node.js)
- **sentry** — query production errors, search issues, read docs (OAuth on first use)

Read-only tools pre-approved in `.claude/settings.json`. Mutating tools require per-developer approval in `.claude/settings.local.json`.

## Command Execution

- **Set the working directory once** with `cd`, then run commands directly — do not prefix every command with `cd <path> &&`
- **Wildcard permissions** — many commands are pre-approved with wildcards (e.g., `git add:*`). Flags like `-C` change the command prefix (`git -C path add` ≠ `git add`), triggering a confirmation prompt. Avoid `-C` when you can `cd` instead
- **Prefer small, focused commands** over one massive pipeline. Break complex operations into multiple steps
- **JSON processing** — always use `jq`; do not shell out to `node` or `python` for JSON parsing

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
```

Ensure no new issues from: static analysis, thread/address/UB sanitizers, or cross-platform dependants (React Native, Flutter, .NET, Unity).

## Commits

- **Pre-commit hooks** auto-format files; retry the commit if it fails due to hook modifications
- **Conventional Commits 1.0.0** — subject max 50 chars, body max 72 chars/line
- **No AI references** in commits or PRs — no Co-Authored-By tags, no Generated-with footers
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

## CLI

| Command                  | Description                       |
| ------------------------ | --------------------------------- |
| `make help`              | List all targets                  |
| `make format`            | Format all code                   |
| `make analyze`           | Static analysis                   |
| `make test`              | All platform tests                |
| `make test-ios`          | iOS tests (fastest)               |
| `make test-ui-critical`  | Important UI tests                |
| `make build-ios`         | Build for iOS                     |
| `make build-xcframework` | Build XCFramework deliverables    |
| `make build-samples`     | Build all sample apps             |
| `make xcode-ci`          | Regenerate sample Xcode projects  |
| `make pod-lint`          | Lint pod deliverable              |
| `make run-test-server`   | Start test server (rarely needed) |
| `make stop-test-server`  | Stop test server                  |

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
