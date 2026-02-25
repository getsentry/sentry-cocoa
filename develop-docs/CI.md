# CI inner working

## `ready-to-merge` label

CI checks are great, but macOS runners are limited on every provider, because of this, we need to be smarter on how we run jobs.
To avoid running many jobs on every PR's commit, we have decided to only run a subset of tests regularily and run the full suite only when the PR has the label `ready-to-merge`.

### How to use the gate

Add this job at the start the workflow and then add `need: ready-to-merge-gate` to jobs that you want to be skipped.

```
ready-to-merge-gate:
  name: Ready-to-merge gate
  uses: ./.github/workflows/ready-to-merge-workflow.yml
```

This job will:

- Pass if the event is not a PR
- Fail if the event is a PR and is missing the `ready-to-merge` label
- Pass if the event is a PR and is has the `ready-to-merge` label

## Cirrus Labs Runners

We use [Cirrus Labs](https://cirrus-runners.app/) macOS runners for most of our CI jobs instead of the default GitHub-hosted macOS runners. The runner image is specified as a container reference (e.g., `ghcr.io/cirruslabs/macos-runner:sequoia`), paired with a `runner_group_id` label.

### Why Cirrus Labs?

Cirrus Labs provides Apple Silicon M4 machines, whereas GitHub-hosted macOS runners use M1 Macs. The newer hardware means our tests run faster, and we have observed better stability with fewer flaky test runs and timeouts compared to GitHub-hosted runners.

### `runner_group_id`

The `runner_group_id` label routes the job to a specific runner group within our Cirrus Labs organization. We use `runner_group_id:10`, which corresponds to the runner group configured for the `sentry-cocoa` repository. This ensures our jobs land on runners provisioned with the right resources and configuration for our workloads.

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
