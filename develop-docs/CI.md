# CI inner working

## PR CI eligibility

PR-triggered workflows use a shared gate to conserve runner capacity:

- Draft PRs run CI only when labeled `run-full-ci`.
- Ready-for-review PRs run CI unless labeled `run-no-ci`.
- If both labels are present, draft PRs run CI and ready-for-review PRs skip it.
- Non-PR events proceed with their existing conditions.

The gate reads current PR state for pull request, pull request target, and PR review events. Skipping CI succeeds, and existing changed-file filters still apply when CI is enabled. The Label PR workflow also runs on draft conversion to remove stale review-status labels.

### How to use the gate

Add the shared gate and check its output on root jobs:

```yaml
jobs:
  run-full-ci-gate:
    name: CI eligibility
    uses: ./.github/workflows/run-full-ci-workflow.yml

  files-changed:
    needs: run-full-ci-gate
    if: needs.run-full-ci-gate.outputs.run_ci == 'true'
    # Existing job configuration follows.
```

Downstream jobs retain their existing dependencies. Required-check jobs using `always()` must also depend directly on the gate so they report gate failures while accepting intentionally skipped jobs.

PR triggers must include `opened`, `synchronize`, `reopened`, `labeled`, `unlabeled`, `ready_for_review`, and `converted_to_draft`, plus any workflow-specific event types. This reevaluates eligibility after label and draft-state changes.

## Background Steps and Dependency Ordering

Apply these scheduling rules only to work the job requires, preserving its launch conditions. Examples involving Ruby, caches, artifact downloads, or simulators do not require introducing those operations into other jobs.

Use [native GitHub Actions background steps](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#jobsjob_idstepsbackground) to overlap independent work. Start each required operation as soon as its prerequisites exist and place its targeted `wait` immediately before the first consumer. A background step's outputs, environment changes, and failure result become available at the join.

### Independent Preparation

- For jobs that consume downloaded artifacts, start those downloads after checkout so checkout cleanup cannot remove their files. Join before extraction, cache seeding, or the first build that consumes them.
- For jobs that require Ruby and use a Ruby cache, restore the cache alongside independent preparation. Join before reading `cache-hit` or installing Ruby.
- When dependency installation invokes a compiler, select Xcode first and keep it stable during that work. Ruby installation and native-gem compilation are examples.
- For jobs that use Homebrew, keep package mutations sequential. For example, Ruby setup that upgrades packages must not overlap `make init-ci-build`.
- Upload completed, immutable artifacts while other work continues. Join before diagnostics so upload failures are visible. Keep uploads separate from operations that still modify their source files.

Use `# === <SECTION> ===` comments to separate independent preparation, dependency joins, builds/tests, and artifact collection. See the [unit-test workflow](../.github/workflows/unit-test-common.yml) and [UI-test workflow](../.github/workflows/ui-tests-common.yml) for examples.

### Simulator Dependencies

CoreSimulator **warmup** lists runtimes to initialize runtime discovery and services. It does not boot a device. **Boot** starts a specific device and validates its readiness.

For jobs that run simulator tests, schedule the applicable operations in this dependency order:

1. If service warmup is used, start it alongside checkout and any required independent downloads/cache restores.
2. If warmup was started, join it before Xcode setup performs runtime discovery, then resolve the destination.
3. When explicit background device boot is needed, complete any required runtime recovery first.
4. Overlap boot with independent work the job requires, such as dependency installation, project generation, or test compilation.
5. Join any background boot immediately before tests or consumers of boot outputs.

Build-only jobs that use CoreSimulator warmup and `resolve-simulators: false` select Xcode before launching warmup. Overlap any required dependency installation or project preparation with warmup, deferring its join until the build.

> [!WARNING]
> Runtime recovery can force-unmount simulator volumes and restart CoreSimulator services. Finish recovery before booting devices or starting simulator-dependent work. Do not switch the selected Xcode while compiler or `xcrun` work is in flight.

### Long-Running Services

For jobs that require a long-running service, run its executable in the foreground of a native `background: true` step so the runner owns its lifecycle. Check service readiness before its first consumer, then use a targeted `cancel` after its last consumer. For example, test-server jobs check HTTP readiness before tests and cancel the server afterward. A `wait` on the server would wait for its exit, not readiness, and an implicit end-of-job join would block cleanup if the server remained running.

Native `wait` and `cancel` control steps run even after failures and do not accept `if`. Keep launch conditions on the background steps and leave their control steps unconditional. Use targeted joins rather than `wait-all` when a long-running service is active.

### Verification and Timing

Validate workflow changes with actionlint and the configured pre-commit workflow-schema checks. After reordering, compare workflow/job settings, matrices, permissions, launch conditions, commands, environment, and artifact configuration against the original. Check that every join follows its launch and precedes consumers of deferred outputs or environment changes.

For CI performance changes, use traces from `sentry/sentry-github-action-ci-data` to identify serial waits and record a baseline. Verify behavior in a draft PR with `run-full-ci`, then compare equivalent jobs before claiming a speedup. Keep measured improvements distinct from expected overlap.

## macOS Runners

macOS jobs run on GitHub-hosted runners. Pick the label by the Xcode major the job selects:

| Xcode | Runner label |
| ----- | ------------ |
| 16    | `macos-15`   |
| 26    | `macos-26`   |
| 27    | `xcode-27`   |

Use the `-xlarge` variant, such as `xcode-27-xlarge`, only for jobs that need more CPU or memory.

A few jobs need an OS or simulator runtime that GitHub-hosted images don't provide, so they stay on Bitrise runners with a `bitrise_pool_name:<pool>` label:

- macOS 14 and Catalyst 14 unit tests use `bitrise_pool_name:sonoma`, because GitHub retired its macOS 14 runners.
- The iOS 17 UI tests use `bitrise_pool_name:sequoia`, because `macos-15` doesn't ship the iOS 17.5 simulator runtime.

List every Bitrise label in `.github/actionlint.yaml`. `unit-test-common.yml` and `ui-tests-common.yml` take the full runner label and install Ruby with rbenv on Bitrise runners, where `ruby/setup-ruby` doesn't work.
