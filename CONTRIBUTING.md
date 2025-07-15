<p align="center">
  <a href="https://sentry.io" target="_blank" align="center">
    <img src="https://sentry-brand.storage.googleapis.com/sentry-logo-black.png" width="280">
  </a>
  <br />
</p>

# Contributing

We welcome suggested improvements and bug fixes for `sentry-cocoa`, in the form of pull requests. To get early feedback, we recommend opening up a [draft PR](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/about-pull-requests#draft-pull-requests). Please follow our official [Commit Guidelines](https://develop.sentry.dev/code-review/#commit-guidelines) and also prefix the title of your PR according to the [Commit Guidelines](https://develop.sentry.dev/code-review/#commit-guidelines). The guide below will help you get started, but if you have further questions, please feel free to reach out on [Discord](https://discord.gg/Ww9hbqr).

For more detailed information, see `develop-docs/README.md`.

## Environment

Run `make init` to get started. This will install `pre-commit`, `bundler` and `Homebrew` and their managed dependencies (see `Gemfile` and `Brewfile`).

Please use `Sentry.xcworkspace` as the entry point when opening the project in Xcode. It also contains all samples for different environments.

## PR reviews

For feedback in PRs, we use the [LOGAF scale](https://develop.sentry.dev/engineering-practices/code-review/#logaf-scale) to specify how important a comment is. You only need one approval from a maintainer to be able to merge. For some PRs, asking specific or multiple people for review might be adequate.

Our different types of reviews:

1. **LGTM without any comments.** You can merge immediately.
2. **LGTM with low and medium comments.** The reviewer trusts you to resolve these comments yourself, and you don't need to wait for another approval.
3. **Only comments.** You must address all the comments and need another review until you merge.
4. **Request changes.** Only use if something critical is in the PR that absolutely must be addressed. We usually use `h` comments for that. When someone requests changes, the same person must approve the changes to allow merging. Use this sparingly.

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

We use [Swiftlint](https://github.com/realm/SwiftLint) and Clang-Format. For SwiftLint, we keep a multiple config files for the tests and samples, cause some rules don't make sense for testing and sample code. To run all the linters locally execute:

```sh
make lint
```

## Final Notes

When contributing to the codebase, please make note of the following:

- Non-trivial PRs will not be accepted without tests (see above).
- Please do not bump version numbers yourself.
