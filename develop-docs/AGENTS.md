# develop-docs

> Instructions for LLM agents. Keep edits minimal (headers + bullets). Use `/agents-md` skill when editing.

Internal developer documentation for SDK maintainers.

## Directory Contents

| File                         | Purpose                                                                     |
| ---------------------------- | --------------------------------------------------------------------------- |
| `ARCHITECTURE.md`            | High-level SDK architecture: core components, feature areas, integrations   |
| `BUILD.md`                   | Build configuration: XCConfig, UIKit linking, `make` targets, visionOS, SPM |
| `CI.md`                      | CI setup: `ready-to-merge` label, Cirrus Labs runners                       |
| `DECISIONS.md`               | ADR-style decision log with context, rationale, and PR links                |
| `INTEGRATIONS.md`            | 3rd-party integrations (CocoaLumberjack, SwiftLog): layout, release flow    |
| `RELEASE.md`                 | Release process: pre-release, stable, promoting betas                       |
| `SDK_HISTORY.md`             | Historical context and FAQ                                                  |
| `SWIFT.md`                   | Swift/ObjC interop: bridging, `_SentryPrivate`, module setup                |
| `TEST.md`                    | Testing: sample apps, unit/UI tests, sanitizers, test plans, benchmarks     |
| `VIEW_MASKING_STRATEGIES.md` | View masking for screenshots/session replay                                 |
| `OBJC-LOAD-AND-LINKING.md`   | ObjC `+load` behavior across distribution formats                           |
| `Fishhook-Explanation.md`    | Fishhook Mach-O symbol rebinding mechanism                                  |

## Conventions

- **File naming** — `UPPERCASE_SNAKE_CASE.md`
- **Index** — `README.md` links to all docs; update it when adding new files
- **Decision records** — use `DECISIONS.md` with date, contributors, context, rationale, and links to PRs/issues
- **Cross-references** — link to other docs and source paths rather than duplicating content
- **Callouts** — use GitHub-style: `[!NOTE]`, `[!WARNING]`, `[!CAUTION]`

## When to Update

- **Architecture changes** → update `ARCHITECTURE.md`
- **New build config or platform** → update `BUILD.md`
- **Significant design decisions** → add entry to `DECISIONS.md`
- **Release process changes** → update `RELEASE.md`
- **New integration** → update `INTEGRATIONS.md`
