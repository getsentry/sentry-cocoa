# Changelog

## Unreleased

### Features

- Add experimental support for capturing structured logs via `SentrySDK.logger` (#5532, #5593, #5639, #5628, #5637)
- The SDK will show a warning in the console if it detects it was loaded twice (#5298)

### Improvements

- Extract video processing to a new class (#5604)
- Move continuous profiling payload serialization off of the main thread (#5613)
- Improve video generation using apple recommended loop (#5612)
- Use -OSize for release builds (#5721)

### Fixes

- Fix video replay crashes due to video writer inputs not marked as finished on cancellation (#5608)
- Fix wrong flush timeout (#5565). When flush timed out before the SDK finished sending data, it always blocked the full flush timeout the next time being called. This is fixed now.
- Launch profiling now respects original configured options if they change on the next launch (#5417)
- User feedback no longer subject to sample rates or `beforeSend` (#5692)
- Build error in app extensions (#5682)
- Fix frame metrics including time while in background (#5681)

## 8.53.2

### Fixes

- Set handled to false for fatal app hangs (#5514)
- User feedback widget can now be displayed in SwiftUI apps (#5223)
- Fix crash when SentryFileManger is nil (#5535)
- Fix crash when capturing events at the same time `bindClient:` is called from a different thread (#5523)
- Record user for watchdog termination events (#5558)
- Add support for dist and environment fields for termination watch (#5560)
- Add support for tags and context fields for termination watch (#5561)
- Add support for extras, fingerprint, and level watchdog termination events (#5569)

### Improvements

- Removed `APPLICATION_EXTENSION_API_ONLY` requirement (#5524)
- Improve launch profile configuration management (#5318)
- Deprecate getStoreEndpoint (#5591)

## 8.53.1

### Fixes

- Fix XCFramework version including commit sha on release. (#5493)

## 8.53.0

> [!Warning]
> This version can cause build errors when using one of the XCFrameworks, such as
> `The value for key CFBundleVersion [8.53.0+f92cfa9b1199c75411a263d2d9bc2df8ea8029cf] in the Info.plist file must be no longer than 18 characters.`
> Updating to 8.53.1 fixes this problem.

### Features

- Capturing fatal CPPExceptions via hooking into cxa_throw when enabling `options.experimental.enableUnhandledCPPExceptionsV2 = true` (#5256)

### Fixes

- Fix building with Xcode 26 (#5386)
- Fix usage of `@available` to be `iOS` instead of `iOSApplicationExtension` (#5361)
- Fix stacktrace symbolication of fatal app hangs (#5438)
- Robustness against corrupt launch profile configuration files (#5447)
- Fix auto-start for session tracker when SDK is started after app did become active (#5121)
- Sessions will now be marked as exited instead of abnormal exit when closing the SDK (#5121)
- Manually add `dyld` image to image cache to fix dyld symbols appearing as `unknown` (#5418)

### Improvements

- Converted SentryUserFeedback from Objective-C to Swift (#5377)
- Crashes for uncaught NSExceptions will now report the stracktrace recorded within the exception (#5306)
- Move SentryExperimentalOptions to a property defined in Swift (#5329)
- Add redaction in session replay for `SFSafariView` used by `SFSafariViewController` and `ASWebAuthenticationSession` (#5408)
- Convert SentryNSURLRequest to Swift (#5457)

## 8.53.0-alpha.0

### Features

- Capturing fatal CPPExceptions via hooking into cxa_throw when enabling `options.experimental.enableUnhandledCPPExceptionsV2 = true` (#5256)
- [Structured Logging] Models + Preparation ([#5441](https://github.com/getsentry/sentry-cocoa/pull/5441))

### Fixes

- Fix building with Xcode 26 (#5386)
- Fix usage of `@available` to be `iOS` instead of `iOSApplicationExtension` (#5361)
- Fix stacktrace symbolication of fatal app hangs (#5438)
- Robustness against corrupt launch profile configuration files (#5447)
- Fix auto-start for session tracker when SDK is started after app did become active (#5121)
- Sessions will now be marked as exited instead of abnormal exit when closing the SDK (#5121)
- Manually add `dyld` image to image cache to fix dyld symbols appearing as `unknown` (#5418)

### Improvements

- Converted SentryUserFeedback from Objective-C to Swift (#5377)
- Crashes for uncaught NSExceptions will now report the stracktrace recorded within the exception (#5306)
- Move SentryExperimentalOptions to a property defined in Swift (#5329)
- Add redaction in session replay for `SFSafariView` used by `SFSafariViewController` and `ASWebAuthenticationSession` (#5408)
- Convert SentryNSURLRequest to Swift (#5457)

## 8.52.1

### Fixes

- Missing debug meta for non fatal events (#5352)

## 8.52.0

> [!Warning]
> This version has a [known issue](https://github.com/getsentry/sentry-cocoa/issues/5334) where events captured with `captureMessage` or `captureError` will have unsymbolicated stack traces. A fix is incoming and will be released in 8.52.1

### Features

- XCFrameworks are now signed (#5271)

### Improvements

- Slightly reduce performance impact by removing unnecessary lock in SentryLog.configure (#5297)
- Redact React Native text and images by default without the RN SDK (#5302)

### Fixes

- Add missing context for watchdog termination events (#5242)
- Use timestamp of screenshot for frames (#5342)
- Use frame rate for cache max size of session replay (#5341)

## 8.52.0-beta

### Features

- XCFrameworks are now signed (#5271)

### Improvements

- Slightly reduce performance impact by removing unnecessary lock in SentryLog.configure (#5297)
- Redact React Native text and images by default without the RN SDK (#5302)

## 8.51.1

> [!Warning]
> This version introduces a [known issue](https://github.com/getsentry/sentry-cocoa/issues/5334) where events captured with `captureMessage` or `captureError` will have unsymbolicated stack traces. A fix is incoming and will be released in 8.52.1

### Fixes

- Uses low-priority queues to reduce the chance of session replay internal multi-threading processes being dropped (#5280)

### Improvements

- Threading issues in internal dependency container (#5225)

## 8.51.0

> [!Important]
> This version creates new issue groups for your unhandled C++ exceptions because it now again reports the message of unhandled C++ exceptions, which we use for grouping.

### Features

- Apps can now manually show and hide the included feedback widget button (#5236)

### Fixes

- Reporting unhandled C++ exception message (#5190)
- Improved internal multi-threading of session replay to fix thread inversion warning and reduce chance of queue starvation (#5018)

### Improvements

- Add `itemCount` to `SentryEnvelopeItemHeader` ([#5230](https://github.com/getsentry/sentry-cocoa/pull/5230))
- Improve warn log in SentryTracer (#5248)

## 8.50.2

### Fixes

- Improved time-to-display tracker to not crash when using view life cycle methods incorrectly (#5048)
- Enable view renderer V2 by default in session replay and preview redact options when using initializer with default values (#5210)

## 8.50.1

### Fixes

- Detect AppHangsV2 when tracing not enabled (#5184)

### Improvements

- Add `frameRate`, `errorReplayDuration`, `errorReplayDuration`, `sessionSegmentDuration` and `maximumDuration` to session replay options dictionary initializer for Hybrid SDKs (#5210)

## 8.50.1-beta.0

### Fixes

- Detect AppHangsV2 when tracing not enabled (#5184)

## 8.50.0

> [!Important]
> This version enables the better view renderer V2 used by Session Replay by default.
> You can disable it by setting the option `options.sessionReplay.enableViewRendererV2` to `false`.
>
> In case you are noticing issues with view rendering, please report them on [GitHub](https://github.com/getsentry/sentry-cocoa).

### Features

- Added ability to bring your own button for user feedback form display (#5107)
- Make enableAppHangTrackingV2 general available (#5149)

### Fixes

- Correctly rate limit envelopes from the new UI profiling system (#5131)
- Race condition in ANRTrackerV1 (#5137)

### Improvements

- More logging for Session Replay video info (#5132)
- Improve session replay frame presentation timing calculations (#5133)
- Use wider compatible video encoding options for Session Replay (#5134)
- GA of better session replay view renderer V2 (#5054)
- Explicitly check malloc result for SRSync to fix a Veracode Security Scan warning (#5160)
- Revert max key-frame interval to once per session replayvideo segment (#5156)
- Add more detailed debug logs for session replay (#5173)

## 8.49.2

> [!Important]
> Version 8.21.0 introduced an issue for app launch profiling **only for macOS apps that run without a sandbox** (i.e. distributed outside the Mac App Store).
> This issue could lead to starting the app launch profiler even when it's not configured via the options.
> We recommend upgrading to at least this version.

### Fixes

- Non-sandboxed macOS app launch profile configuration are now respected (#5144)

## 8.49.1

### Fixes

- Crash in setMeasurement when name is nil (#5064)
- Make setMeasurement thread safe (#5067, #5078)
- Truncation of Swift crash messages (#5036)
- Add error logging for move current replay to last path (#5083)
- Async safe log for backtrace in CPPException (#5098)

## 8.49.0

### Features

- New continuous profiling configuration API (#4952 and #5063)

> [!Important]
> With the addition of the new profiling configuration API, the previous profiling API are deprecated and will be removed in the next major version of the SDK:
>
> - `SentryOptions.enableProfiling`
> - `SentryOptions.isProfilingEnabled`
> - `SentryOptions.profilesSampleRate`
> - `SentryOptions.profilesSampler`
> - `SentryOptions.enableLaunchProfiling`
>
> Additionally, note that the behavior of `SentrySDK.startProfiler()` will change once the above APIs are removed, as follows: before adding the new configuration API (`SentryProfileOptions`), `SentrySDK.startProfiler()` would unconditionally start a continuous profile if both `SentryOptions.profilesSampleRate` and `SentryOptions.profilesSampler` were `nil`, or no-op if either was non-`nil` (meaning the SDK would operate under original, transaction-based, profiling model). In the next major version, `SentryOptions.profilesSampleRate` and `SentryOptions.profilesSampler` will be removed, and `SentrySDK.startProfile()` will become a no-op unless you configure `SentryProfileOptions.sessionSampleRate` to a value greater than zero (which is its default). If you already have calls to `SentrySDK.startProfiler()` in your code, ensure you properly configure `SentryProfileOptions` via `SentryOptions.configureProfiling` to avoid losing profiling coverage.

### Fixes

- Continuous profile stop requests are cancelled by subsequent timely calls to start (#4993)

### Improvements

- Remove SDK side character limit of 8192 for SentryMessage (#5005) Now, the backend handles the character limit, which has the advantage of showing in the UI when the message was truncated.

## 8.48.0

### Features

- Add extension for `FileManager` to track file I/O operations with Sentry (#4863)

### Improvements

- Slightly speed up adding breadcrumbs (#4984)

### Fixes

- Fixes experimental Replay view renderer options initialisation (#4988)

## 8.47.0

> [!Important]
> This version fixes an important bug for applying scope data to crash events (#4969).
>
> Previously, the SDK always set the event's user to the user of the scope of the app launch after the crash event, which could result in incorrect user data if the user changed between the crash and the next launch.
> Additionally, if specific properties on the crash event were nil, the SDK replaced them with values from the scope of the app launch after the crash event. This affected the following event properties: tags, extra, fingerprints, breadcrumbs, dist, environment, level, and trace context. However, since most of these properties are infrequently nil, the fix should have minimal impact on most users.

### Deprecations

- Some profiling API are deprecated in favor of new ways to manage starting and stopping continuous profiling sessions (#4854)

### Features

- Add extension for `Data` to track file I/O operations with Sentry (#4862)
- Send fatal app hang session updates (#4921) only when enabling the option `enableAppHangTrackingV2`.
- Add experimental flag `options.sessionReplay.enableExperimentalViewRenderer` to enable up to 5x times more performance in Session Replay (#4940)

### Fixes

- Correctly finish TTFD span when no new frame (#4941)
- Only delete envelopes when receiving HTTP 200 (#4956)
- Set foreground true for watchdog terminations (#4953)
- Fix removing value from context not updating observer context (#4960)
- Fix wrongly applying scope to crash events (#4969)
- Changed parameter of `SDKInfo.initWithOptions` to be nullable (#4968)

### Improvements

- More debug logs for UIViewController tracing (#4942)
- Avoid creating unnecessary User Interaction transactions (#4957)

## 8.46.0

### Features

- Report fatal app hangs (#4889) only when enabling the option `enableAppHangTrackingV2`
- New user feedback API and Widget (#4874)

### Improvements

- Log message when setting user before starting the SDK (#4882)
- Add experimental flag to disable swizzling of `NSData` individually (#4859)
- Replace calls of `SentryScope.useSpan` with callback to direct span accessor (#4896)
- Slightly reduce size of SentryCrashReports (#4915)

### Fixes

- Fix rare memory access issue for auto tracing (#4894). For more details, see issue (#4887).
- Move assignment of file IO span origin outside of block (#4888)
- Deadline timeout crash in SentryTracer (#4911)
- Improve memory-safety by converting Swift constants to Objective-C (#4910)
- Fix C++ compilation error due to changes in Xcode 16.3 beta's compiler toolchain (#4917 and #4918)

### Internal

- Add injectable mask and view renderer (#4938)

## 8.45.0

> [!WARNING]
> We have been made aware that this version can cause crashes in certain configurations when using network tracking, file I/O tracking, or CoreData tracking features.
> We recommend staying on version 8.43.0 or disabling the mentioned features until a fix is released.
> See issue [#4887](https://github.com/getsentry/sentry-cocoa/issues/4887) for more details.

### Features

- Add `showMaskPreview` to `SentrySDK.replay` api to debug replay masking (#4761)
- Session replay masking preview for SwiftUI (#4737)
- HTTP Breadcrumb level based on response status code (#4779) 4xx is warning, 5xx is error.
- Measure app hang duration for AppHangTrackingV2 (#4836)

### Improvements

- Add more debug logs for SentryViewHierarchy (#4780)
- Add `sample_rand` to baggage (#4751)
- Add timeIntervalSince1970 to log messages (#4781)
- Add `waitForFullDisplay` to `sentryTrace` view modifier (#4797)
- Increase continuous profiling buffer size to 60 seconds (#4826)

### Fixes

- Fix missing `sample_rate` in baggage (#4751)
- Serializing SentryGeo with `nil` values (#4724)
- Add type-safety for screenshots result array (#4843)

### Internal

- Deserializing SentryEvents with Decodable (#4724)
- Remove internal unknown dict for Breadcrumbs (#4803) This potentially only impacts hybrid SDKs.

## 8.44.0

> [!WARNING]
> We have been made aware that this version can cause crashes in certain configurations when using network tracking, file I/O tracking, or CoreData tracking features.
> We recommend staying on version 8.43.0 or disable the mentioned features until a fix is released.
> See issue [#4887](https://github.com/getsentry/sentry-cocoa/issues/4887) for more details.

### Fixes

- Don't start the SDK inside Xcode preview (#4601)
- Use strlcpy to save session replay info path (#4740)
- `sentryReplayUnmask` and `sentryReplayUnmask` preventing interaction (#4749)
- Missing `SentryCrashExceptionApplication` implementation for non-macOS target (#4759)
- Add `NSNull` handling to `sentry_sanitize` (#4760)

### Improvements

- Add native SDK information in the replay option event (#4663)
- Add error logging for invalid `cacheDirectoryPath` (#4693)
- Add SentryHub to all log messages in the Hub (#4753)
- More detailed log message when can't start session in SentryHub (#4752)

### Features

- SwiftUI time for initial display and time for full display (#4596)
- Add protocol for custom screenName for UIViewControllers (#4646)
- Allow hybrid SDK to set replay options tags information (#4710)
- Add threshold to always log fatal logs (#4707)

### Internal

- Change macros TEST and TESTCI to SENTRY_TEST and SENTRY_TEST_CI (#4712)
- Convert constants SentrySpanOperation to Swift (#4718)
- Convert constants SentryTraceOrigins to Swift (#4717)

## 8.44.0-beta.1

### Fixes

- Don't start the SDK inside Xcode preview (#4601)

### Improvements

- Add native SDK information in the replay option event (#4663)
- Add error logging for invalid `cacheDirectoryPath` (#4693)

### Features

- SwiftUI time for initial display and time for full display (#4596)
- Add protocol for custom screenName for UIViewControllers (#4646)
- Allow hybrid SDK to set replay options tags information (#4710)
- Add threshold to always log fatal logs (#4707)

### Internal

- Change macros TEST and TESTCI to SENTRY_TEST and SENTRY_TEST_CI (#4712)
- Convert constants SentrySpanOperation to Swift (#4718)
- Convert constants SentryTraceOrigins to Swift (#4717)

## 8.43.1-beta.0

### Fixes

- Memory growth issue in profiler (#4682)
- Replace occurences of `strncpy` with `strlcpy` (#4636)
- Fix span recording for `NSFileManager.createFileAtPath` starting with iOS 18, macOS 15 and tvOS 18. This feature is experimental and must be enabled by setting the option `experimental.enableFileManagerSwizzling` to `true` (#4634)

### Internal

- Update to Xcode 16.2 in workflows (#4673)
- Add method unswizzling (#4647)

## 8.43.0

> [!WARNING]
> This release contains a breaking change for the previously experimental session replay options. We moved the options from Session from `options.experimental.sessionReplay` to `options.sessionReplay`.

### Features

- Session replay GA (#4662)
- Show session replay options as replay tags (#4639)

### Fixes

- Remove empty session replay tags (#4667)
- `SentrySdkInfo.packages` should be an array (#4626)
- Use the same SdkInfo for envelope header and event (#4629)

### Improvements

- Improve compiler error message for missing Swift declarations due to APPLICATION_EXTENSION_API_ONLY (#4603)
- Mask screenshots for errors (#4623)
- Slightly speed up serializing scope (#4661)

### Internal

- Remove loading `integrations` names from `event.extra` (#4627)
- Add Hybrid SDKs API to add extra SDK packages (#4637)

## 8.43.0-beta.1

### Improvements

- Improve compiler error message for missing Swift declarations due to APPLICATION_EXTENSION_API_ONLY (#4603)
- Mask screenshots for errors (#4623)
- Slightly speed up serializing scope (#4661)

### Features

- Show session replay options as replay tags (#4639)

### Fixes

- `SentrySdkInfo.packages` should be an array (#4626)
- Use the same SdkInfo for envelope header and event (#4629)

### Internal

- Remove loading `integrations` names from `event.extra` (#4627)
- Add Hybrid SDKs API to add extra SDK packages (#4637)

## 8.42.1

### Fixes

- Fixes Session replay screenshot provider crash (#4649)
- Session Replay wrong clipping order (#4651)

## 8.42.0

### Features

- Add in_foreground app context to transactions (#4561)
- Add in_foreground app context to crash events (#4584)
- Promote the option `performanceV2` from experimental to stable (#4564)

### Fixes

- Session replay touch tracking race condition (#4548)
- Use `options.reportAccessibilityIdentifier` for Breadcrumbs and UIEvents (#4569)
- Session replay transformed view masking (#4529)
- Load integration from same binary (#4541)
- Masking for fast animations #4574
- Fix GraphQL context for HTTP client error tracking (#4567)

### Improvements

- impr: Speed up getBinaryImages V2 (#4539). Follow up on (#4435)
- Make SentryId Sendable (#4553)
- Expose `Sentry._Hybrid` explicit module (#4440)
- Track adoption of `enablePersistingTracesWhenCrashing` (#4587)

## 8.42.0-beta.2

### Fixes

- Fix GraphQL context for HTTP client error tracking (#4567)

### Improvements

- Track adoption of `enablePersistingTracesWhenCrashing` (#4587)

## 8.42.0-beta.1

### Features

- Add in_foreground app context to transactions (#4561)
- Add in_foreground app context to crash events (#4584)
- Promote the option `performanceV2` from experimental to stable (#4564)

### Fixes

- Session replay touch tracking race condition (#4548)
- Use `options.reportAccessibilityIdentifier` for Breadcrumbs and UIEvents (#4569)
- Session replay transformed view masking (#4529)
- Load integration from same binary (#4541)
- Masking for fast animations #4574

### Improvements

- impr: Speed up getBinaryImages V2 (#4539). Follow up on (#4435)
- Make SentryId Sendable (#4553)
- Expose `Sentry._Hybrid` explicit module (#4440)

## 8.41.0

### Features

- Transactions for crashes (#4504): Finish the transaction bound to the scope when the app crashes. This **experimental** feature is disabled by default. You can enable it via the option `enablePersistingTracesWhenCrashing`.

### Fixes

- Keep PropagationContext when cloning scope (#4518)
- UIViewController with Xcode 16 in debug (#4523). The Xcode 16 build setting [ENABLE_DEBUG_DYLIB](https://developer.apple.com/documentation/xcode/build-settings-reference#Enable-Debug-Dylib-Support), which is turned on by default only in debug, could lead to missing UIViewController traces.
- Concurrency crash with Swift 6 (#4512)
- Make `Scope.span` fully thread safe (#4519)
- Finish TTFD when not calling reportFullyDisplayed before binding a new transaction to the scope (#4526).
- Session replay opacity animation masking (#4532)

## 8.41.0-beta.1

### Features

- Transactions for crashes (#4504): Finish the transaction bound to the scope when the app crashes. This **experimental** feature is disabled by default. You can enable it via the option `enablePersistingTracesWhenCrashing`.

### Fixes

- Keep PropagationContext when cloning scope (#4518)
- UIViewController with Xcode 16 in debug (#4523). The Xcode 16 build setting [ENABLE_DEBUG_DYLIB](https://developer.apple.com/documentation/xcode/build-settings-reference#Enable-Debug-Dylib-Support), which is turned on by default only in debug, could lead to missing UIViewController traces.
- Concurrency crash with Swift 6 (#4512)
- Make `Scope.span` fully thread safe (#4519)
- Finish TTFD when not calling reportFullyDisplayed before binding a new transaction to the scope (#4526).
- Session replay opacity animation masking (#4532)

## 8.40.1

### Fixes

- Session replay masking not working inside scroll view (#4498)

### Improvements

- Add extra logs for UIViewControllerSwizzling (#4511)

## 8.40.0

### Features

- Add option to report uncaught NSExceptions on macOS (#4471)
- Build visionOS project with static Sentry SDK (#4462)
- Too many navigation breadcrumbs for Session Replay (#4480)
- Time-of-check time-of-use filesystem race condition (#4473)
- Capture all touches with session replay (#4477)

### Improvements

- Improve frames tracker performance (#4469)
- Log a warning when dropping envelopes due to rate-limiting (#4463)
- Expose `SentrySessionReplayIntegration-Hybrid.h` as `private` (#4486)
- Stops session replay if rate limiting is activated (#4496)
- Add `maskedViewClasses` and `unmaskedViewClasses` to SentryReplayOptions init via dict (#4492)
- Add `quality` to SentryReplayOptions init via dict (#4495)

### Fixes

- Masking text with transparent text color (#4499)

## 8.39.0

### Removal of Experimental API

- Remove the deprecated experimental Metrics API (#4406): [Learn more](https://sentry.zendesk.com/hc/en-us/articles/26369339769883-Metrics-Beta-Coming-to-an-End)

### Features

- feat: API to manually start/stop Session Replay (#4414)
- Custom redact modifier for SwiftUI (#4362, #4392)
- Track usage of appHangTrackingV2 (#4445)
- AppHangV2 detection (#4379) Add a new algorithm for detecting app hangs that differentiates between fully blocking and non-fully blocking app hangs. Read more in-depth in our [docs](https://docs.sentry.io/platforms/apple/guides/ios/configuration/app-hangs/#app-hangs-v2).

### Fixes

- Edge case for swizzleClassNameExclude (#4405): Skip creating transactions for UIViewControllers ignored for swizzling via the option `swizzleClassNameExclude`.
- Add TTID/TTFD spans when loadView gets skipped (#4415)
- Finish TTID correctly when viewWillAppear is skipped (#4417)
- Swizzling RootUIViewController if ignored by `swizzleClassNameExclude` (#4407)
- Data race in SentrySwizzleInfo.originalCalled (#4434)
- Delete old session replay files (#4446)
- Thread running at user-initiated quality-of-service for session replay (#4439)
- Don't create transactions for unused UIViewControllers (#4448)

### Improvements

- Serializing profile on a BG Thread (#4377) to avoid potentially slightly blocking the main thread.
- Session Replay performance for SwiftUI (#4419)
- Speed up getBinaryImages (#4435) for finishing transactions and capturing events
- Align SDK dispatch queue names (#4442) to start with `io.sentry`
- Use UInts in envelope deserialization (#4441)
- Make `SentrySDK.replay.start()` thread safe (#4455)

## 8.39.0-beta.1

### Removal of Experimental API

- Remove the deprecated experimental Metrics API (#4406): [Learn more](https://sentry.zendesk.com/hc/en-us/articles/26369339769883-Metrics-Beta-Coming-to-an-End)

### Features

- feat: API to manually start/stop Session Replay (#4414)
- Custom redact modifier for SwiftUI (#4362, #4392)
- Track usage of appHangTrackingV2 (#4445)
- AppHangV2 detection (#4379) Add a new algorithm for detecting app hangs that differentiates between fully blocking and non-fully blocking app hangs. Read more in-depth in our [docs](https://docs.sentry.io/platforms/apple/guides/ios/configuration/app-hangs/#app-hangs-v2).

### Fixes

- Edge case for swizzleClassNameExclude (#4405): Skip creating transactions for UIViewControllers ignored for swizzling via the option `swizzleClassNameExclude`.
- Add TTID/TTFD spans when loadView gets skipped (#4415)
- Finish TTID correctly when viewWillAppear is skipped (#4417)
- Swizzling RootUIViewController if ignored by `swizzleClassNameExclude` (#4407)
- Data race in SentrySwizzleInfo.originalCalled (#4434)
- Delete old session replay files (#4446)
- Thread running at user-initiated quality-of-service for session replay (#4439)
- Don't create transactions for unused UIViewControllers (#4448)

### Improvements

- Serializing profile on a BG Thread (#4377) to avoid potentially slightly blocking the main thread.
- Session Replay performance for SwiftUI (#4419)
- Speed up getBinaryImages (#4435) for finishing transactions and capturing events
- Align SDK dispatch queue names (#4442) to start with `io.sentry`
- Use UInts in envelope deserialization (#4441)
- Make `SentrySDK.replay.start()` thread safe (#4455)

## 8.38.0

### Features

- Added breadcrumb.origin private field (#4358)
- Custom redact modifier for SwiftUI (#4362)
- Add support for arm64e (#3398)
- Add mergeable libraries support to dynamic libraries (#4381)

### Improvements

- Speed up HTTP tracking for multiple requests in parallel (#4366)
- Slightly speed up SentryInAppLogic (#4370)
- Rename session replay `redact` options and APIs to `mask` (#4373)
- Stop canceling timer for manual transactions (#4380)

### Fixes

- Fix the versioning to support app release with Beta versions (#4368)
- Linking ongoing trace to crash event (#4393)

## 8.38.0-beta.1

### Features

- Added breadcrumb.origin private field (#4358)
- Custom redact modifier for SwiftUI (#4362)
- Add support for arm64e (#3398)
- Add mergeable libraries support to dynamic libraries (#4381)

### Improvements

- Speed up HTTP tracking for multiple requests in parallel (#4366)
- Slightly speed up SentryInAppLogic (#4370)
- Rename session replay `redact` options and APIs to `mask` (#4373)
- Stop canceling timer for manual transactions (#4380)

### Fixes

- Fix the versioning to support app release with Beta versions (#4368)
- Linking ongoing trace to crash event (#4393)

## 8.37.0

### Features

- Added `thermal_state` to device context (#4305)
- Send envelopes that cannot be cached to disk (#4294)

### Refactoring

- Moved session replay API to `SentrySDK.replay` (#4326)
- Changed default session replay quality to `medium` (#4326)

### Fixes

- Resumes replay when the app becomes active (#4303)
- Session replay redact view with transformation (#4308)
- Correct redact UIView with higher zPosition (#4309)
- Don't redact clipped views (#4325)
- Session replay for crash not created because of a race condition (#4314)
- Double-quoted include, expected angle-bracketed instead (#4298)
- Discontinue use of NSApplicationSupportDirectory in favor of NSCachesDirectory (#4335)
- Safe guard `strncpy` usage (#4336)
- Stop using `redactAllText` as an indicator tha redact is enabled (#4327)

### Improvements

- Avoid extra work when storing invalid envelopes (#4337)

## 8.37.0-beta.1

### Features

- Added `thermal_state` to device context (#4305)
- Send envelopes that cannot be cached to disk (#4294)

### Refactoring

- Moved session replay API to `SentrySDK.replay` (#4326)
- Changed default session replay quality to `medium` (#4326)

### Fixes

- Resumes replay when the app becomes active (#4303)
- Session replay redact view with transformation (#4308)
- Correct redact UIView with higher zPosition (#4309)
- Don't redact clipped views (#4325)
- Session replay for crash not created because of a race condition (#4314)
- Double-quoted include, expected angle-bracketed instead (#4298)
- Discontinue use of NSApplicationSupportDirectory in favor of NSCachesDirectory (#4335)
- Safe guard `strncpy` usage (#4336)
- Stop using `redactAllText` as an indicator tha redact is enabled (#4327)

### Improvements

- Avoid extra work when storing invalid envelopes (#4337)

## 8.36.0

### Features

- Continuous mode profiling (see `SentrySDK.startProfiler` and `SentryOptions.profilesSampleRate`) (#4010)

### Fixes

- Proper redact SR during animation (#4289)

## 8.35.1

### Fixes

- Crash when reading corrupted envelope (#4297)

## 8.35.0

### Features

- Expose span baggage API (#4207)

### Fixes

- Fix `SIGABRT` when modifying scope user (#4274)
- Crash during SDK initialization due to corrupted envelope (#4291)
  - Reverts [#4219](https://github.com/getsentry/sentry-cocoa/pull/4219) as potential fix

## 8.34.0

### Features

- Pause replay in session mode when offline (#4264)
- Add replay quality option for Objective-C (#4267)

### Fixes

- Session replay not redacting buttons and other non UILabel texts (#4277)
- Rarely reporting too long frame delays (#4278) by fixing a race condition in the frames tracking logic.
- Crash deserializing empty envelope length>0 (#4281]
- Guard dereferencing of stack frame pointer in SentryBacktrace ([#4268](https://github.com/getsentry/sentry-cocoa/pull/4268))

## 8.33.0

### Note: Due to a bug (#4280) introduced in this release, we recommend upgrading to [8.35.0](https://github.com/getsentry/sentry-cocoa/releases/tag/8.35.0) or newer.

---

This release fixes a bug (#4230) that we introduced with a refactoring (#4101) released in [8.30.1](https://github.com/getsentry/sentry-cocoa/releases/tag/8.30.1).
This bug caused unhandled/crash events to have the unhandled property and mach info missing, which is required for release health to show events in the unhandled tab. It's essential to mention that this bug **doesn't impact** release health statistics, such as crash-free session or user rates.

### Features

- Support orientation change for session replay (#4194)
- Replay for crashes (#4171)
- Redact web view from replay (#4203)
- Add beforeCaptureViewHierarchy callback (#4210)
- Rename session replay `errorSampleRate` property to `onErrorSampleRate` (#4218)
- Add options to redact or ignore view for Replay (#4228)

### Fixes

- Skip UI crumbs when target or sender is nil (#4211)
- Guard FramesTracker start and stop (#4224)
- Long-lasting TTID/TTFD spans (#4225). Avoid long TTID spans when the FrameTracker isn't running, which is the case when the app is in the background.
- Missing mach info for crash reports (#4230)
- Crash reports not generated on visionOS (#4229)
- Don’t force cast to `NSComparisonPredicate` in TERNARY operator (#4232)
- Fix accessing UI API on bg thread in enrichScope (#4245)
- EXC_BAD_ACCESS in SentryMetricProfiler (#4242)
- Missing `#include <sys/_types/_ucontext64.h>` (#4244)
- Rare flush timeout when called in tight loop (#4257)

### Improvements

- Reduce memory usage of storing envelopes (#4219)
- Skip enriching scope when nil (#4243)

## 8.32.0

### Features

- Add `reportAccessibilityIdentifier` option (#4183)
- Record dropped spans (#4172)

### Fixes

- Session replay crash when writing the replay (#4186)

### Features

- Collect only unique UIWindow references (#4159)

### Deprecated

- options.enableTracing was deprecated. Use options.tracesSampleRate or options.tracesSampler instead. (#4182)

## 8.31.1

### Fixes

- Session replay video duration from seconds to milliseconds (#4163)

## 8.31.0

### Features

- Include the screen names in the session replay (#4126)

### Fixes

- Properly handle invalid value for `NSUnderlyingErrorKey` (#4144)
- Session replay in buffer mode not working (#4160)

## 8.30.1

### Fixes

- UIKitless configurations now produce a module with a different name (#4140)
- Sentry Replay Serialized Breadcrumbs include level name ([#4141](https://github.com/getsentry/sentry-cocoa/pull/4141))

## 8.30.0

### Features

- Restart replay session with mobile session (#4085)
- Add pause and resume AppHangTracking API (#4077). You can now pause and resume app hang tracking with `SentrySDK.pauseAppHangTracking()` and `SentrySDK.resumeAppHangTracking()`.
- Add `beforeSendSpan` callback (#4095)

### Fixes

- `storeEnvelope` ends session for unhandled errors (#4073)
- Deprecate `SentryUser.segment`(#4092). Please remove usages of this property. We will remove it in the next major.
- Double-quoted include in framework header (#4115)
- Sentry Replay Network details should be available without Tracing (#4091)

## 8.29.1

### Fixes

- Fix potential deadlock in app hang detection (#4063)
- Swizzling of view controllers `loadView` that don't implement `loadView` (#4071)

## 8.29.0

### Features

- Add a touch tracker for replay (#4041)
- Add enableMetricKitRawPayload (#4044)
- Resume session replay when app enters foreground (#4053)

### Fixes

- `SentryCrashMonitor_CPPException.cpp` compilation using Xcode 16b1 (#4051)

## 8.28.0

### Features

- Add replay quality option (#4035)

## 8.27.0

### Features

- Add breadcrumbs to session replay (#4002)
- Add start time to network request breadcrumbs (#4008)
- Add C++ exception support for `__cxa_rethrow` (#3996)
- Add beforeCaptureScreenshot callback (#4016)
- Disable SIGTERM reporting by default (#4025). We added support
  for SIGTERM reporting in the last release and enabled it by default.
  For some users, SIGTERM events were verbose and not actionable.
  Therefore, we disable it per default in this release. If you'd like
  to receive SIGTERM events, set the option `enableSigtermReporting = true`.

### Improvements

- Stop FramesTracker when app is in background (#3979)
- Speed up adding breadcrumbs (#4029, #4034)
- Skip evaluating log messages when not logged (#4028)

### Fixes

- Fix retrieving GraphQL operation names crashing ([#3973](https://github.com/getsentry/sentry-cocoa/pull/3973))
- Fix SentryCrashExceptionApplication subclass problem (#3993)
- Fix wrong value for `In Foreground` flag on UIKit applications (#4005)
- Fix a crash in baggageEncodedDictionary (#4017)
- Session replay wrong video size (#4018)

## 8.26.0

### Features

- Add SIGTERM support ([#3895](https://github.com/getsentry/sentry-cocoa/pull/3895))

### Fixes

- Fix data race when calling reportFullyDisplayed from a background thread (#3926)
- Ensure flushing envelopes directly after capturing them (#3915)
- Unable to find class: SentryCrashExceptionApplication (#3957)
- Clang error for Xcode 15.4 (#3958)
- Potential deadlock when starting the SDK (#3970)

### Improvements

- Send Cocoa SDK features (#3948)

## 8.25.2

### Features

The following two features, disabled by default, were mistakenly added to the release. We usually only add features in minor releases.

- Add option to use own NSURLSession for transport (#3811)
- Support sending GraphQL operation names in HTTP breadcrumbs (#3931)

### Fixes

- 'SentryFileManager+Test.h' file not found (#3950)

## 8.25.1

### Fixes

- Ignore SentryFramesTracker thread sanitizer data races (#3922)
- Handle no releaseName in WatchDogTerminationLogic (#3919)
- Stop SessionReplay when closing SDK (#3941)

### Improvements

- Remove not needed lock for logging (#3934)
- Session replay Improvements (#3877)
  - Use image average color and text font color to redact session replay
  - Removed iOS 16 restriction from session replay
  - Performance improvement

## 8.25.0

### Features

- Add Session Replay, which is **still experimental**. (#3625)
  - Access is limited to early access orgs on Sentry. If you're interested, [sign up for the waitlist](https://sentry.io/lp/mobile-replay-beta/)

### Fixes

- Crash due to a background call to -[UIApplication applicationState] (#3855)
- Save framework without UIKit/AppKit as Github Asset for releases (#3858)
- Fix crash associated with runtime collision in global C function names (#3862)
- Remove wrong error log in SentryCoreDataTracker (#3894)
- Don't transmit device boot time in envelopes enriched with crash data (#3912, #3916)

### Improvements

- Capture transactions on a background thread (#3892)

## 8.25.0-alpha.0

### Features

- Add Session Replay, which is **still experimental**. (#3625)
  - Access is limited to early access orgs on Sentry. If you're interested, [sign up for the waitlist](https://sentry.io/lp/mobile-replay-beta/)

### Fixes

- Crash due to a background call to -[UIApplication applicationState] (#3855)
- Save framework without UIKit/AppKit as Github Asset for releases (#3858)
- Fix crash associated with runtime collision in global C function names (#3862)
- Remove wrong error log in SentryCoreDataTracker (#3894)

## 8.24.0

### Features

- Add timing API for Metrics (#3812):
- Add [rate limiting](https://develop.sentry.dev/sdk/rate-limiting/) for Metrics (#3838)
- Data normalization for Metrics (#3843)

## 8.23.0

### Features

- Add Metrics API (#3791, #3799): Read our [docs](https://docs.sentry.io/platforms/apple/metrics/) to learn
  more about how to use the Metrics API.
- Pre-main profiling data is now attached to the app start transaction (#3736)
- Release framework without UIKit/AppKit (#3793)
- Add the option swizzleClassNameExcludes (#3813)

### Fixes

- Don't run onCrashedLastSession for nil Events (#3785)
- Redistributable static libraries should never be built with module debugging enabled (#3800)
- Fixed certain views getting loaded twice when adding a child view controller (#3753)
- Fixed broken imports in SentrySwiftUI Carthage build (#3817)
- Fix NSInvalidArgumentException for `NSError sentryErrorWithDomain` (#3819)
- Again fix runtime error when including Sentry as a static lib (#3820)
- Fix crash in hasUnfinishedChildSpansToWaitFor (#3821)

## 8.22.4

### Fixes

- CFBundleShortVersionString in the Info.plist file is invalid (#3787)

## 8.22.3

### Fixes

- Sentry.framework does not support the minimum OS Version specified in the Info.plist (#3774)
- Add reference to Swift classes for hybrid SDKs (#3771)

## 8.22.3-beta.0

### Fixes

- Sentry.framework does not support the minimum OS Version specified in the Info.plist (#3774)
- Add reference to Swift classes for hybrid SDKs (#3771)

## 8.22.2

- Fix runtime error when including Sentry as a static lib (#3764)
- Fix Mac Catalyst support for the prebuilt XCFramework used by SPM and Carthage (#3767)

## 8.22.1

### Fixes

- Checksum error when resolving the SDK via SPM (#3760)

## 8.22.0

**Warning:** this version is not working with SPM

### Improvements

- **SPM uses a prebuilt XCFramework and remove SentryPrivate (#3623)**:
  We now provide a prebuilt XCFramework for SPM, which speeds up your build and allows us to write
  more code in Swift. To make this happen, we had to remove the SentryPrivate target for SPM and
  CocoaPods, which you shouldn't have included directly.

### Fixes

- Write NSException reason for crash report (#3705)
- Add context to event with CrashIntegration disabled (#3699)

## 8.21.0

> [!Important]
> This version introduced an issue for app launch profiling **only for macOS apps that run without a sandbox** (i.e. distributed outside the Mac App Store).
> This issue could lead to starting the app launch profiler even when it's not configured via the options.
> We recommend upgrading to at least version 8.49.2.

### Features

- Add support for Sentry [Spotlight](https://spotlightjs.com/) (#3642), which is basically Sentry
  for development. Read our [blog post](https://blog.sentry.io/sentry-for-development/) to find out more.
- Add field `SentrySDK.detectedStartUpCrash` (#3644)
- Automatically profile app launches (#3529)
- Use CocoaPods resource_bundles for PrivacyInfo (#3651)
- Make tags of SentryScope public (#3650)

### Improvements

- Cache installationID async to avoid file IO on the main thread when starting the SDK (#3601)
- Add reason for NSPrivacyAccessedAPICategoryFileTimestamp (#3626)

### Fixes

- Finish TTID span when transaction finishes (#3610)
- Don't take screenshot and view hierarchy for app hanging (#3620)
- Remove `free_storage` and `storage_size` from the device context (#3627), because Apple forbids sending
  information retrieved via `NSFileSystemFreeSize` and `NSFileSystemSize` off a device; see
  [Apple docs](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files/describing_use_of_required_reason_api?language=objc).
- Make SentryFramesTracker available for HybridSDKs ([#3683](https://github.com/getsentry/sentry-cocoa/pull/3683))
- Make SentrySwizzle available for HybridSDKs ([#3684](https://github.com/getsentry/sentry-cocoa/pull/3684))
- Move headers reference out of "extern C" (#3690)

## 8.21.0-beta.0

### Features

- Add support for Sentry [Spotlight](https://spotlightjs.com/) (#3642), which is basically Sentry
  for development. Read our [blog post](https://blog.sentry.io/sentry-for-development/) to find out more.
- Add field `SentrySDK.detectedStartUpCrash` (#3644)
- Automatically profile app launches (#3529)
- Use CocoaPods resource_bundles for PrivacyInfo (#3651)
- Make tags of SentryScope public (#3650)

### Improvements

- Cache installationID async to avoid file IO on the main thread when starting the SDK (#3601)
- Add reason for NSPrivacyAccessedAPICategoryFileTimestamp (#3626)

### Fixes

- Finish TTID span when transaction finishes (#3610)
- Don't take screenshot and view hierarchy for app hanging (#3620)
- Remove `free_storage` and `storage_size` from the device context (#3627), because Apple forbids sending
  information retrieved via `NSFileSystemFreeSize` and `NSFileSystemSize` off a device; see
  [Apple docs](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files/describing_use_of_required_reason_api?language=objc).

## 8.20.0

### Features

- Add visionOS as device family (#3548)
- Add VisionOS Support for Carthage (#3565)

### Fixes

- Move header reference out of "extern C" (#3538)
- Clarify FramesTracker log message (#3570)
- Fix rare battery breadcrumbs crash (#3582)
- Fix synchronization issue in FramesTracker (#3571)
- Fix SentryFileManager logs warning for .DS_Files (#3584)
- Fix FileManager logs info instead of error when a path doesn't exist (#3594)

## 8.19.0

### Features

- Send debug meta for app start transactions (#3543)

### Fixes

- Fix typo in BUILD_LIBRARY_FOR_DISTRIBUTION variable in Makefile (#3488)
- Remove dispatch queue metadata collection to fix crash (#3522)
- Make SentryScope.useSpan non-blocking (#3568)
- Don't override `sentry-trace` and `baggage` headers (#3540)

## 8.18.0

### Features

- Add frames delay to transactions and spans (#3487, #3496)
- Add slow and frozen frames to spans (#3450, #3478)
- Split up UIKit and App Init App Start Span (#3534)
- Prewarmed App Start Tracing is stable (#3536)

### Fixes

- TTFD waits for next drawn frame (#3505)
- Fix TTID/TTFD for app start transactions (#3512): TTID/TTFD spans and measurements for app start transaction now include the app start duration.
- Crash when adding a crumb for a timezone change (#3524)
- Fix a race condition in SentryTracer (#3523)
- App start ends when first frame is drawn when performanceV2 is enabled (#3530)
- Use correct rendered frames timestamp for TTID/TTFD and app start (#3531)
- Missing transactions when not calling `reportFullyDisplayed` (#3477)

## 8.17.2

### Fixes

- **Fix marking manual sessions as crashed (#3501)**: When turning off autoSessionTracking and manually starting and ending sessions, the SDK didn't mark sessions as crashed when sending a crash event to Sentry. This is fixed now.

## 8.17.1

### Fixes

- Crash when UINavigationController doesn't have rootViewController (#3455)
- Crash when synchronizing invalid JSON breadcrumbs to SentryWatchdogTermination (#3458)
- Check for NULL in binary image cache (#3469)
- Threading issues in binary image cache (#3468)
- Finish transaction for external view controllers (#3440)

## 8.17.0

### Features

- SwiftUI support is no longer in Beta (#3441)

## 8.16.1

### Fixes

- Fix inaccurate number of frames for transactions (#3439)

## 8.16.0

### Features

- Add screen name to app context (#3346)
- Add cache directory option (#3369)

### Fixes

- Infinite loop when parsing MetricKit data (#3395)
- Fix incorrect implementation in #3398 to work around a profiling crash (#3405)
- Fix crash in SentryFramesTracker (#3424)

### Improvements

- Build XCFramework with Xcode 15 (#3415)

The XCFramework attached to GitHub releases is now built with Xcode 15.

## 8.15.2

### Fixes

- Crash when logging from certain profiling contexts (#3390)

## 8.15.1

### Fixes

- Crash when initializing SentryHub manually (#3374)

## 8.15.0

### Features

- Enrich error events with any underlying NSErrors reported by Cocoa APIs (#3230)
- Add experimental visionOS support (#3328)
- Improve OOM detection by ignoring system reboot (#3352)
- Add thread id and name to span data (#3359)

### Fixes

- Reporting app hangs from background (#3298)
- Thread sanitizer data race warnings in ANR tracker, network tracker and span finish (#3303)
- Stop sending empty thread names (#3361)
- Work around edge case with a thread info kernel call sometimes returning invalid data, leading to a crash (#3364)
- Crashes when trace ID is externally modified or profiler fails to initialize (#3365)

## 8.14.2

### Fixes

- Missing `mechanism.handled` is not considered crash (#3353)

## 8.14.1

### Fixes

- SPM build failure involving "unsafe settings" (#3348)

## 8.14.0

### Features

- Sentry can now be used without linking UIKit; this is helpful for using the SDK in certain app extension contexts (#3175)
  **Note:** this is an experimental feature not yet available for with SPM.
  **Warning:** this breaks some SPM integrations. Use 8.14.1 if you integrate using SPM.

- GA of MetricKit integration (#3340)

Once enabled, this feature subscribes to [MetricKit's](https://developer.apple.com/documentation/metrickit) [MXDiagnosticPayload](https://developer.apple.com/documentation/metrickit/mxdiagnosticpayload) data, converts it to events, and sends it to Sentry.
The MetricKit integration subscribes to [MXHangDiagnostic](https://developer.apple.com/documentation/metrickit/mxhangdiagnostic),
[MXDiskWriteExceptionDiagnostic](https://developer.apple.com/documentation/metrickit/mxdiskwriteexceptiondiagnostic),
and [MXCPUExceptionDiagnostic](https://developer.apple.com/documentation/metrickit/mxcpuexceptiondiagnostic).

## 8.13.1

### Fixes

- Always start SDK on the main thread (#3291)
- App hang with race condition for tick counter (#3290)
- Remove "duplicate library" warning (#3312)
- Fix multiple issues in Reachability (#3338)
- Remove unnecessary build settings (#3325)
- Crash in SentryTracer when cancelling timer (#3333)

## 8.13.0

### Fixes

- Remove sync call to main thread from SentryUIDeviceWrapper (#3295)

### Features

- Record changes to network connectivity in breadcrumbs (#3232)
- Add Sampling Decision to Trace Envelope Header (#3286)

## 8.12.0

### Fixes

- Remove warning about non-portable path to file "SentryDsn.h" (#3270)
- Privacy manifest collection purposes type (#3276)
- Fix how profiles were identified in the backend for grouping and issue correlation purposes (#3282)
- Ensure GPU frame data is always sent with profiles even if `enableAutoPerformanceTracing` is `NO` (#3273)
- Gather metric readings fully covering the duration of a profile (#3272)
- Remove spammy logs (#3284)

### Features

- Rename "http.method" to "http.request.method" for network Spans (#3268)

## 8.11.0

### Features

- Distributed tracing without performance (#3196)
- Report database backing store information for Core Data (#3231)
- Add "data use" in privacy manifests (#3259)
- Add required reason API (#3206)

### Fixes

- Report correct units (nanojoules) for profiling energy metrics (#3262)

## 8.10.0

### Features

- Record energy usage estimates for profiling (#3217)

### Fixes

- Remove a noisy NSLog (#3227)
- WatchOS build for Xcode 15 (#3204)

## 8.9.6

### Fixed

- Fix CPU usage collection for upcoming visualization in profiling flamecharts (#3214)

## 8.9.5

### Hybrid SDK support

- Allow profiling from hybrid SDKs (#3194)

## 8.9.4

### Fixes

- Remove linker settings from Package.swift (#3188)
- Free memory returned by backtrace_symbols() in debug builds ([#3202](https://github.com/getsentry/sentry-cocoa/pull/3202))

## 8.9.3

### Fixes

- Reclaim memory used by profiler when transactions are discarded (#3154)
- Crashed session not being reported as crashed (#3183)

## 8.9.2

## Important Note

**Do not use this version** if you use Release Health. It introduces a bug where crashed Sessions would not be reported correctly. This has been fixed in [version `8.9.3`](https://github.com/getsentry/sentry-cocoa/releases/tag/8.9.3).

### Improvements

- Reduced macOS SDK footprint by 2% (#3157) with similar changes for tvOS and watchOS (#3158, #3159, #3161)

### Fixes

- Fix a crash in SentryCoreDataTracker for nil error params (#3152)

## 8.9.1

### Fixes

- Fix potential unbounded memory growth when starting profiled transactions from non-main contexts (#3135)

## 8.9.0

### Features

- Symbolicate locally only when debug is enabled (#3079)

This change considerably speeds up retrieving stacktraces, which the SDK uses for captureMessage, captureError and also for reporting file IO or DB operation on the main thread.

- Sanitize HTTP info from breadcrumbs, spans and events (#3094)

### Breaking change

- Renamed `enableTimeToFullDisplay` to `enableTimeToFullDisplayTracing` (#3106)
  - This is an experimental feature and may change at any time without a major revision.

## 8.9.0-beta.1

### Features

- Symbolicate locally only when debug is enabled (#3079)
- Sanitize HTTP info from breadcrumbs, spans and events (#3094)

## 8.8.0

### Features

- Experimental support for Swift Async stacktraces (#3051)
- Cache binary images to be used for crashes (#2939)

### Fixes

- Fix a data race for `SentryId.empty` (#3072)
- Duplicated HTTP breadcrumbs (#3058)
- Expose SentryPrivate and SentrySwiftUI schemes for cartahge clients that have `--no-use-binaries` option (#3071)
- Convert last remaining `sprintf` call to `snprintf` (#3077)
- Fix a crash when serializing profiling data (#3092)

## 8.7.4

### Fixes

- Changed `Trace` serialized value of `sampled` from string to boolean (#3067)

### Breaking Changes

- Removed `nameForSentrySampleDecision` which shouldn't have been public (#3067)

## 8.7.3

### Fixes

- Convert one of the two remaining usages of `sprintf` to `snprintf` (#2866)
- Fix use-after-free ASAN warning (#3042)
- Fix memory leaks in the profiler (#3055, #3061)

## 8.7.2

### Fixed

- Fix crashes in profiling serialization race condition (#3018, #3035)
- Fix a crash for user interaction transactions (#3036)

## 8.7.1

### Fixes

- Add `sent_at` to envelope header (#2859)
- Fix import of `User` & `Breadcrumb` (#3017)

## 8.7.0

### Features

- Allow starting the SDK with an initial scope (#2982)
- Swift Error Names (#2960)

```Swift
enum LoginError: Error {
    case wrongUser(id: String)
    case wrongPassword
}

SentrySDK.capture(error: LoginError.wrongUser("12345678"))
```

For the Swift error above Sentry displays:

| sentry-cocoa SDK | Title        | Description                           |
| ---------------- | ------------ | ------------------------------------- |
| Since 8.7.0      | `LoginError` | `wrongUser(id: "12345678") (Code: 1)` |
| Before 8.7.0     | `LoginError` | `Code: 1`                             |

[Customized error descriptions](https://docs.sentry.io/platforms/apple/usage/#customizing-error-descriptions) have precedence over this feature.
This change has no impact on grouping of the issues in Sentry.

### Fixes

- Propagate span when copying scope (#2952)
- Remove "/" from crash report file name (#3005)

## 8.6.0

### Features

- Send trace origin (#2957)

[Trace origin](https://develop.sentry.dev/sdk/performance/trace-origin/) indicates what created a trace or a span. Not all transactions and spans contain enough information to tell whether the user or what precisely in the SDK created it. Origin solves this problem. The SDK now sends origin for transactions and spans.

- Create User and Breadcrumb from map (#2820)

### Fixes

- Improved performance serializing profiling data (#2863)
- Possible crash in Core Data tracking (#2865)
- Ensure the current GPU frame rate is always reported for concurrent transaction profiling metrics (#2929)
- Move profiler metric collection to a background queue (#2956)

### Removed

- Remove experimental `stitchAsyncCode` from SentryOptions (#2973)

The `stitchAsyncCode` experimental option has been removed from `SentryOptions` as its behavior was unpredictable and sometimes resulted in unexpected errors. We plan to add it back once we fix it, but we don't have an ETA for it.

## 8.5.0

### Features

- feat: Core data operation in the main thread (#2879)

### Fixes

- Crash when serializing invalid objects (#2858)
- Don't send screenshots with either width or height of 0 (#2876)
- GPU frame alignment with stack traces in profiles (#2856)

## 8.4.0

### Features

- Time to initial and full display (#2724)
- Add time-to-initial-display and time-to-full-display measurements to ViewController transactions (#2843)
- Add `name` and `geo` to User (#2710)

### Fixes

- Correctly track and send GPU frame render data in profiles (#2823)
- Xcode 14.3 compiling issue regarding functions declaration with no prototype (#2852)

## 8.3.3

### Fixes

- View hierarchy not sent for crashes (#2781)
- Crash in Tracer for idle timeout (#2834)

## 8.3.2

### Features

- Add CPU core count in device context (#2814)

### Fixes

- Updating AppHang state on main thread (#2793)
- App Hang report crashes with too many threads (#2811)

### Improvements

- Remove not needed locks in SentryUser (#2809)

## 8.3.1

### Fixes

- Stop using UIScreen.main (#2762)
- Profile timestamp alignment with transactions (#2771) and app start spans (#2772)
- Fix crash when compiling profiling data during transaction serialization (#2786)

## 8.3.0

### Important Note

This release can cause crashes when Profiling is enabled (#2779). Please update to `8.3.1`.

### Fixes

- Crash in AppHangs when no threads (#2725)
- MetricKit stack traces (#2723)
- InApp for MetricKit stack traces (#2739)
- Mutating while enumerating crash in Tracer (#2744)
- Normalize profiling timestamps relative to transaction start (#2729)

## 8.2.0

### Features

- Add enableTracing option (#2693)
- Add isMain thread to SentryThread (#2692)
- Add `in_foreground` to App Context (#2692)
- Combine UIKit and SwiftUI transactions (#2681)

### Fixes

- Cleanup AppHangTracking properly when closing SDK (#2671)
- Add EXC_BAD_ACCESS subtypes to events (#2667)
- Keep status of auto transactions when finishing (#2684)
- Fix atomic import error for profiling (#2683)
- Don't create breadcrumb for UITextField editingChanged event (#2686)
- Fix EXC_BAD_ACCESS in SentryTracer (#2697)
- Serialization of nullable booleans (#2706)

### Improvements

- Change debug image type to macho (#2701)

This change might mark 3rd party library frames as in-app, which the SDK previously marked as system frames.

## 8.1.0

### Features

- Add thread information to File I/O spans (#2573)
- AttachScreenshots is GA (#2623)
- Gather profiling timeseries metrics for CPU usage and memory footprint (#2493)
- Change SentryTracedView `transactionName` to `viewName` (#2630)

### Fixes

- Support uint64 in crash reports (#2631, #2642, #2663)
- Always fetch view hierarchy on the main thread (#2629)
- Carthage Xcode 14 compatibility issue (#2636)
- Crash in CppException Monitor (#2639)
- fix: Disable watchdog when disabling crash handler (#2621)
- MachException Improvements (#2662)

## 8.0.0

### Features

This version adds a dependency on Swift.
We renamed the default branch from `master` to `main`. We are going to keep the `master` branch for backwards compatibility for package managers pointing to the `master` branch.

### Features

- Properly demangle Swift class name (#2162)
- Change view hierarchy attachment format to JSON (#2491)
- Experimental SwiftUI performance tracking (#2271)
- Enable [File I/O Tracking](https://docs.sentry.io/platforms/apple/performance/instrumentation/automatic-instrumentation/#file-io-tracking) by default (#2497)
- Enable [AppHang Tracking](https://docs.sentry.io/platforms/apple/configuration/app-hangs/) by default (#2600)
- Enable [Core Data Tracing](https://docs.sentry.io/platforms/apple/performance/instrumentation/automatic-instrumentation/#core-data-tracking) by default (#2598)
- [User Interaction Tracing](https://docs.sentry.io/platforms/apple/performance/instrumentation/automatic-instrumentation/#user-interaction-tracing) is stable and enabled by default(#2503)
- Add synthetic for mechanism (#2501)
- Enable CaptureFailedRequests by default (#2507)
- Support the [`SENTRY_DSN` environment variable](https://docs.sentry.io/platforms/apple/guides/macos/configuration/options/#dsn) on macOS (#2534)
- Experimental MetricKit integration (#2519) for
  - [MXHangDiagnostic](https://developer.apple.com/documentation/metrickit/mxhangdiagnostic)
  - [MXDiskWriteExceptionDiagnostic](https://developer.apple.com/documentation/metrickit/mxdiskwriteexceptiondiagnostic)
  - [MXCPUExceptionDiagnostic](https://developer.apple.com/documentation/metrickit/mxcpuexceptiondiagnostic)
- Add a timeout for auto-generated transactions (#2535)

### Fixes

- Errors shortly after `SentrySDK.init` now affect the session (#2430)
- Use the same default environment for events and sessions (#2447)
- Increase `SentryCrashMAX_STRINGBUFFERSIZE` to reduce the instances where we're dropping a crash due to size limit (#2465)
- `SentryAppStateManager` correctly unsubscribes from `NSNotificationCenter` when closing the SDK (#2460)
- The SDK no longer reports an OOM when a crash happens after closing the SDK (#2468)
- Don't capture zero size screenshots ([#2459](https://github.com/getsentry/sentry-cocoa/pull/2459))
- Use the preexisting app release version format for profiles (#2470)
- Don't add out of date context for crashes (#2523)
- Fix ARC issue for FileManager (#2525)
- Remove delay for deleting old envelopes (#2541)
- Fix strong reference cycle for HttpTransport (#2552)
- Deleting old envelopes for empty DSN (#2562)
- Remove `SentrySystemEventBreadcrumbs` observers with the most specific detail possible (#2489)

### Breaking Changes

- Rename `- [SentrySDK startWithOptionsObject:]` to `- [SentrySDK startWithOptions:]` (#2404)
- Make `SpanProtocol.data` non nullable (#2409)
- Mark `- [SpanProtocol setExtraValue:forKey:]` as deprecated (#2413)
- Make SpanContext immutable (#2408)
  - Remove tags from SpanContext
  - Remove context property from SentrySpan
- Bump minimum supported OS versions to macOS 10.13, iOS 11, tvOS 11, and watchOS 4 (#2414)
- Make public APIs Swift friendly
  - Rename `SentrySDK.addBreadcrumb(crumb:)` to `SentrySDK.addBreadcrumb(_ crumb:)` (#2416)
  - Rename `SentryScope.add(_ crumb:)` to `SentryScope.addBreadcrumb(_ crumb:)` (#2416)
  - Rename `SentryScope.add(_ attachment:)` to `SentryScope.addAttachment(_ attachment:)` (#2416)
  - Rename `Client` to `SentryClient` (#2403)
- Remove public APIs
  - Remove `SentryScope.apply(to:)` (#2416)
  - Remove `SentryScope.apply(to:maxBreadcrumb:)` (#2416)
  - Remove `- [SentryOptions initWithDict:didFailWithError:]` (#2404)
  - Remove `- [SentryOptions sdkInfo]` (#2404)
  - Make SentrySession and SentrySDKInfo internal (#2451)
- Marks App hang's event stacktrace snapshot as true (#2441)
- Enable user interaction tracing by default (#2442)
- Remove default attachment content type (#2443)
- Rename APM tracking feature flags to tracing (#2450)
  - Rename `SentryOptions.enableAutoPerformanceTracking` to `enableAutoPerformanceTracing`
  - Rename `SentryOptions.enableUIViewControllerTracking` to `enableUIViewControllerTracing`
  - Rename `SentryOptions.enablePreWarmedAppStartTracking` to `enablePreWarmedAppStartTracing`
  - Rename `SentryOptions.enableFileIOTracking` to `enableFileIOTracing`
  - Rename `SentryOptions.enableCoreDataTracking` to `enableCoreDataTracing`
- SentrySDK.close calls flush, which is a blocking call (#2453)
- Bump minimum Xcode version to 13 (#2483)
- Rename `SentryOptions.enableOutOfMemoryTracking` to `SentryOptions.enableWatchdogTerminationTracking` (#2499)
- Remove the automatic `viewAppearing` span for UIViewController APM (#2511)
- Remove the permission context for events (#2529)
- Remove captureEnvelope from Hub and Client (#2580)
- Remove confusing transaction tag (#2574)

## 7.31.5

### Fixes

- Crash in SentryOutOfMemoryScopeObserver (#2557)

## 7.31.4

### Fixes

- Screenshot crashes when application delegate has no window (#2538)

## 7.31.3

### Fixes

- Reporting crashes when restarting the SDK (#2440)
- Core data span status with error (#2439)

## 7.31.2

### Fixes

- Crash in Client when reading integrations (#2398)
- Don't update session for dropped events (#2374)

## 7.31.1

### Fixes

- Set the correct OOM event timestamp (#2394)

## 7.31.0

### Features

- Store breadcrumbs to disk for OOM events (#2347)
- Report pre-warmed app starts (#1969)

### Fixes

- Too long flush duration (#2370)
- Do not delete the app state when OOM tracking is disabled. The app state is needed to determine the app start type on the next app start. (#2382)

## 7.30.2

### Fixes

- Call UIDevice methods on the main thread (#2369)
- Avoid sending profiles with 0 samples or incorrectly deduplicated backtrace elements (#2375)

## 7.30.1

### Fixes

- Fix issue with invalid profiles uploading (#2358 and #2359)

## 7.30.0

### Features

- Profile concurrent transactions (#2227)
- HTTP Client errors (#2308)
- Disable bitcode for Carthage distribution (#2341)

### Fixes

- Stop profiler when app moves to background (#2331)
- Clean up old envelopes (#2322)
- Crash when starting a profile from a non-main thread (#2345)
- SentryCrash writing nan for invalid number (#2348)

## 7.29.0

### Features

- Offline caching improvements (#2263)
- Report usage of stitchAsyncCode (#2281)

### Fixes

- Enable bitcode (#2307)
- Fix moving app state to previous app state (#2321)
- Use CoreData entity names instead of "NSManagedObject" (#2329)

## 7.28.0

### Features

- [Custom measurements API](https://docs.sentry.io/platforms/apple/performance/instrumentation/custom-instrumentation/) (#2268)

### Fixes

- Device info details for profiling (#2205)

### Performance Improvements

- Use double-checked lock for flush (#2290)

## 7.27.1

### Fixes

- Add app start measurement to first finished transaction (#2252)
- Return SentryNoOpSpan when starting a child on a finished transaction (#2239)
- Fix profiling timestamps for slow/frozen frames (#2226)

## 7.27.0

### Features

- Report [start up crashes](https://docs.sentry.io/platforms/apple/guides/ios/) (#2220)
- Add segment property to user (#2234)
- Support tracePropagationTargets (#2217)

### Fixes

- Correctly attribute enterprise builds (#2235)

## 7.26.0

### Features

- [Core Data Tracking](https://docs.sentry.io/platforms/apple/performance/instrumentation/automatic-instrumentation/#core-data-tracking) is stable (#2213)
- [File I/O Tracking](https://docs.sentry.io/platforms/apple/performance/instrumentation/automatic-instrumentation/#file-io-tracking) is stable (#2212)
- Add flush (#2140)
- Add more device context (#2190)

### Fixes

- Sentry-trace header incorrectly assigned to http requests (#2167)
- Use the `component` name source for SentryPerformanceTracker (#2168)
- Add support for arm64 architecture to the device context (#2185)
- Align core data span operations (#2222)

## 7.25.1

### Performance Improvements

- Prewarmed app start detection (#2151)

## 7.25.0

### Features

- Users can [customize the error description](https://docs.sentry.io/platforms/apple/usage/#customizing-error-descriptions) shown in the Sentry UI by providing an NSDebugDescriptionErrorKey value in the error user info dictionary. (#2120)
- Add support for dynamic library (#1726)

### Fixes

- Can't find app image when swizzling (#2124)
- Crash with screenshot is reported twice (#2134)
- Setting SDK name through `options[sdk][name]` shouldn't clear version (#2139)

## 7.24.1

### Fixes

- Remove Media Library Permission check from permission observer (#2123)

## 7.24.0

### Features

- App permissions are now also included when running from an app extension (#2106)
- Report App Memory Usage (#2027)
- Include app permissions with event (#1984)
- Add culture context to event (#2036)
- Attach view hierarchy to events (#2044)
- Clean up SentryOptions: added `enableCrashHandler` and deprecated `integrations` (#2049)
- Integrations send the [transaction name source](https://develop.sentry.dev/sdk/event-payloads/transaction/#transaction-annotations) (#2076)
- Added extra logs when creating automatic transactions and spans (#2087)

### Fixes

- Fix Swift 5.5 compatibility (#2060)
- Add span finish flag (#2059)
- SentryUser.userId should be nullable (#2071)
- Send time zone name, not abbreviation (#2091)
- Use a prime number for the profiler's sampling rate to reduce the potential for [lock-step](https://stackoverflow.com/a/45471031) issues (#2055).
- Improve App Hangs detection (#2100)
- Send `environment` set from `SentryOptions` or `configureScope` with profiling data (#2095)

## 7.24.0-beta.0

### Features

- Report App Memory Usage (#2027)
- Include app permissions with event (#1984)
- Add culture context to event (#2036)
- Attach view hierarchy to events (#2044)
- Clean up SentryOptions: added `enableCrashHandler` and deprecated `integrations` (#2049)
- Integrations send the [transaction name source](https://develop.sentry.dev/sdk/event-payloads/transaction/#transaction-annotations) (#2076)
- Added extra logs when creating automatic transactions and spans (#2087)

### Fixes

- Fix Swift 5.5 compatibility (#2060)
- Add span finish flag (#2059)
- SentryUser.userId should be nullable (#2071)
- Send time zone name, not abbreviation (#2091)
- Use a prime number for the profiler's sampling rate to reduce the potential for [lock-step](https://stackoverflow.com/a/45471031) issues (#2055).
- Improve App Hangs detection (#2100)
- Send `environment` set from `SentryOptions` or `configureScope` with profiling data (#2095)

## 7.23.0

### Features

- Add sampling configuration for profiling (#2004)
- Add transaction to baggage and trace headers (#1992)

### Fixes

- Log empty samples instead of collecting stacks for idle threads (#2013)
- Remove logging that could occur while a thread is suspended (#2014)
- Handle failure to read thread priority gracefully (#2015)
- Fix address sanitizer compilation error (#1996)

## 7.22.0

### Features

- Read free_memory when the event is captured, not only at SDK startup (#1962)
- Provide private access to SentryOptions for hybrid SDKs (#1991)

### Fixes

- Remove Sentry keys from cached HTTP request headers (#1975)
- Collect samples for idle threads in iOS profiler (#1978)
- Fix removeNonSdkFrames working incorrectly for os users named sentry(#2002)
- Don't override already-set timestamp when finishing Span (#1993)
- Respect existing baggage header instead of overwriting it (#1995)

## 7.21.0

### Features

- Enhance the UIViewController breadcrumbs with more data (#1945)
- feat: Add extra app start span (#1952)
- Add enableAutoBreadcrumbTracking option (#1958)
- Automatic nest spans with the UI life cycle (#1959)
- Upload frame rendering timestamps to correlate to sampled backtraces (#1910)
- Remove PII from auto-generated core data spans (#1982)

### Fixes

- Don't track OOMs for simulators (#1970)
- Properly sanitize the event context and SDK information (#1943)
- Don't send error 429 as `network_error` (#1957)
- Sanitize Span data (#1963)
- Deprecate not needed option `sdkInfo` (#1960)
- Crash in profiling logger (#1964)

## 7.20.0

### Features

- Add screenshot at crash (#1920)
- Track timezone changes as breadcrumbs (#1930)
- Add sample rate in the baggage header, remove Userid and Transaction (#1936)

## 7.19.0

### Features

- Add main thread ID to profiling payload (#1918)
- Add App Hangs tracking (#1906)

### Fixes

- Remove WebKit optimization check (#1921)
- Detect prewarmed starts with env variable (#1927)

## 7.18.1

### Fixes

- Fix high percentage of slow frames (#1915)

## 7.18.0

### Features

- Replace tracestate header with baggage (#1867)

### Fixes

- Discard long-lasting auto-generated transactions (#1903)
- Unset scope span when finishing idle transaction (#1902)
- Set max app start duration to 60s (#1899)
- Screenshot wrongly attached in crash events (#1901)

## 7.17.0

### Features

- Implement description for SentryBreadcrumb (#1880)

### Fixes

- Propagate configured SDK info from options to events (#1853)
- Stop reporting pre warmed app starts (#1896)

## 7.16.1

### Fixes

- Fix reporting wrong OOM when starting SDK twice (#1878)
- Fix JSON conversion error message (#1856)
- Transaction tag and data serialization (#1826)

## 7.16.0

### Features

- UI event transactions for clicks (#1784)
- Collect queue label information for profiles (#1828)
- Use the macho format for debug information in Profiling (#1830)
- Allow partial SDK info override (#1816)

### Fixes

- Hub uses its scope (#1821)

## 7.15.0

### Features

- Add profile data category for rate limiting (#1799)
- Allow setting SDK info with Options initWithDict (#1793)
- Remove ViewController name match for swizzling (#1802)

### Fixes

- Apply patch for SentryCrashCachedData (#1790)
- Fix getting class data mask in SentryCrash (#1788)
- Use pod_target_xcconfig for Podspec #1792
- Case sensitive header import error (#1794)
- Parsing of output from backtrace_symbols() (#1782)

## 7.14.0

- fix: User feedback crash (#1766)
- feat: Attach screenshots for errors (#1751)
- fix: Remove authenticated pointer stripping for iOS backtraces (#1757)
- perf: Filter binary images on Sentry Crash (#1767)
- fix: NSURL warning during SDK initialization (#1764)

## 7.13.0

If you are using self-hosted Sentry, this version requires Sentry version >= [21.9.0](https://github.com/getsentry/relay/blob/master/CHANGELOG.md#2190)
to work or you have to manually disable sending client reports via the `sendClientReports` option.

- feat: Add Client Reports (#1733)
- fix: enableProfiling option via initWithDict (#1743)

## 7.12.0

### Important notice

This release contains a fix for the sampling of transactions. The SDK applied both sample rates for events and transactions when capturing transactions. Previously, when setting sampleRate to 0.0, the SDK would discard all transactions.
This is fixed now by ignoring the sampleRate for transactions. If you use custom values for sampleRate and traceSampleRate or traceSampler, this change will have an impact on you.

If you are using profiling and self-hosted Sentry, this version requires Sentry version >= [22.3.0](https://github.com/getsentry/relay/releases/tag/22.3.0).

### Various fixes & improvements

- fix: Avoid race condition in SentryCrash (#1735)
- fix: Possible endless loop for onCrashedLastRun (#1734)
- fix: Wrongly sampling transactions (#1716)
- feat: Add flag for UIViewControllerTracking (#1711)
- feat: Add more info to touch event breadcrumbs (#1724)
- feat: Add support for profiling on iOS (#1652) by @armcknight

## 7.12.0-beta.0

### Various fixes & improvements

- feat: Add support for profiling on iOS (#1652) by @armcknight

## 7.11.0

- feat: Add CoreData performance tracking (#1682)
- fix: Detecting ANRs as false OOMs (#1695)

## 7.10.2

- fix: Crash in UIViewControllerSwizzling (#1692)

## 7.10.1

- fix: Swizzling UIViewControllers crash (#1670)
- feat: Expose Installation ID for Hybrid SDKs (#1680)
- fix: SentryNSURLSessionTaskSearch using invalid nil parameter with NSURLSession (#1669)

## 7.10.0

- fix: Always tracks App start for Hybrid SDKs (#1662)
- feat: Send SDK integrations (#1647)
- fix: Don't track OOMs for unit tests (#1651)
- fix: Add verification for vendor UUID in OOM logic (#1648)
- fix crash in dirContentsCount() when dir == NULL (#1658)

## 7.9.0

- fix: Crash in SentrySubClassFinder (#1635)
- fix: Set timestamp in init of event (#1629)
- fix: Load invalid CrashState json (#1625)
- feat: Auto I/O spans for NSData (#1557)

## 7.8.0

- feat: Support for fatalError, assert, precondition (#1596)
- feat: Include unfinished spans in transactions (#1592)
- build: Disable NSAssertions for Release Builds (#1545)

## 7.7.0

- feat: Send Locale with Events (#1539)

## 7.6.1

- fix: iOS13-Swift build (#1522)
- fix: Check task support on setState: (#1523)

## 7.6.0

- fix: Create span for loadView (#1495)
- feat: Add flag to control network requests breadcrumbs (#1505)
- feat: Support for ignored signals with SIGN_IGN (#1489)

## 7.5.4

- fix: Sending OOM when SDK is closed (#1487)

## 7.5.3

- fix: Use swizzling instead of KVO for network tracking (#1452)

## 7.5.2

### Various fixes & improvements

- fix: AppStart Transaction for Apps Using UIScenes (#1427) by @brustolin

## 7.5.1

- fix: SentryOptions initWithDict type errors (#1443)
- fix: Transaction default status should be OK (#1439)
- fix: AppStart Transaction for Apps Using UIScenes (#1427)

## 7.5.0

- feat: Add one flag to disable all swizzling (#1430)
- fix: Dispatch Queue ARC Warning for RN (#1424)
- fix: Dictionary Key cannot be nil, in SentryPerformanceTracer (#1434)

## 7.4.8

- fix: Crash when objc_getClassList returns different values (#1420)

## 7.4.7

- fix: Only enable APM when traceRate set (#1417)
- fix: Crash in Span when Tracer nil (#1416)
- fix: Instrumenting multiple UIViewControllers (#1409)
- fix: Clear unfinished transaction in UIViewController APM (#1408)

## 7.4.6

- fix: Crash when Getting Subclasses (#1396)

## 7.4.5

- fix: Remove Check for Original Method Call When Swizzling (#1383)
- fix: Init for Span, Tracer, Transaction (#1385)

## 7.4.4

- fix: Crash for Call Should be on Main Thread (#1371)

## 7.4.3

- fix: Crash for Custom ViewController init on iOS 15 (#1361)

## 7.4.2

- fix: Crash When Observing Span Finished (#1360)

## 7.4.1

- fix: HTTP instrumentation KVO crash (#1354)

## 7.4.0

- feat: Add enableNetworkTracking flag (#1349)
- fix: Memory Leak for Span (#1352)

## 7.3.0

- fix: Trying to swizzle a class without a library name (#1332)

## 7.3.0-beta.0

- fix: maxBreadcrumb zero crashes when adding (#1326)

- feat: Add tracestate HTTP header support (#1291)

## 7.2.10

- No documented changes.

## 7.2.9

- Nothing

## 7.2.8

- fix: SpanProtocol add setData for Swift (#1305)
- fix: SentryHub not checking spanContext sampled value (#1318)

## 7.2.7

- fix: Remove Trace Headers below iOS 14.0 (#1309)
- fix: XCFramework output not preserving symlinks for macOS (#1281)

## 7.2.6

- fix: Add Trace Headers below iOS 14.0 (#1302)

## 7.2.5

- fix: Swizzling crash on iOS 13 (#1297)

## 7.2.4

- fix: Sentry HTTP Trace Header Breaking Requests (#1295)
- fix: Apps crash when using a URLSessionTask subclass with currentRequest unavailable (#1294)

## 7.2.3

- fix: Build failure for SPM (#1284)
- fix: Set app state on main thread when terminating (#1272)

## 7.2.2

- fix: Crash when swizzling Nib UIViewController (#1277)

## 7.2.1

This release fixes a crucial issue for auto performance instrumentation that caused crashes when using nested ViewControllers.

- fix: Callback issue for auto performance (#1275)

## 7.2.0

This release contains support for [auto performance instrumentation](https://docs.sentry.io/platforms/apple/performance/instrumentation/automatic-instrumentation/)
for ViewControllers, HTTP requests, app start and slow and frozen frames.

### Auto Performance Features

- feat: Auto UI Performance Instrumentation (#1105, #1150, #1136, #1139, #1042, #1264, #1164, #1202, #1231, #1242)
- feat: Measure slow and frozen frames (#1123)
- feat: Measure app start time (#1111, #1228)
- feat: Add automatic HTTP request performance monitoring (#1178, #1237, #1250, #1255)
- feat: Add tags to Sentry Span (#1243)
- feat: Sub-millis precision for spans and events (#1234)
- feat: Add Sentry Trace HTTP Header (#1213)

### More Features

- feat: Add flag stichAsyncCode (#1172)
- feat: Support XCFramework for Carthage (#1175)
- feat: Add isEnabled property in SentrySDK (#1265)
- feat: Add breadcrumbs for HTTP requests (#1258)
- feat: Add clearAttachments to Scope (#1195)
- feat: Expose tracked screen frames (#1262)
- feat: Expose AppStartMeasurement for Hybrid SDKs (#1251)

### Fixes

- fix: Remove invalid excludes from `Package.swift` (#1169)
- fix: Compile failure with C99 (#1224)
- fix: Race on session task (#1233)
- fix: Remove tags and data if empty for Span (#1246)

### Performance Improvements

- perf: Scope sync to SentryCrash (#1193)

## 7.2.0-beta.9

- feat: Expose tracked screen frames (#1262)
- feat: Expose AppStartMeasurement for Hybrid SDKs (#1251)
- fix: Span serialization HTTP data in wrong place. (#1255)
- feat: Add tags to Sentry Span (#1243)

## 7.2.0-beta.8

- fix: Remove tags and data if empty for Span (#1246)
- fix: Race Conditions in NetworkTracker (#1250)
- fix: Don't create transactions for HTTP Requests. (#1237)

## 7.2.0-beta.7

- fix: Swizzle only inApp ViewControllers (#1242)
- feat: Add Sentry Trace HTTP Header (#1213)
- feat: Sub-millis precision for spans and events (#1234)
- fix: Race on session task (#1233)

## 7.2.0-beta.6

- fix: ViewController swizzling before iOS 13 (#1231)
- fix: AppStartMeasurement didFinishLaunching is nil (#1228)

## 7.2.0-beta.5

- perf: Scope sync to SentryCrash (#1193)
- fix: Compile failure with C99 (#1224)

## 7.2.0-beta.4

- fix: Add viewAppearing to UIViewController spans (#1202)

## 7.2.0-beta.3

- feat: Add automatic http request performance monitoring (#1178)
- feat: Add clearAttachments to Scope (#1195)

## 7.2.0-beta.2

- feat: Add flag stichAsyncCode (#1172)
- feat: Support XCFramework for Carthage (#1175)
- fix: Remove invalid excludes from `Package.swift` (#1169)

## 7.2.0-beta.1

- feat: Measure slow and frozen frames (#1123)
- fix: Operation names for auto instrumentation (#1164)

## 7.2.0-beta.0

- feat: Measure app start time (#1111)
- feat: Auto UI Performance Instrumentation (#1105, #1150, #1136, #1139, #1042)

## 7.1.4

- fix: Compile failure with C99 (#1224)

## 7.1.3

- feat: Add PrivateSentrySDKOnly (#1131)

## 7.1.2

- fix: Serialization of span description (#1128)

## 7.1.1

- No documented changes. This is the same as 7.1.0. Ignore this release and please use 7.1.2 instead.

## 7.1.0

- fix: Remove SentryUnsignedLongLongValue (#1118)
- feat: Expose SentryDebugImageProvider (#1094)
- docs: Improve code doc on start and endSession (#1098)

## 7.0.3

- fix: Add SentryMechanismMeta to Sentry.h (#1102)

## 7.0.2

- No documented changes. This is the same as 7.0.1. Ignore this release and please use 7.0.3 instead.

## 7.0.1

ref: Prefix TracesSampler with Sentry (#1091)

## 7.0.0

This is a major bump with the [Performance Monitoring API](https://docs.sentry.io/platforms/apple/performance/) and [Out of Memory Tracking](https://docs.sentry.io/platforms/apple/configuration/out-of-memory/), many improvements and a few breaking changes.
For a detailed explanation how to upgrade please checkout the [migration guide](https://docs.sentry.io/platforms/apple/migration/).

### Breaking Changes

- ref: Add SentryMechanismMeta (#1048)
- ref: Align SentryException with unified API (#1026)
- ref: Remove deprecated SentryHub.getScope (#1025)
- ref: Make closeCachedSessionWithTimestamp private (#1022)
- ref: Improve envelope API for Hybrid SDKs (#1020)
- ref: Remove currentHub from SentrySDK (#1019)
- feat: Add maxCacheItems (#1017)
- ref: SentryEvent.timestamp changed to nullable.
- ref: Add read-only scope property to Hub (#975)
- ref: Remove SentryException.userReported (#974)
- ref: Replace SentryLogLevel with SentryLevel (#979)
- fix: Mark frames as inApp (#956)

### Features

- feat: Performance Monitoring API (#909, #977, #961, #932, #919, #992, #1065, #1042, #1079, #1061, #1069, #1066, #1040, #1084)
- feat: Out Of Memory Tracking (#1001, #1015)
- feat: Add close method to SDK (#1046)
- feat: Add start and endSession to SentrySDK (#1021)
- feat: Add urlSessionDelegate option to SentryOptions (#965)

### Fixes

- ref: Set sample rates to default if out of range (#1074): When setting a value `SentryOptions.sampleRate` that is not >= 0.0 and <= 1.0 the SDK sets it to the default of 1.0.
- fix: Release builds in CI (#1076)
- perf: Avoid allocating dict in BreadcrumbTracker (#1027)
- fix: Crash when passing garbage to maxBreadcrumbs (#1018)
- fix: macOS version for Mac Catalyst (#1011)

## 7.0.0-beta.1

### Features and Fixes

- ref: Set sample rates to default if out of range (#1074): When setting a value `SentryOptions.sampleRate` that is not >= 0.0 and <= 1.0 the SDK sets it to the default of 1.0.
- feat: Add trace information from scope to event capture (#1065)
- fix: SentryOptions.tracesSampleRate default value (#1069)
- ref: Discard unfinished spans when capturing transaction (#1066)
- ref: Make calls to customSamplingContext nonnull (#1061)
- ref: Mark async call chains explicitly as such (#1071)
- fix: fix: performance headers (#1079)
- fix: performance headers (#1079)
- fix: Release builds in CI (#1076)

## 7.0.0-beta.0

- feat: Add close method to SDK #1046

## 7.0.0-alpha.5

### Breaking Changes

- ref: Add SentryMechanismMeta #1048: Replaced dict `SentryMechanism.meta` with new class `SentryMechanismMeta`. Moved `SenryNSError` to `SentryMechanismMeta`.

### Features and Fixes

- feat: Async callstacks are being tracked by wrapping the `dispatch_async` and related APIs. #998
- feat: Add transaction to the scope #992
- fix: Pass SentryTracer to span child #1040
- feat: Add span to SentrySDK #1042
- feat: Add urlSessionDelegate option to SentryOptions #965

## 7.0.0-alpha.4

### Breaking Changes

- ref: Align SentryException with unified API #1026: Replaced `SentryException.thread` with `SentryException.threadId` and `SentryException.stacktrace`.
- ref: Remove deprecated SentryHub.getScope #1025: Use `SentryHub.scope` instead.
- ref: Make closeCachedSessionWithTimestamp private #1022
- ref: Improve envelope API for Hybrid SDKs #1020: We removed `SentryClient.storeEnvelope`, which is reserved for Hybrid SDKs.
- ref: Remove currentHub from SentrySDK #1019: We removed `SentrySDK.currentHub` and `SentrySDK.setCurrentHub`. In case you need this methods, please open up an issue.
- feat: Add maxCacheItems #1017: This changes the maximum number of cached envelopes from 100 to 30. You can configure this number with `SentryOptions.maxCacheItems`.

### Features and Fixes

- perf: Avoid allocating dict in BreadcrumbTracker #1027
- feat: Add start and endSession to SentrySDK #1021
- fix: Crash when passing garbage to maxBreadcrumbs #1018
- fix: OutOfMemory exception type #1015
- fix: macOS version for Mac Catalyst #1011

## 7.0.0-alpha.3

- feat: Out Of Memory Tracking #1001

## 7.0.0-alpha.2

### Features

- feat: Performance Monitoring API (#909, #977, #961, #932, #919)

### Breaking Changes

- SentryEvent.timestamp changed to nullable.

## 7.0.0-alpha.1

Features and fixes:

- ref: Add read-only scope property to Hub #975

### Breaking Changes

- ref: Add read-only scope property to Hub #975
- ref: Remove SentryException.userReported #974
- ref: Replace SentryLogLevel with SentryLevel #978

## 7.0.0-alpha.0

**Breaking Change**: This version introduces a change to the grouping of issues. The SDK now sets the `inApp`
flag for frames originating from only the main executable using [CFBundleExecutable](https://developer.apple.com/documentation/bundleresources/information_property_list/cfbundleexecutable).
In previous versions, all frames originating from the application bundle were marked as `inApp`. This had the
downside of marking frames of private frameworks inside the bundle as `inApp`. This problem is fixed now.
Applications using static frameworks shouldn't be affected by this change.
For more information on marking frames as inApp [docs](https://docs.sentry.io/platforms/apple/data-management/event-grouping/stack-trace-rules/#mark-in-app-frames).

- fix: Mark frames as inApp #956

## 6.2.1

- fix: Redundant x29 GP register on arm64 and UBSan crash #964

## 6.2.0

With this version, Sentry groups errors by domain and code. MyDomain 1 and MyDomain 2
are going to be two separate issues in Sentry. If you are using self-hosted Sentry,
it requires Sentry version >= v21.2.0 to work. Staying on Sentry < v21.2.0 and upgrading
to this version of the SDK won't do any damage. Sentry will group like in previous
versions, but you will see a new group because we slightly changed the wording. If you
are using sentry.io no action is needed. In case you are not satisfied with this change,
you can take a look at
[SDK fingerprinting](https://docs.sentry.io/platforms/apple/data-management/event-grouping/sdk-fingerprinting/)
to group by domain only.

- fix: Use mechanism meta for error grouping #946
- fix: Sanitize SentryMechanism.data on serialize #947
- feat: Add error to SentryEvent #944
- fix: Mark SentryEvent.message as Nullable #943
- fix: Stacktrace inApp marking on Simulators #942
- feat: Group NSError by domain and code #941
- fix: Discard Sessions when JSON is faulty #939
- feat: Add sendDefaultPii to SentryOptions #923

## 6.1.4

- fix: Sessions for Hybrid SDKs #913

## 6.1.3

- fix: Capture envelope updates session state #906

## 6.1.2

- fix: Clash with KSCrash functions #905

## 6.1.1

- fix: Duplicate symbol clash with KSCrash #902

## 6.1.0

- perf: Improve locks in SentryScope #888

## 6.1.0-alpha.1

- fix: Change maxAttachmentSize from MiB to bytes #891
- feat: Add maxAttachmentSize to SentryOptions #887
- ref: Remove SentryAttachment.isEqual and hash #885
- ref: Remove SentryScope.isEqual and hash #884

## 6.1.0-alpha.0

- feat: Add basic support for attachments #875

## 6.0.12

- fix: Crash in SentrySession.serialize #870

## 6.0.11

- perf: Drop global dispatch queue (#869)
- fix: Increase precision of iso8601 date formatter #860

## 6.0.10

- feat: Add onCrashedLastRun #808
- feat: Add SentrySdkInfo to SentryOptions #859

## 6.0.9

- fix: Serialization of SentryScope #841
- fix: Recrash parsing in SentryCrash #850
- fix: Not crash during crash reporting #849

## 6.0.8

- feat: Add storeEnvelope on SentryClient #836
- perf: Async synching of scope on to SentryCrash #832

## 6.0.7

- fix: Drop Sessions without release name #826
- feat: Bring back SentryOptions.enabled #818
- fix: Remove enum specifier for SentryLevel #822
- feat: Send environment 'production' if nothing was set #825
- fix: Typo for Swift name: UserFeedback #829

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
For a detailed explanation how to updgrade please checkout the [migration guide](https://docs.sentry.io/platforms/apple/migration/).

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

- fix: Make public isEqual \_Nullable #751
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
