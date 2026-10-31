# GitHub Configuration

> Scope: `.github/**`. Also follow [root instructions](../AGENTS.md).

## Workflow Naming

- Use concise action-oriented workflow names such as `Release`, `UI Tests`, or `Test CocoaPods`
- Use action verbs for job names, avoid redundant workflow prefixes, and omit tool versions
- Keep job names to three or four words when practical
- Increment flaky-test tracking versions in both the job name and its adjacent comment

## Concurrency

Use conditional cancellation unless the workflow is pull-request-only:

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}
```

- Pull-request-only workflows may use `cancel-in-progress: true`
- Fixed groups are reserved for singleton automation such as tool updates
- Explain cancellation behavior, resource constraints, and branch-protection implications in comments

## Background Steps and Ordering

Follow [CI dependency ordering](../develop-docs/CI.md#background-steps-and-dependency-ordering).

- Schedule only work the job requires and preserve existing launch conditions. Examples involving Ruby, caches, artifacts, or simulators do not require adding them to other jobs
- Start required independent downloads and cache restores as soon as their prerequisites exist
- Place targeted `wait` steps immediately before the first consumer, including consumers of background outputs or environment changes
- Distinguish CoreSimulator service warmup from device boot. Join boot immediately before tests, not before independent setup or compilation
- Keep Xcode selection stable during compiler work, runtime recovery ahead of simulator use, and Homebrew mutations sequential
- For jobs that require CI services, use native `background` and `cancel` with a separate readiness check instead of waiting for service exit
- Upload only completed, immutable artifacts in parallel and join before diagnostics
- Use `# === <SECTION> ===` comments to distinguish preparation, dependency joins, execution, and artifact collection
- After reordering, verify dependency boundaries and check for drift in job settings, conditions, commands, and artifacts. Validate performance changes with traces and full CI

## File Filters

- Update `.github/file-filters.yml` when directories, workflows, plans, project files, or relevant configuration change
- Ensure every code, test, and configuration directory is covered by at least one filter
- Use recursive patterns such as `Sources/**`, not `Sources/*`
- Include the workflow and configuration files that can change each filtered job
