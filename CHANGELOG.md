# Changelog

## unreleased

## 6.0.6

- fix: Call beforeBreadcrumb for Breadcrumb Tracker #815

## 6.0.5

- fix: Add eventId to user feedback envelope header #809
- feat: Manually capturing User Feedback #804

## 6.0.4
- fix: Sanitize UserInfo of NSError and NSException #770
- fix: Xcode 12 warnings for Cocoapods #791

## 6.0.3

- fix: Making SentrySdkInfo Public #788

## 6.0.2

- fix: iOS 13.4 Runtime Crash #786
- fix: Using wrong SDK name #782
- feat: Expose `captureEnvelope` on the client #784
- fix: Remove initWithJSON from SentryEvent #781
- fix: Carthage for Xcode 12 #780
- fix: Add missing SentrySdkInfo.h to umbrella header #779
- ref: Remove event.json field #768

## 6.0.1

- fix: Warning Duplicate build file in Copy Headers #761
- fix: Warning when integrating SDK via Carthage #760
- feat: Set installationId to userId if no user is set #757

## 6.0.0

This is a major bump with lots of internal improvements and a few breaking changes.
For a detailed explanation  how to updgrade please checkout the [migration guide](MIGRATION.md).

Breaking changes:

- fix: Make SentryMessage formatted required #756
- feat: Add SentryMessage #752
- feat: Replace passing nullable Scope with overloads #743
- feat: Remove SentryOptions.enabled #736
- fix: Public Headers #735
- feat: Attach stacktraces to all events by default #705
- feat: Replace NSNumber with BOOL in SentryOptions #719
- feat: Enable auto session tracking per default #689
- feat: Remove deprecated SDK inits #673
- feat: Bump minimum iOS version to 9.0 #669
- fix: Umbrella header #671
- feat: Replace NSString for eventId with SentryId #668
- feat: Use envelopes for sending events #650

Features and fixes:

- fix: Make public isEqual _Nullable #751
- feat: Use error domain and code for event message #750
- feat: Remove SDK frames when attaching stacktrace #739
- fix: captureException crates a event type=error #746
- fix: Setting environment for Sessions #734
- feat: Crash event and session in same envelope #731
- feat: Allow nil in setExtraValue on SentryScope to remove key #703
- fix: Header Imports for the Swift Package Manager #721
- fix: Async storing of envelope to disk #714
- feat: Migrate session init for stored envelopes #693
- fix: Remove redundant sdk options enable check in SentryHttpTransport #698
- fix: Sending envelopes multiple times #687
- fix: Rate limiting for cached envelope items #685
- feat: Errors and sessions in the same envelope #686
- feat: Implement NSCopying for SentrySession #683
- fix: Crash when SentryClient is nil in SentryHub #681
- feat: Send cached envelopes first #676

## 6.0.0-beta.2

Breaking changes:

- feat: Remove SentryOptions.enabled #736
- fix: Public Headers #735

Fix:
- fix: Setting environment for Sessions #734

## 6.0.0-beta.1

This release also enables by default the option `attackStacktrace` which includes
the stacktrace in all events, including `captureMessage` by default.

Breaking Changes: 

- feat: Attach stacktraces to all events by default #705

Features and fixes: 

- feat: Crash event and session in same envelope #731
- feat: Allow nil in setExtraValue on SentryScope to remove key #703

## 6.0.0-beta.0

Breaking changes:

- feat: Replace NSNumber with BOOL in SentryOptions #719

Features and fixes: 

- fix: Header Imports for the Swift Package Manager #721
- fix: Async storing of envelope to disk #714
- feat: Migrate session init for stored envelopes #693
- fix: Remove redundant sdk options enable check in SentryHttpTransport #698

## 6.0.0-alpha.0

**Breaking Change**: This version uses the [envelope endpoint](https://develop.sentry.dev/sdk/envelopes/).
If you are using an on-premise installation it requires Sentry version
`>= v20.6.0` to work. If you are using sentry.io nothing will change and
no action is needed. Furthermore, with this version
[auto session tracking](https://github.com/getsentry/sentry-cocoa/blob/7876949ca78aebfe7883432e35727993c5c30829/Sources/Sentry/include/SentryOptions.h#L101)
is enabled per default.
[This feature](https://docs.sentry.io/product/releases/health/)
is collecting and sending health data about the usage of your
application.
We are going to add the official migration guide in one of the next beta releases.

Here is an overview of all the breaking changes:

- feat: Enable auto session tracking per default #689
- feat: Remove deprecated SDK inits #673
- feat: Bump minimum iOS version to 9.0 #669
- fix: Umbrella header #671
- feat: Replace NSString for eventId with SentryId #668
- feat: Use envelopes for sending events #650

Other new features and fixes:

- fix: Sending envelopes multiple times #687
- fix: Rate limiting for cached envelope items #685
- feat: Errors and sessions in the same envelope #686
- feat: Implement NSCopying for SentrySession #683
- fix: Crash when SentryClient is nil in SentryHub #681
- feat: Send cached envelopes first #676

## 5.2.2

- feat: Add crashedLastRun to SentrySDK #688

## 5.2.1

- fix: Add IP address to user serialization #665
- fix: Crash in SentryEnvelope.initWithEvent #643
- fix: Build failure for Apple Silicon Macs #588
- feat: capture userinfo from NSError and NSException #679

## 5.2.0

- fix: nxgetlocalarch app store #651

## 5.1.10

- fix: Crash when converting Recrash Report #627
- feat: Add SdkInfo to Envelope Header #626
- fix: Deserialize envelope with header and item #620
- fix: Set LogLevel in startWithConfigureOptions #613

## 5.1.10-beta.0

- fix: Abnormal sessions #607

## 5.1.9

- fix: beforeSend callback in SentryClient #608

## 5.1.8

- fix: Cocoapods build

## 5.1.7

- fix: Overwriting stack trace for crashes #605
- fix: Deployment target warning for Swift Package Manager for Xcode 12 #586

## 5.1.6

- feat: Simplified SDK start #580
- fix: Custom release name for crash reports #590

## 5.1.5

- feat: Attach the stacktrace to custom events #583
- fix: SentryCrashJSON encodeObject crash #576
- feat: Added automatic breadcrumbs for system events #559

## 5.1.4

- fix: Increase max report length #569
- fix: Remove weak ref file contents #571

## 5.1.3

- fix: UUID for SentryCrashReport is null #566

## 5.1.2

- feat: Attach stacktrace of current thread to events #561

## 5.1.1

- fix: Prefix categories methods with sentry #555
- feat: Attach DebugMeta to Events #545
- fix: Duplicate symbol for SentryMeta #549
- feat: Set SUPPORTS_MACCATALYST to YES explicitly #547

## 5.1.0

- fix: Make properties of Session readonly #541
- fix: Remove MemoryWarningIntegration #537
- fix: Avoid Implicit conversion in SentrySession #540
- fix: Change SentryScope setTagValue to NSString #524

## 5.0.5

- feat: Add remove methods for SentryScope #529
- fix: Failing MacOS build #530
- ref: Session values are unsigned #527

## 5.0.4

- fix: End file at the right place with #ifdef #521

## 5.0.3

- fix: Exit session with timestamp #518
- feat: Add sentry_sanitize for NSArray #509

## 5.0.2

- fix: Keep maximum rate limit #498
- fix: Ignore unknown rate limit categories #497
- fix: On app exit, close session as healthy #500

## 5.0.1

- fix: Flakey concurrent test for RateLimits #493
- fix: missing breadcrumbs data on hardcrash #492

## 5.0.0

- GA of major version 5

## 5.0.0-rc.1

- feat: Add support for mac catalyst #479
- fix: RateLimitCategories #482
- fix: RetryAfter treated like all categories #481
- feat: RateLimiting for cached events and envelopes #480
- fix: EnvelopeRateLimit init envelope with header #478

## 5.0.0-beta.7

- feat: RateLimit for non cached Envelopes #476
- fix: Use RateLimitCategoryError for events #470
- feat: Store SentryEnvelopes in extra path #468
- feat: Adds setUser to SentrySDK and SentryHub #467
- feat: Add auto session starting for macOS #463
- fix: Take release name from options #462
- feat: Use new envelope endpoint #475
- feat: App lifecycle events as breadcrumbs #474

## 5.0.0-beta.6

- feat: RateLimit for sendAllStoredEvents #458
- fix: Use maxBreadcrumbs from options #451
- fix: Send vmaddr if available for apple crash reports #459

## 5.0.0-beta.5

- fix: Limit number of breadcrumbs #450

## 5.0.0-beta.4

- feat: Add Sentry initialization function 'start' #441
- fix: Crashed sessions are marked as such #448

## 5.0.0-beta.3

- fix: Persisting Scope with CrashReport
- fix: Frame in app detection #438
- fix: Session ending as Crashed #439

## 5.0.0-beta.2

- fix: The order of how integrations are initialized (fixes not sending crashes on startup)
- fix: Add missing header files to umbrella header

## 5.0.0-beta.1

- feat: Added Session Feature
- feat: New option `enableAutoSessionTracking` set to `true` if you want sessions to be enabled
- feat: Add `_crashOnException:` to handle exceptions for AppKit apps on macOS

## 5.0.0-beta.0

- feat: Added internal `captureEnvelope` method

## 5.0.0-alpha.0

**_BREAKING_**: This is the first public release of our new `5.0.0` #339 version of the SDK.
The majority of the public API of the SDK changed, now it's more streamlined with other Sentry SDKs and prepared for future updates.
Please read the migration guide how to use the new SDK [MIGRATION.MD](MIGRATION.md)

## 4.5.0

- fix: Mac Catalyst detection
- fix: Add null checks in crash reporter
- fix: Check type of key before use it as NSString (#383)
- fix: Use rawKey to get object from dictionary (#392)
- fix: Change instantiating SentryMechanism of unknown exception type (#385)

## 4.4.3

- feat: Swift Package Manager support #352
- fix: travis lane lint #345

## 4.4.2

- feat: Prefer snprintf over sprintf #342

## 4.4.1

- feat: Add support for custom context and event types

## 4.4.0

- feat: Helper property on event to send raw payload

## 4.3.4

- fix: #305

## 4.3.3

- fix: 64 int conversion #296
- fix: Extracting reason of NSException

## 4.3.2

- fix: [SentryThread serialize] will crash when threadId is nil #292

## 4.3.1

- ref: Make `event_id` all lowercase
- feat: Emit log error in case no shared client is set and crash handler was started
- ref: Renamed `Container+DeepSearch` to `Container+SentryDeepSearch`
- ref: Renamed `NSData+Compression` to `NSData+SentryCompression`
- ref: Renamed `NSDate+Extras` to `NSDate+SentryExtras`
- ref: Renamed `NSDictionary+Sanitize` to `NSDictionary+SentrySanitize`

## 4.3.0

- feat: Added `initWithOptions` function, it takes an Dictionary of key value. Possible values are `dsn`, `enabled`, `environment`, `release`, `dist`
- feat: Added `enabled` on the `Client`
- feat: Added `environment` on the `Client`
- feat: Added `release` on the `Client`
- feat: Added `dist` on the `Client`
- ref: Renamed `NSError+SimpleConstructor.h` to `NSError+SentrySimpleConstructor.h`

## 4.2.1

- fix: Add environment to Event in JavaScriptHelper

## 4.2.0

- feat: Add `Client.shared?.trackMemoryPressureAsEvent()` to emit an event if application receives memory pressure notification
- feat: `Client.shared?.enableAutomaticBreadcrumbTracking()` now adds a breadcrumb in case of memory pressure notification

## 4.1.3

- Fix: WatchOS build

## 4.1.2

- fix(react-native): Correctly label fingerprints for JS bridge. (#279)
- Fix error for empty array creation (#278)
- Fix NSInvalidArgumentException in SentryBreadcrumbStore (#272)

## 4.1.1

- Add fingerprint support to JavaScript bridge
- Fix internal variable naming conflict with KSCrash

## 4.1.0

- Introduce `maxEvents` `maxBreadcrumbs` to increase the max count of offline stored assets

## 4.0.1

- Fixes CocoaPods build to include C++ as a library #252

## 4.0.0

- Moved KSCrash into Codebase while renaming it to SentryCrash.
  Removed KSCrash dep in Podspec.
  Still if you do not call `startCrashHandlerWithError` crash handlers will not be installed.

**This should be safe to upgrade from 3.x.x, there are no code changes what so ever.
If you are using CocoaPods or Carthage an update should take care of everything, if you were using the source code directly, make sure to remove KSCrash if you were using it.**

We recommend updating if you experience any KSCrash related crashes since we fixed bunch of stuff directly in our codebase now.

## 3.13.1

- Updated KSCrash project to SKIP_INSTALL

## 3.13.0

- Update docs to use public DSN
- Don't emit nslog if loglevel is none
- Send new mechanism
- Add transaction of current uiviewcontroller

## 3.12.4

- Fixed a bug for empty timestamp if created from JavaScript

## 3.12.3

- Fixed #239

## 3.12.2

- Synchronize storing of breadcrumbs and events

## 3.12.1

- Fixed and error in javascript helper for new exception structure

## 3.12.0

- Fixed #235
- Fixed #236

## 3.11.1

- Fixed #231

## 3.11.0

- Greatly improved handling for rate limiting see: #230
- Added `shouldQueueEvent`
- There is a hardlimit for offline stored events of 10 and 200 for breadcrumbs

## 3.10.0

- This update will create a subfolder for each instance of SentryClient depending on the DSN.
  This also fixes a bug where under rare circumstances on MacOS for not sandboxed apps got sent with the wrong SentryClient.
  **We recommend updating to this version if you are running a un-sandboxed macOS app**
- Fixes #216

## 3.9.1

- Fixed #213

## 3.9.0

- Added JavaScriptBridgeHelper for react-native, cordova SDK

## 3.8.5

- Send breadcrumbs in the order in which they got created

## 3.8.4

- Tick allow-app-extension-API-only box for Carthage builds

## 3.8.3

- Fixed an issue where a crash and the actual event diverge in release version/ dist #218

## 3.8.2

- Fixed #217
- Fixed #214

## 3.8.1

- Fixed failing test

## 3.8.0

- Make KSCrash default CocoaPod subspec
- macOS: Call super exception handler when crash happens
- Added `sampleRate` parameter to configure the likelihood of sending an event [0.0-1.0]

## 3.7.1

- Fixes a bug where stack trace is nil when snapshotting stacktrace

## 3.7.0

- Bump KSCrash to `1.15.12`
- Add `SentryCrashExceptionApplication` for macOS uncaught exception handling

## 3.6.1

- Add `storeEvent` function, mainly used for `react-native`

## 3.6.0

- Fixed a bug in crash Thread detection which caused the Sentry web interface to sometimes show the wrong culprit

## 3.5.0

- Fixed https://github.com/getsentry/sentry-cocoa/issues/200 Make userId optional of `SentryUser`
- Fixed https://github.com/getsentry/sentry-cocoa/issues/198

## 3.4.3

- Initialize extra and tags in private instead of setter in Client init

## 3.4.2

- Fixed #196

## 3.4.1

Fixed messed up Travis build.

## 3.4.0

Expose `sdk` property for `SentryEvent` to allow users to set specific SDK information. -> mainly used in react-native

## 3.3.3

Remove stripping of \_\_sentry extra because it breaks if the event is serialized more than once.

## 3.3.2

Fix `integrations` for `sdk` context.

## 3.3.1

Pretty print json request when verbose logging is active.

## 3.3.0

Change the way `extra` `tags` and `user` is stored.

## 3.2.1

- Fixed #190
- Fixed #191

## 3.2.0

- Add `appendStacktraceToEvent` function in addition to `snapshotStacktrace` to add stacktraces reliably.

## 3.1.3

- Bump KSCrash to `1.15.11`

## 3.1.2

- Add support for SDK integrations

## 3.1.1

- Prefix internal category function

## 3.1.0

- Added new callback `shouldSendEvent` to make it possible to prevent the event from being sent.
- Fixes #178

## 3.0.11

- Fix `snapshotStacktrace` to also include `debug_meta` to fix grouping

## 3.0.10

- Sanitize all extra's array before serialization (Convert NSDate -> NSString)

## 3.0.9

- Change internal locking mechanism for swizzling

## 3.0.8

- Use `KSCrash` `1.15.9` `Core` subspec which only uses bare minimum for Crash reporting
- Fixes #174

## 3.0.7

- Fix system name

## 3.0.6

- Fix `NSNumber` properties in DebugMeta

## 3.0.5

- Rename `RSSwizzle` to `SentrySwizzle`

## 3.0.4

- Fix empty frames on specific crash

## 3.0.3

- Fix carthage builds

Bundled KSCrash into Sentry. Note that this is just for Carthage, CocoaPods knows how to link 2 dynamic frameworks together.

## 3.0.2

- Fix Sentry dynamic framework

## 3.0.1

- Fix carthage build

## 3.0.0

This release is a rewrite of the existing codebase, `sentry-cocoa` now uses Objective-C instead of Swift.
Please make sure to check out the docs since this update introduced many breaking changes.
https://docs.sentry.io/clients/cocoa/

`KSCrash` is now optional, you can use Sentry without it, we still recommend using KSCrash by default otherwise Sentry will not catch any crashes.

## 2.1.11

- Fix swift 3 async operation -> Operation never got removed from queue due using private vars instead of setter

## 2.1.10

- Fixed release naming to `bundleIdentifier`-`shortVersion`

## 2.1.9

- Add support for distributions in sentry
- Make `eventID` `var` instead of `let`

## 2.1.8

- Update KSCrash

## 2.1.7

- Fix duplicate symbols in crash report

  1884.42s user 368.70s system 171% cpu 21:55.70 total

## 2.1.6

- Add additional Info about device

```
("app_identifier", bundleID)
("app_name", bundleName)
("app_build", bundleVersion)
("app_version", bundleShortVersion)
```

## 2.1.5

- Only switflint in Xcode builds, do not while building with CARTHAGE

## 2.1.4

- No longer automatically clear breadcrumbs when an event is sent

## 2.1.3

- Set `ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES` back to `NO` since it prevents upload to iTunes Connect

## 2.1.2

- Prefix react-native frames with `app://`

## 2.1.1

- Update swiftlint to whitelist rules
- Add app context

## 2.1.0

- Added `addTag` `addExtra` function to `SentryClient` and `Event`
  e.g.:

```
SentryClient.shared?.addExtra("key", value: "value")
event.addTag("key", value: "value")
```

- Fixed a bug where 64bit uInt got converted to 32bit
- Added compatiblity for incomplete Crashreports from KSCrash
- Added internal support for upcoming react-native support
- Exposed `maxCrumbs` so the maximum amount of breadcrumbs can be adjusted

## 2.0.1

- Fixed a bug with not sending `release` with event
- Changed the way how swizzling works, there should not be a problem with e.g.: New Relic anymore

## 2.0.0 - Rename from SentrySwift to Sentry

- We decided to rename `SentrySwift` to just `Sentry`

  Version `2.0.0` has the same features as `1.4.5`.
  The name of the Framework has been changed from:
  `import SentrySwift`
  to
  `import Sentry`
  Also in the `Podfile` you have to change to `pod Sentry` instead of `pod SentrySwift`.
  Everything else stayed the same.

## 1.4.5

- Now sending `registers` with stacktrace for better symbolication results
- Added `verbose` logging option which outputs raw events and crash reports
- Add `relevant_address` to stacktrace
- Extended `mechanism`
- Add `build` to `release` e.g.: `1.0 (1337)`
- Added `objcBeforeSendEventBlock` as equivalent to swifts `beforeSendEventBlock`

## 1.4.4

- Removed `SentryClient.shared?.enableThreadNames` because KSCrash changed the mechanism on how threadnames are fetched. They will show up in sentry if available.
- Now sending build number with every event.

## 1.4.3

- Fixed an issue where properties of an event will be overwritten before sending
- Added `SentryClient.shared?.enableThreadNames` variable which can be set to true in order to retrieve the thread names when a crash happens. Enable this on you own risk this could deadlock you app therefore its not yet officially documented.

## 1.4.2

- Fixed Xcode 7 support

## 1.4.1

- enable `searchThreadNames` to display thread names in sentry

## 1.4.0

- Update KSCrash to 1.13.x

**Warning**

- Added namespace for Objc
  e.g.: `User` -> `SentryUser` but Xcode should suggest the new class names ... Swift code does not change

## 1.3.4

- Store events now in `Library/Caches` instead of `Documents` folder

## 1.3.3

- Add `RequestManager` for improved handling on many requests

## 1.3.2

- Reuse `URLSession` when sending events
- Optimize `BreadcrumbStore`

## 1.3.1

- Default log level `.Error`
- Don't strip filepath from frames
- Add `reportReactNativeFatalCrash`

## 1.3.0

- Moved `docs/` to this repo
- You can now take a snapshot of the stacktrace and send it with your event ... see https://docs.sentry.io/clients/cocoa/advanced/#adding-stacktrace-to-message for more information
- Added `beforeSendEventBlock` to change a event before sending it https://docs.sentry.io/clients/cocoa/advanced/#change-event-before-sending-it

## 1.2.0

- Reverse frames in stacktrace
- Remove in_app from stacktrace

## 1.1.0

- Added `SentryClient.shared?.enableAutomaticBreadcrumbTracking()` for iOS which sends all actions and viewDidAppear as breadcrumbs to the server
- Fixed podspec for all target
- Improved UserFeedback controller
- Updated KSCrash to 1.11.2

## 1.0.0

- Refactored a lot of internal classes
- Added `UserFeedback` feature to iOS
- Added basic support for watchOS

## 0.5.0 - Remove Apple Crash Report

- Remove appleCrashReport from request
- Add mechanism to request
- Switch version/build to make iOS version in sentry more understandable
- Use `diagnosis` from KSCrash for crash reasons

## 0.4.1

Fixed for breadcrumbs not always sending on fatal

## 0.4.0

- Support for Swift 2.3 and Swift 3.0

## 0.3.3

- Fixes issue in where capturing `NSError` was not sending up to API

## 0.3.2

- Release was not getting sent up on crashes
- Contexts was getting sent up on wrong key

## 0.3.1

- Defaulting release to main bundle version

## 0.3.0

- Added support for crashing reporting for Mac apps
- Requests are now gzip before going off to Sentry API

## 0.2.1

- Fixed breadcrumbs for updated spec
- Removed all references of "raven"
  - Fixed #13
- Changed merging behaviour in EventProperties
  - Event takes priority over client

## 0.2.0

- Added tvOS support
- Fixes with KSCrash that will build KSCrash for all platforms

## 0.1.0

First pre-release that is ready for testers
