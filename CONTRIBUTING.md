<p align="center">
  <a href="https://sentry.io" target="_blank" align="center">
    <img src="https://sentry-brand.storage.googleapis.com/sentry-logo-black.png" width="280">
  </a>
  <br />
</p>

# Contributing

We welcome suggested improvements and bug fixes for `sentry-cocoa`, in the form of pull requests on [`GitHub`](https://github.com/getsentry/sentry-javascript). The guide below will help you get started, but if you have further questions, please feel free to reach out on [Discord](https://discord.gg/Ww9hbqr).

## Setting up an Environment

You need to install bundler and all dependencies locally to run tests:

```
gem install bundler
bundle install
```

With that, the repo is fully set up and you are ready to run all commands.

## Run Tests

Test can either be ran inside from Xcode or using `fastlane`:

```
bundle exec fastlane test
```

## Code Formatting

We use [Clang Format](http://clang.llvm.org/docs/ClangFormat.html) for formatting Objective-C and C. The configuration can be found in [`.clang-format`](./.clang-format). To install Clang Format:

```
npm install -g clang-format
# OR
brew install clang-format
# OR
sudo apt-get install clang-format
```

To format all Objcective-C, C++ and C files:

```
make format
```

To check if their are any style violations in Objcective-C, C++ and C files:

```
make lint
```

## Environment

Please use `Sentry.xcworkspace` as the entry point when opening the project in Xcode. It also contains all samples for different environments.

## Final Notes

When contributing to the codebase, please make note of the following:

- Non-trivial PRs will not be accepted without tests (see above).
- Please do not bump version numbers yourself.
