# .github — Agent Instructions

## Workflow Naming Convention

### Workflow Names (Top-level `name:` field)

Use concise, action-oriented names: `[Action] [Subject]`

- `Release` (not "Release a new version")
- `UI Tests` (not "Sentry Cocoa UI Tests")
- `Benchmarking` (not "Run benchmarking tests")
- `Lint SwiftLint` (not "Lint Swiftlint Formatting")
- `Test CocoaPods` (not "CocoaPods Integration Test")

### Job Names (Job-level `name:` field)

1. **Remove redundant prefixes** — Don't repeat the workflow name
2. **Use action verbs** — Start with what the job does
3. **Avoid version-specific naming** — Don't include Xcode versions, tool versions, etc.
4. **Keep it concise** — Maximum 3-4 words when possible

#### Build Jobs

- `Build XCFramework Slice`
- `Build App and Test Runner`
- `${{matrix.sdk}}` for platform-specific builds (e.g., "iphoneos", "macosx")
- `${{inputs.name}}${{inputs.suffix}}` for variant assembly (e.g., "Sentry-Dynamic")

#### Test Jobs

- `Test ${{matrix.name}} V3 # Up the version with every change to keep track of flaky tests`
- `Unit ${{matrix.name}}`
- `Run Benchmarks ${{matrix.suite}}`

Version numbers (V1, V2, etc.) are included in test job names for flaky test tracking, with explanatory comments retained.

#### Validation Jobs

- `Validate XCFramework`
- `Validate SPM Static`
- `Check API Stability`

#### Lint Jobs

- `Lint` (job name when workflow already specifies the tool, e.g., "Lint SwiftLint")

#### Utility Jobs

- `Collect App Metrics`
- `Detect File Changes`
- `Release New Version`

### Version Tracking for Flaky Test Management

Include the version number in BOTH the job name AND a comment:

```yaml
name: Test iOS Swift V5 # Up the version with every change to keep track of flaky tests
```

Version numbers must be in the job name because failure rate monitoring captures job names and ignores comments.

### Matrix Variables in Names

Use descriptive names over technical details:

- `Test ${{matrix.name}}` where name = "iOS Objective-C", "tvOS Swift"
- `Unit ${{matrix.name}}` where name = "iOS 16 Sentry", "macOS 15 Sentry"
- `Run Benchmarks ${{matrix.suite}}` where suite = "High-end device", "Low-end device"

### Reusable Workflow Names

- `Build XCFramework Slice`
- `Assemble XCFramework Variant`
- `UI Tests Common`

### Anti-Patterns

Don't include tool versions (Xcode 15.4, Swift 5.9, etc.) unless relevant, redundant workflow prefixes, overly verbose descriptions, or technical implementation details in user-facing names.

## Concurrency Strategy

### Core Principles

- **Cancel outdated PR runs** — When new commits are pushed to a PR, cancel the previous run
- **Protect critical runs** — Never cancel workflows on main, release branches, or scheduled runs
- **Per-branch grouping** — Use `github.ref` for consistent concurrency grouping

### Pattern 1: Conditional Cancellation (Most Common)

Used by most workflows that run on both main/release branches AND pull requests:

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}
```

### Pattern 2: Always Cancel (PR-Only Workflows)

Used by workflows that ONLY run on pull requests:

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

### Pattern 3: Fixed Group Name (Special Cases)

Used by utility workflows with specific requirements:

```yaml
concurrency:
  group: "auto-update-tools"
  cancel-in-progress: true
```

### Group Naming

Use `${{ github.workflow }}-${{ github.ref }}` — simpler than `github.head_ref || github.run_id`, consistent behavior, per-branch grouping without special cases.

### Documentation Requirements

Each workflow's concurrency block must include comments explaining: purpose, resource considerations, branch protection logic, and user experience impact.

```yaml
# Concurrency configuration:
# - We use workflow-specific concurrency groups to prevent multiple benchmark runs on the same code,
#   as benchmarks are extremely resource-intensive and require dedicated device time on SauceLabs.
# - For pull requests, we cancel in-progress runs when new commits are pushed to avoid wasting
#   expensive external testing resources and provide timely performance feedback.
# - For main branch pushes, we never cancel benchmarks to ensure we have complete performance
#   baselines for every main branch commit, which are critical for performance regression detection.
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}
```

## File Filters Configuration

### Core Principles

1. **Complete Coverage** — Every directory with code, tests, or configuration affecting CI should appear in at least one filter pattern
2. **Logical Grouping** — Group files with workflows they logically affect (source changes → build/test, test changes → test, config changes → validation, script changes → workflows using those scripts)
3. **Hierarchy Awareness** — Use `**` to capture all subdirectories recursively

### Pattern Best Practices

**Use `**` for recursive matching:\*\*

```yaml
# Good
- "Sources/**"
- "Tests/**"

# Bad
- "Sources/*" # Only one level deep
- "Tests/" # Doesn't match files
```

**Be specific when needed:**

```yaml
# Good
- "Samples/iOS-Cocoapods-*/**"
- "**/*.xctestplan"
- "scripts/ci-*.sh"

# Bad
- "Samples/**" # Too broad
- "**/*" # Matches everything
```

**Always include related configuration:**

```yaml
run_unit_tests_for_prs: &run_unit_tests_for_prs
  - "Sources/**"
  - "Tests/**"
  - ".github/workflows/test.yml"
  - ".github/file-filters.yml"
  - "Sentry.xcodeproj/**"
  - "Sentry.xcworkspace/**"
```

### Common Patterns by Workflow Type

#### Unit Test Workflows

```yaml
run_unit_tests_for_prs: &run_unit_tests_for_prs
  - "Sources/**"
  - "Tests/**"
  - "SentryTestUtils/**"
  - "SentryTestUtilsDynamic/**"
  - "SentryTestUtilsTests/**"
  - "3rd-party-integrations/**"
  - ".github/workflows/test.yml"
  - ".github/file-filters.yml"
  - "scripts/ci-*.sh"
  - "test-server/**"
  - "**/*.xctestplan"
  - "Plans/**"
  - "Sentry.xcodeproj/**"
```

#### Lint Workflows

```yaml
run_lint_swift_formatting_for_prs: &run_lint_swift_formatting_for_prs
  - "**/*.swift"
  - ".github/workflows/lint-swift-formatting.yml"
  - ".github/file-filters.yml"
  - ".swiftlint.yml"
  - "scripts/.swiftlint-version"
```

#### Build Workflows

```yaml
run_build_for_prs: &run_build_for_prs
  - "Sources/**"
  - "Samples/**"
  - ".github/workflows/build.yml"
  - ".github/file-filters.yml"
  - "Sentry.xcodeproj/**"
  - "Package*.swift"
  - "scripts/sentry-xcodebuild.sh"
```

### Verification Checklist

Before submitting a PR that affects project structure:

- [ ] List all new or renamed directories
- [ ] Check if each directory appears in `.github/file-filters.yml`
- [ ] Add missing patterns to appropriate filter groups
- [ ] Verify glob patterns match intended files

### Troubleshooting

**PR Not Triggering Expected Workflows:**

1. Check the paths-filter configuration in the workflow
2. Verify the filter name matches between `file-filters.yml` and workflow (`if: steps.changes.outputs.run_unit_tests_for_prs == 'true'`)
3. Test the pattern locally using glob matching tools

**Pattern Not Matching Expected Files:**

- Missing `**` for recursive matching
- Using `*` instead of `**` for deep directories
- Forgetting to include file extensions
- Pattern too broad or too narrow

### Maintenance

- Periodically review file-filters.yml to remove patterns for deleted directories, update for renamed directories, and ensure new directories are covered
- Each filter group should have comments explaining purpose, which workflow uses it, and special considerations
