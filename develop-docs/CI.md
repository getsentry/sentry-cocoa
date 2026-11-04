# CI inner working

## `run-full-ci` label

CI checks are great, but macOS runners are limited on every provider, because of this, we need to be smarter on how we run jobs.
To avoid running many jobs on every PR's commit, we have decided to only run a subset of tests regularily and run the full suite only when the PR has the label `run-full-ci`.

### How to use the gate

Add this job at the start the workflow and then add `need: run-full-ci-gate` to jobs that you want to be skipped.

```
run-full-ci-gate:
  name: run-full-ci gate
  uses: ./.github/workflows/run-full-ci-workflow.yml
```

This job will:

- Pass if the event is not a PR
- Fail if the event is a PR and is missing the `run-full-ci` label
- Pass if the event is a PR and is has the `run-full-ci` label

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

## Cirrus Labs Runners

We use [Cirrus Labs](https://cirrus-runners.app/) macOS runners for most of our CI jobs instead of the default GitHub-hosted macOS runners. The runner image is specified as a container reference (e.g., `ghcr.io/cirruslabs/macos-runner:sequoia`), paired with a `runner_group_id` label.

### Why Cirrus Labs?

Cirrus Labs provides Apple Silicon M4 machines, whereas GitHub-hosted macOS runners use M1 Macs. The newer hardware means our tests run faster, and we have observed better stability with fewer flaky test runs and timeouts compared to GitHub-hosted runners.

### `runner_group_id`

The `runner_group_id` label routes the job to a specific runner group within our Cirrus Labs organization. We use `runner_group_id:10`, which corresponds to the runner group configured for the `sentry-cocoa` repository. This ensures our jobs land on runners provisioned with the right resources and configuration for our workloads.

The group id `10` has been assigned by our security team during the initial runner setup.

### Usage

For workflows that hardcode the runner, use the array syntax:

```yaml
runs-on: ["ghcr.io/cirruslabs/macos-runner:sequoia", "runner_group_id:10"]
```

For reusable workflows that support both GitHub-hosted and Cirrus Labs runners, the `run_on_cirrus_labs` input flag controls which runner is used:

```yaml
runs-on: ${{ inputs.run_on_cirrus_labs && fromJSON(format('["ghcr.io/cirruslabs/macos-runner:{0}", "runner_group_id:10"]', inputs.runs-on)) || inputs.runs-on }}
```

When `run_on_cirrus_labs` is `true`, this constructs the Cirrus Labs runner label array dynamically using the macOS version from the `runs-on` input. When `false`, it falls back to the standard GitHub-hosted runner label.
