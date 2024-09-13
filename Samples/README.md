# Samples

Sample applications used as test hosts and manual acceptance testing.

Most subdirectories contain an xcodeproj per platform/version, with one or more targets describing variants of applications targeting it, and including the Sentry SDK via a subproject reference. Each sample xcodeproj is included in the top level Sentry.xcworkspace.

## Automatically created Sentry tags

To help pinpoint where to look to debug an issue we see on our Sentry dashboard for the `sentry-sdks` project for events coming from our sample apps, each sample app injects some information from the build environment automatically. 
- The Git commit hash, branch name and working index status at build time into its Info.plist, which is then accessed on app launch and injected into the initial scope during options configuration in the call to `SentrySDK.startWithOptions`. These then show up as tags in the event detail named `git-branch-name` and `git-commit-hash`. Some apps weren't instrumented yet:
    - tvOS-SBSwift and iOS15-SwiftUI, as those use plist generation from build settings, and that doesn't work with the current strategy implemented with the scripts
    - visionOS-Swift because I was unable to build and test it
- `SentryUser.username` is automatically set to the `SIMULATOR_HOST_HOME` if it is defined, which is usually the value of `whoami` on a developer's work machine. This can be overridden in the scheme with the environment variable key `--io.sentry.user.username` if you need something more specific for your tests.
- `SentryUser.email` is hardcoded to `"tony@example.comn"` but can be overridden using the environment variable `--io.sentry.user.email` in the scheme.
