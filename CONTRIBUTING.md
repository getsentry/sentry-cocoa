<p align="center">
  <a href="https://sentry.io" target="_blank" align="center">
    <img src="https://sentry-brand.storage.googleapis.com/sentry-logo-black.png" width="280">
  </a>
  <br />
</p>

# Contributing

Thanks for your interest in contributing to `sentry-cocoa`! This guide explains how we work with external contributions and how to get your environment set up. If you have questions, reach out on [Discord](https://discord.com/invite/sentry).

For more detailed information, see `develop-docs/README.md`.

## Submitting Changes

**TL;DR: Discuss your change in a GitHub issue before opening a pull request. We may close PRs that weren't discussed with a maintainer first.**

Every line we merge is code we maintain long-term for hundreds of thousands of apps, so we want to agree on the problem and the approach before anyone writes code. This saves time for you and for us.

### Before You Start

1. **Find or create an issue.** Search the [issue tracker](https://github.com/getsentry/sentry-cocoa/issues) first. If nothing fits, open a new issue describing the problem or feature.
2. **Discuss your approach with a maintainer.** Comment on the issue with what you plan to change and wait for a maintainer to respond before you start working.
3. **Check the assignee.** If the issue is already assigned to someone else, coordinate with them in the issue before starting work.

### Making Your Contribution

- Fork the repo and make your changes on a branch.
- Add tests. Non-trivial PRs won't be accepted without them.
- Don't bump version numbers. We do that when we release.
- Open a [draft PR](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/about-pull-requests#draft-pull-requests) that links the issue (e.g. `Fixes #123`), and mark it ready for review once CI passes.
- Name your PR according to our [commit message format](https://develop.sentry.dev/commit-messages/#commit-message-format).
- Keep PRs focused: one change per PR, no unrelated refactors.

### AI Use

You are welcome to use whatever tools you prefer for making a contribution. However, any changes you propose have to be understood, reviewed and tested by you, a human, first, before you submit a pull request with them for the Sentry team to review. If we feel like that didn't happen, we will close the PR outright. For example, we won't review visibly AI-generated PRs from an agent instructed to look for and "fix" open issues in the repo. This aligns with our SDK principle: [every line has an owner](https://develop.sentry.dev/sdk/getting-started/principles/#every-line-has-an-owner).

## Environment

Run `make init` to get started. This will install `pre-commit`, `bundler` and `Homebrew` and their managed dependencies (see `Gemfile` and `Brewfile`).

Please use `Sentry.xcworkspace` as the entry point when opening the project in Xcode. It also contains all test apps for different environments.

## PR reviews

### PR Status and Readiness

- **Pull requests which are not ready for review should stay in draft mode.** Use GitHub's draft PR feature to indicate that your PR is still work in progress and not yet ready for maintainer review.
- **Pull requests which are ready to review should be marked as such.** When your PR is ready for review, mark it as ready by converting it from draft to a regular PR.

### Review Types and Meanings

For feedback in PRs, we use the [LOGAF scale](https://develop.sentry.dev/engineering-practices/code-review/#logaf-scale) to specify how important a comment is. You only need one approval from a maintainer to be able to merge. For some PRs, asking specific or multiple people for review might be adequate.

**Understanding review feedback:**

- **PR comments are a request for change.** When a reviewer leaves comments on your PR, they are requesting changes or asking questions that need to be addressed.
- **PR approvals are a confirmation it can be merged.** An approval indicates the reviewer has reviewed your PR and confirms it's ready to be merged.

Our different types of reviews:

1. **LGTM without any comments.** You can merge immediately.
2. **LGTM with low and medium comments.** The reviewer trusts you to resolve these comments yourself, and you don't need to wait for another approval.
3. **Only comments.** You must address all the comments and need another review until you merge.
4. **Request changes.** Only use if something critical is in the PR that absolutely must be addressed. We usually use `h` comments for that. When someone requests changes, the same person must approve the changes to allow merging. Use this sparingly.

**Comment resolution workflow:**

- `h` (high) comments **must be resolved by the reviewer** who left them — the author should not self-resolve these.
- `m` (medium) and `l` (low) comments may be resolved by the PR author once they believe the concern has been appropriately addressed.

### After Addressing PR Feedback

**After addressing PR feedback, request another PR review via GitHub.** This changes the pull request status back from commented/approved to waiting, ensuring maintainers are notified that you've addressed their feedback and the PR is ready for re-review.

### PR Labels

#### `ready-for-merge` Label

The `ready-for-merge` label is used to enable CI of the pull request. **It should be set as soon as the PR is ready to be tested in CI, not before, to save CI resources.** Only add this label when your PR is actually ready for full CI testing.

#### `Waiting for: Review :hourglass:` Label

If a PR has been pending review for a while (typically several days), contributors can set the label `Waiting for: Review :hourglass:`, which will result in an internal reminder to maintainers.

**Important:** Contributors should **not** put the "Waiting for: Review :hourglass:" label on every PR, as we still have normal review processes where maintainers regularly look at open PRs. This label should only be used if PRs have not been reviewed for days and need additional attention.

## Code Formatting

Please follow the convention of removing the copyright code comments at the top of files. We only keep them inside [SentryCrash](/SentryCrash/),
as the code is based on [KSCrash](https://github.com/kstenerud/KSCrash).

All Objective-C, C and C++ needs to be formatted with [Clang Format](http://clang.llvm.org/docs/ClangFormat.html). The configuration can be found in [`.clang-format`](./.clang-format). Formatting should happen automatically as part of our precommit hook, which uses `make format`.

### GH actions suddenly formats code differently

It can be that it uses a different clang-format version, than you local computer. Please run `make init`, and ensure that your version (run `clang-format --version`) matches the one from GH actions. There is now a precommit step that ensures that the versions are synchronized, see `scripts/check-tooling-versions.sh`.

**More information:**
We always use the latest version of clang-format in homebrew in [our GH actions](https://github.com/getsentry/sentry-cocoa/blob/bdaf35331fa9dc67fc318e4a25b92cdc9b0c0ed7/.github/workflows/format-code.yml#L19-L20) for formatting the code.
As we use homebrew for setting up the development environment, homebrew only contains formulas for clang-format 8, 11, or the latest, and we want to use the latest clang-format version; we accept that we don't pin clang-format to a specific version. Using the GH action images clang-format version doesn't work, as it can be different than the one from homebrew.
This means if homebrew updates the [formula](https://formulae.brew.sh/formula/) for the default clang-format version so does our GH actions job. If the GH actions job suddenly starts to format code differently than your local make format, please compare your clang-format version with the GH actions jobs version.

## Linting

We use [Swiftlint](https://github.com/realm/SwiftLint) and Clang-Format. For SwiftLint, we keep a multiple config files for the tests and test apps, cause some rules don't make sense for testing and test app code. To run all the linters locally execute:

```sh
make lint
```

## Changelog entries and linked issues

Changelog entries are generated from merged PRs (see Danger and release tooling). If a PR should
trigger a comment on a linked issue after a release ships, use a GitHub closing keyword in the PR
description, such as `Fixes #123`, `Closes #123`, or `Resolves #123`. The release notification
workflow only comments on issues GitHub recognizes as closed by the released PR; mentioning an issue
without a closing keyword is not enough.

Each Unreleased or version block may only have one heading per section type, for example a single
`### Features` block. Duplicate section headings are rejected by `make check-changelog`.

### Changelog merge conflicts

`.gitattributes` marks `CHANGELOG.md` and `CHANGELOG_V10.md` with Git's built-in `merge=union`
driver, so a local merge or rebase keeps the entries from both sides instead of reporting a
conflict. GitHub ignores this attribute: the pull request conflict check, the **Update branch**
button, and the web conflict editor still report changelog conflicts. When a pull request only
conflicts in a changelog, update it locally and push:

```sh
git fetch origin
git merge origin/main
git push
```

`git rebase origin/main` followed by `git push --force-with-lease` works too.

The union driver keeps the lines from both sides without understanding Markdown. Check the merged
changelog: if both sides edited the same entry, it keeps both versions. `make check-changelog`
rejects duplicate section headings.
