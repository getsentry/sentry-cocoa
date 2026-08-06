# Repository Mirroring

sentry-cocoa mirrors code and release artifacts to downstream repositories so consumers can depend on them via SPM without pulling unnecessary third-party dependencies. There are two distinct mechanisms: **continuous code sync** (on every push to main) and **release-time distribution** (via Craft).

For the motivation behind this approach, see [INTEGRATIONS.md](INTEGRATIONS.md) and [DECISIONS.md (decision #31)](DECISIONS.md#3rd-party-library-integrations).

## Downstream Repositories

| Source in sentry-cocoa                          | Downstream repo                          | Continuous sync | Release (Craft) |
| ----------------------------------------------- | ---------------------------------------- | --------------- | --------------- |
| `3rd-party-integrations/SentrySwiftLog/`        | `getsentry/sentry-apple-swift-log`       | yes             | yes             |
| `3rd-party-integrations/SentryCocoaLumberjack/` | `getsentry/sentry-apple-cocoalumberjack` | yes             | yes             |
| `3rd-party-integrations/SentryPulse/`           | `getsentry/sentry-apple-pulse`           | yes             | yes             |
| `3rd-party-integrations/SentrySwiftyBeaver/`    | `getsentry/sentry-apple-swiftybeaver`    | yes             | yes             |
| `distribution/apple-binaries/`                  | `getsentry/sentry-apple-binaries`        | no              | yes             |

## Continuous Code Sync

**Workflow:** [`.github/workflows/mirror-3rd-party-integrations.yml`](../.github/workflows/mirror-3rd-party-integrations.yml)

Triggers on every push to `main` that touches `3rd-party-integrations/**`. For each integration in the matrix:

1. Checks out sentry-cocoa and the downstream repo.
2. Wipes the downstream repo (except `.git`).
3. Copies the integration directory contents plus root `LICENSE.md`.
4. Commits as `sentry-mobile-updater[bot]` and pushes.

This keeps downstream repos up to date between releases, so consumers on the `main` branch always have the latest code.

### Authentication

The workflow uses the **sentry-mobile-updater** GitHub App (`SENTRY_DEPENDENCY_UPDATER_GITHUB_APP_ID` / `SENTRY_DEPENDENCY_UPDATER_GITHUB_APP_PRIVATE_KEY`) to generate a scoped token for each downstream repo.

## Release-Time Distribution (Craft)

**Config:** [`.craft.yml`](../.craft.yml)

During a release, the [release workflow](../.github/workflows/release.yml):

1. Builds XCFrameworks.
2. Creates `.tgz` archives via [`scripts/create-apple-binaries-archive.sh`](../scripts/create-apple-binaries-archive.sh) and [`scripts/create-3rd-party-integration-archive.sh`](../scripts/create-3rd-party-integration-archive.sh).
3. Craft pushes each archive to its downstream repo on the `main` branch and creates a Git tag matching the release version.

Craft authenticates via the GitHub org's own rules — no additional repo-level setup is needed for release pushes.

## Adding a New Downstream Mirror

### For 3rd-party integrations

1. **Create the downstream repo** under `getsentry/` (e.g., `getsentry/sentry-apple-<name>`).
2. **Allow sentry-mobile-updater** — in the downstream repo, go to `https://github.com/getsentry/<REPO_NAME>/settings/rules/` and add `sentry-mobile-updater` to the allowed apps section in the branch ruleset. This is required for the continuous sync workflow to push commits.
3. **Add to the mirror workflow matrix** in [`.github/workflows/mirror-3rd-party-integrations.yml`](../.github/workflows/mirror-3rd-party-integrations.yml).
4. **Add a Craft target** in [`.craft.yml`](../.craft.yml) with a `commit-on-git-repository` entry matching the archive name.
5. **Add the archive mapping** in [`scripts/create-3rd-party-integration-archive.sh`](../scripts/create-3rd-party-integration-archive.sh).

### For binary distribution repos (e.g., sentry-apple-binaries)

Only a Craft target is needed — there is no continuous sync for binary artifacts. Craft authenticates through the GitHub org's rules, so no additional repo-level permission changes are required.
