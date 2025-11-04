# SDK Releases

This repo uses the following ways to release SDK updates:

- `Pre-release`: We create pre-releases (alpha, beta, RC,…) for larger and potentially more impactful changes, such as new features or major versions.
- `Latest`: We continuously release major/minor/hotfix versions from the `main` branch. These releases go through all our internal quality gates and are very safe to use and intended to be the default for most teams.
- `Stable`: We promote releases from `Latest` when they have been used in the field for some time and in scale, considering time since release, adoption, and other quality and stability metrics. These releases will be indicated on the [releases page](https://github.com/getsentry/sentry-cocoa/releases/) with the `Stable` suffix.

## Promoting a beta release to a normal release

We frequently release a beta version of our SDK and dogfood it with internal apps to increase our SDK stability. We continue to merge PRs to the main branch, so we can't promote a beta release by publishing it from the main branch. Instead, we create a branch from the GH tag of the beta release and promote it from there. To do this, follow these steps:

1. Checkout a new branch from the GH tag of the beta release: `git checkout -b publish/x.x.x x.x.x-beta.1`. You can't use `release/x.x.x` or `x.x.x` as the branch name as craft will fail, as it creates a `release/x.x.x` branch for updating the changelog and it will create a tag `x.x.x` for the release.
2. Duplicate the Changelog.md entry of the beta release and change header of the version number to unreleased.
3. Commit and push the changes.
4. Trigger the release workflow with use workflow from the `publish/x.x.x` branch and set the target branch to merge into to `publish/x.x.x`, cause per default craft will merge into the main branch and this could lead to merge conflicts in the changelog.
5. After the successful release, validate that craft merged the changes back into `publish/x.x.x` branch and deleted the release branch.
6. Manually open a PR from the `publish/x.x.x` branch into the main branch and merge it.

## Releasing V8

As of Oct 1st 2025, the [main branch](https://github.com/getsentry/sentry-cocoa/tree/main) is for v9 and the branch [v8.x](https://github.com/getsentry/sentry-cocoa/tree/v8.x) is for v8.

To continue supporting users on version 8, we have created a dedicated v8 branch. This is the first time in the SDK’s history that we’ve maintained a legacy branch. Since v8 was released over two years ago, and with new features like Session Replay shipped this year, we know some important customers still require bugfixes on v8 before moving to v9. Maintaining a separate branch allows us to deliver those fixes without complicating the v9 release process.

When releasing v8, we must to specify the `Target branch to merge into` for Craft via the GH action, because otherwise Craft merges v8 into main.
