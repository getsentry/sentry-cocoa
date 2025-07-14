# Samples

Sample applications used as UI test hosts and manual acceptance testing.

Most subdirectories contain an xcodeproj per platform/version, with one or more targets describing variants of applications targeting it, and including the Sentry SDK via a subproject reference. Each sample xcodeproj is included in the top level Sentry.xcworkspace.

## Project Structure

- Uses `xcodegen` with YAML configuration files for sample apps
- Sample configurations in `Samples/*/[AppName].yml`
- Shared configurations and code in `Samples/SentrySampleShared/`
- Run `make xcode` after checkout to ensure projects are up-to-date

## SDK Configuration

The iOS-Swift and iOS-ObjectiveC sample apps have schema launch args and environment variables available to customize how the SDK is configured.

In iOS-Swift, these can also be modified at runtime, to help test various configurations in scenarios where using launch args and environment variables isn't possible, like TestFlight builds. Runtime overrides are set via `UserDefaults`. They interact with schema launch arguments and environment variables as follows: - Boolean flags are ORed together: if either a `true` is set in User Defaults, or a launch argument is set, then the override takes effect. - Values written to user defaults take precedence over schema environment variables by default. If you want to give precedence to schema environment vars over user defaults values, enable the launch arg `--io.sentry.schema-environment-variable-precedence`.

Note that if a key we use to write a boolean value to defaults isn't present in defaults, then UserDefaults returns `false` for the query by default. We write all environment variables as strings, so that by default, if the associated key isn't present, `UserDefaults` returns `nil` (if we directly wrote and read Floats, for example, defaults would return `0` if the key isn't present, and we'd have to do more work to disambiguate that from having overridden it to 0, for cases where 0 isn't the default we want to set in the sample app).

You can see the current override value being used in the "Features" tab.

You can also remove all stored values in user defaults by launching with `--io.sentry.wipe-data`. See `SentrySDKWrapper.swift` and `SentrySDKOverrides.swift` for usages.

Note that in-app overrides don't take effect until the app is relaunched (and not simply backgrounded and then foregrounded again). This means that if you want to test changes to launch profiling, you must change the settings, then relaunch the app for the launch profile configuration to be written to disk, and then relaunch once more for the launch profile scenario to actually be tested.

## Automatically created Sentry tags

To help pinpoint where to look to debug an issue we see on our Sentry dashboard for the `sentry-sdks` project for events coming from our sample apps, each sample app injects some information from the build environment automatically.

- The Git commit hash, branch name and working index status at build time into its Info.plist, which is then accessed on app launch and injected into the initial scope during options configuration in the call to `SentrySDK.startWithOptions`. These then show up as tags in the event detail named `git-branch-name` and `git-commit-hash`. Some apps weren't instrumented yet:
  - tvOS-SBSwift and iOS15-SwiftUI, as those use plist generation from build settings, and that doesn't work with the current strategy implemented with the scripts
  - visionOS-Swift because I was unable to build and test it
- `SentryUser.username` is automatically set to the `SIMULATOR_HOST_HOME` if it is defined, which is usually the value of `whoami` on a developer's work machine. This can be overridden in the scheme with the environment variable key `--io.sentry.user.username` if you need something more specific for your tests.
- `SentryUser.email` is hardcoded to `"tony@example.comn"` but can be overridden using the environment variable `--io.sentry.user.email` in the scheme.

## Code Signing

This repository follows the [codesiging.guide](https://codesigning.guide/) in combination with [fastlane match](https://docs.fastlane.tools/actions/match/).
Therefore the sample apps use manual code signing, see [fastlane docs](https://docs.fastlane.tools/codesigning/xcode-project/):

> In most cases, fastlane will work out of the box with Xcode 9 and up if you selected manual code signing and choose a provisioning profile name for each of your targets.

### Creating new App Identifiers

E.g. if you create a new extension target, like a File Provider for iOS-Swift, make sure it has a unique bundle identifier like `io.sentry.sample.iOS-Swift.FileProvider`. Then, run the following terminal command:

```
rbenv exec bundle exec fastlane produce -u andrew.mcknight@sentry.io --skip_itc -a io.sentry.sample.iOS-Swift.FileProvider
```

You'll be prompted for an Apple Developer Portal 2FA code, and the description for the identifier; in this example, "Sentry Cocoa Sample Swift File Provider Extension".

### Creating provisioning profiles

For an existing app identifier, run the terminal command, after changing the email address in the Matchfile to your personal ADP account's:

```
rbenv exec bundle exec fastlane match development --app_identifier io.sentry.sample.iOS-Swift.FileProvider
```

You can include the `--force` option to regenerate an existing profile.

You can run samples in a real device without changing certificates and provisioning profiles if you are a Sentry employee with access to Sentry [profiles repository](https://github.com/getsentry/codesigning) and 1Password account.

- Configure your environment to use SSH to access GitHub. Follow [this instructions](https://docs.github.com/en/authentication/connecting-to-github-with-ssh).
- You will need `Cocoa codesigning match encryption password` from your Sentry 1Password account.
- run `fastlane match_local`

This will setup certificates and provisioning profiles into your machine, but in order to be able to run a sample in a real device you need to register that device with Sentry AppConnect account, add the device to the provisioning profile you want to use, download the profile again and open it with Xcode.
