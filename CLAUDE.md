# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Best Practices

- Before forming a commit, ensure compilation succeeds for all platforms: iOS, macOS, tvOS, watchOS and visionOS. This should hold for:
  - the SDK framework targets
  - the sample apps
  - the test targets for the SDK framework and sample apps
- Before submitting a branch for a PR, ensure there are no new issues being introduced for:
  - static analysis
  - runtime analysis, using thread, address and undefined behavior sanitizers
  - cross platform dependencies:
    - React Native
    - Flutter
    - .Net
    - Unity
- While preparing changes, ensure that relevant documentation is added/updated in:
  - headerdocs and inline comments
  - readmes and maintainer markdown docs
  - our docs repo and web app onboarding
  - our cli and integration wizard

## Helpful Commands

- format code: `make format`
- run static analysis: `make analyze`
- run unit tests: `make run-test-server && make test`
- run important UI tests: `make test-ui-critical`
- build the XCFramework deliverables: `make build-xcframework`
- lint pod deliverable: make `pod-lint`

## Resources & Documentation

- **Main Documentation**: [docs.sentry.io/platforms/apple](https://docs.sentry.io/platforms/apple/)
  - **Docs Repo**: [sentry-docs](https://github.com/getsentry/sentry-docs)
- **SDK Developer Documentation**: [develop.sentry.dev/sdk/](https://develop.sentry.dev/sdk/)

### `sentry-cocoa` Maintainer Documentation

- **README**: @README.md
- **Contributing**: @CONTRIBUTING.md
- **Developer README**: @develop-docs/README.md
- **Sample App collection README**: @Samples/README.md

## Related Code & Repositories

- [sentry-cli](https://github.com/getsentry/sentry-cli): uploading dSYMs for symbolicating stack traces gathered via the SDK
- [sentry-wizard](https://github.com/getsentry/sentry-wizard): automatically injecting SDK initialization code
- [sentry-cocoa onboarding](https://github.com/getsentry/sentry/blob/master/static/app/utils/gettingStartedDocs/apple.tsx): the web app's onboarding instructions for `sentry-cocoa`
- [sentry-unity](https://github.com/getsentry/sentry-unity): the Sentry Unity SDK, which depends on sentry-cocoa
- [sentry-dart](https://github.com/getsentry/sentry-dart): the Sentry Dart SDK, which depends on sentry-cocoa
- [sentry-react-native](https://github.com/getsentry/sentry-react-native): the Sentry React Native SDK, which depends on sentry-cocoa
- [sentry-dotnet](https://github.com/getsentry/sentry-dotnet): the Sentry .NET SDK, which depends on sentry-cocoa
