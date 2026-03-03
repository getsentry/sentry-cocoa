# .github

> Instructions for LLM agents. Keep edits minimal (headers + bullets). Use `/agents-md` skill when editing.

## Workflow Naming

**Workflow names** — concise, action-oriented: `[Action] [Subject]`

- `Release`, `UI Tests`, `Benchmarking`, `Lint SwiftLint`, `Test CocoaPods`

**Job names** — no redundant prefixes, use action verbs, max 3-4 words, no tool versions:

| Category | Examples                                                                |
| -------- | ----------------------------------------------------------------------- |
| Build    | `Build XCFramework Slice`, `${{matrix.sdk}}`                            |
| Test     | `Test ${{matrix.name}} V3 # Up the version...`, `Unit ${{matrix.name}}` |
| Validate | `Validate XCFramework`, `Check API Stability`                           |
| Lint     | `Lint` (when workflow name already specifies tool)                      |
| Utility  | `Collect App Metrics`, `Detect File Changes`                            |

### Flaky Test Tracking

Version number in BOTH job name AND comment (monitoring captures names, ignores comments):

```yaml
name: Test iOS Swift V5 # Up the version with every change to keep track of flaky tests
```

## Concurrency

### Pattern 1: Conditional (most common)

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}
```

Cancels PR runs on new push. Never cancels main/release/schedule.

### Pattern 2: Always Cancel (PR-only workflows)

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

### Pattern 3: Fixed Group (special cases)

```yaml
concurrency:
  group: "auto-update-tools"
  cancel-in-progress: true
```

Each concurrency block must include comments explaining purpose, resource considerations, and branch protection logic.

## File Filters (`file-filters.yml`)

- Every directory with code/tests/config must appear in at least one filter
- Use `**` for recursive matching (`Sources/**`, not `Sources/*`)
- Include related workflow and config files in each filter group

### Templates

```yaml
# Unit tests
run_unit_tests_for_prs:
  - "Sources/**"
  - "Tests/**"
  - "SentryTestUtils/**"
  - "SentryTestUtilsDynamic/**"
  - "SentryTestUtilsTests/**"
  - ".github/workflows/test.yml"
  - ".github/file-filters.yml"
  - "scripts/ci-*.sh"
  - "test-server/**"
  - "**/*.xctestplan"
  - "Plans/**"
  - "Sentry.xcodeproj/**"
```

```yaml
# Lint
run_lint_swift_formatting_for_prs:
  - "**/*.swift"
  - ".github/workflows/lint-swift-formatting.yml"
  - ".github/file-filters.yml"
  - ".swiftlint.yml"
```

```yaml
# Build
run_build_for_prs:
  - "Sources/**"
  - "Samples/**"
  - ".github/workflows/build.yml"
  - ".github/file-filters.yml"
  - "Sentry.xcodeproj/**"
  - "Package*.swift"
```

### When changing project structure

1. List all new/renamed directories
2. Check each against `file-filters.yml`
3. Add missing patterns to appropriate filter groups
