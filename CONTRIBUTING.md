<p align="center">
  <a href="https://sentry.io" target="_blank" align="center">
    <img src="https://sentry-brand.storage.googleapis.com/sentry-logo-black.png" width="280">
  </a>
  <br />
</p>

# Contributing

We welcome suggested improvements and bug fixes for `sentry-cocoa`, in the form of pull requests. Please follow our official [Commit Guidelines](https://develop.sentry.dev/code-review/#commit-guidelines) and also prefix the title of your PR according to the [Commit Guidelines](https://develop.sentry.dev/code-review/#commit-guidelines). The guide below will help you get started, but if you have further questions, please feel free to reach out on [Discord](https://discord.gg/Ww9hbqr).

## Setting up an Environment

Run `make init` to get started. This will install `bundler` and `Homebrew` and their managed dependencies (see `Gemfile` and `Brewfile`).

## Tests

The tests depend on our test server. To run the automated tests, you first need to have the server running locally with

```sh
make run-test-server
```

Test guidelines:

* We write our tests in Swift. When touching a test file written in Objective-C consider converting it to Swift and then add your tests.
* Make use of the fixture pattern for test setup code. For examples, checkout [SentryClientTest](/Tests/SentryTests/SentryClientTest.swift) or [SentryHttpTransportTests](/Tests/SentryTests/SentryHttpTransportTests.swift).
* Use [TestData](/Tests/SentryTests/Protocol/TestData.swift) when possible to avoid setting up data classes with test values.

Test can either be ran inside from Xcode or via

```sh
make test
```

## Code Formatting
Please follow the convention of removing the copyright code comments at the top of files. We only keep them inside [SentryCrash](/SentryCrash/),
as the code is based on [KSCrash](https://github.com/kstenerud/KSCrash).

All Objective-C, C and C++ needs to be formatted with [Clang Format](http://clang.llvm.org/docs/ClangFormat.html). The configuration can be found in [`.clang-format`](./.clang-format). Simply run the make task before submitting your changes for review:

```sh
make format
```

## Linting
We use [Swiftlint](https://github.com/realm/SwiftLint) and Clang-Format. For Swiftlint we keep a seperate [config file](/Tests/.swiftlint) for the tests. To run all the linters locally execute:

```sh
make lint
```

## Environment

Please use `Sentry.xcworkspace` as the entry point when opening the project in Xcode. It also contains all samples for different environments.

## Public Headers

To make a header public follow these steps:

* Move it into the folder [Public](/Sources/Sentry/Public). Both [CocoaPods](Sentry.podspec) and [Swift Package Manager](Package.swift) make all headers in this folder public.
* Add it to the Umbrella Header [Sentry.h](/Sources/Sentry/Public/Sentry.h).
* Set the target membership to public.

## Final Notes

When contributing to the codebase, please make note of the following:

- Non-trivial PRs will not be accepted without tests (see above).
- Please do not bump version numbers yourself.
