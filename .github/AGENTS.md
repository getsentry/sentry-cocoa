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

## File Filters

- Update `.github/file-filters.yml` when directories, workflows, plans, project files, or relevant configuration change
- Ensure every code, test, and configuration directory is covered by at least one filter
- Use recursive patterns such as `Sources/**`, not `Sources/*`
- Include the workflow and configuration files that can change each filtered job
