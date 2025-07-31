# Decision Log

## Not capturing screenshots for crashes

Date: April 21st 2022
Contributors: @philipphofmann, @brustolin

We decided against capturing screenshots for crashes because we must only call [async-safe functions](https://man7.org/linux/man-pages/man7/signal-safety.7.html) in signal handlers. Capturing a screenshot requires Objcetive-C code, which is not async safe.
We could create the crash report first, write it to disk and then call Objective-C to get the screenshot. The outcome in such a scenario would be undefined, potentially breaking other signal handlers. We decided against this approach because we don't want to break the contract of signal handlers only calling async-safe functions.

Related links:

- https://github.com/getsentry/sentry-cocoa/pull/1751

## Custom SentryHttpStatusCodeRange type instead of NSRange

Date: October 24th 2022
Contributors: @marandaneto, @brustolin and @philipphofmann

We decided not to use the `NSRange` type for the `failedRequestStatusCodes` property of the `SentryNetworkTracker` class because it's not compatible with the specification, which requires the type to be a range of `from` -> `to` integers. The `NSRange` type is a range of `location` -> `length` integers. We decided to use a custom type instead of `NSRange` to avoid confusion. The custom type is called `SentryHttpStatusCodeRange`.

## Manually installing iOS 12 simulators <a name="ios-12-simulators"></a>

Date: October 21st 2022
Contributors: @philipphofmann

We reverted this decision with [remove running unit tests on iOS 12 simulators](#remove-ios-12-simulators).

GH actions will remove the macOS-10.15 image, which contains an iOS 12 simulator on 12/1/22; see https://github.com/actions/runner-images/issues/5583.
Neither the [macOS-11](https://github.com/actions/runner-images/blob/main/images/macos/macos-11-Readme.md#installed-sdks) nor the
[macOS-12](https://github.com/actions/runner-images/blob/main/images/macos/macos-12-Readme.md#installed-sdks) image contains an iOS 12 simulator. GH
[concluded](https://github.com/actions/runner-images/issues/551#issuecomment-788822538) to not add more pre-installed simulators. SauceLabs doesn't
support running unit tests and adding another cloud solution as Firebase TestLab would increase the complexity of CI. Not running the unit tests on
iOS 12 opens a risk of introducing bugs, which has already happened in the past, especially with swizzling. Therefore, we give manually installing
the iOS 12 simulator a try.

Related to [GH-2218](https://github.com/getsentry/sentry-cocoa/issues/2218)

## Adding Swift code in the project

Date: October 1st 2022
Contributors: @brustolin

A Sentry SDK started to be [written in Swift once,](https://github.com/getsentry/raven-swift) but due to ABI not being stable at that time, it got dropped. Since then Swift 5.0 landed and we got ABI stability. We’ve considered adding Swift to our sentry.cocoa SDK since then, but because of some of the trade offs, we’ve postponed that decision.
This changed with our goal to better support SwiftUI. It’s growing in popularity and we need to write code in Swift in order to support it.
SwiftUI support will be available through an additional library, but to support it, we need to be able to demangle Swift class names in Sentry SDK, which can be done by using Swift API.
Since we support SPM, and SPM doesn't support multi-language projects, we need to create two different targets, one with Swift and another with Objective-C code. Because of that, our swift code needs to be public, so we're creating a second module called SentryPrivate, where all swift code will be, and we need an extra cocoapod library.
With this approach, classes from SentryPrivate will not be available when users import Sentry.
We don't mind breaking changes in SentryPrivate, because this is not meant to be use by the user, we going to point this out in the docs.

## Writing breadcrumbs to disk in the main thread

Date: November 15, 2022
Contributors: @kevinrenskers, @brustolin and @philipphofmann

For the benefit of OOM crashes, we write breadcrumbs to disk; see https://github.com/getsentry/sentry-cocoa/pull/2347. We have decided to do this in the main thread to ensure we're not missing out on any breadcrumbs. It's mainly the last breadcrumb(s) that are important to figure out what is causing an OOM. And since we're only appending to an open file stream, the overhead is acceptable compared to the benefit of having accurate breadcrumbs.

## Bump min Xcode version to 13

With adding the [MetricKit integration](https://github.com/getsentry/sentry-cocoa/issues/1661), we need to bump the min Xcode version to 13,
as MetricKit is unavailable on previous Xcode versions. As Xcode 12 doesn't run on macOS 12, and the current Xcode version is 14, we are OK
with that change. With that change, we also have to drop support for
[building platform-specific framework bundles](https://github.com/Carthage/Carthage/tree/a91d086ceaffef65c4a4a761108f3f32c519940c#building-platform-specific-framework-bundles-default-for-xcode-11-and-below)
with Carthage, which was the default for Xcode 11 and below, because the
[workaround](https://github.com/Carthage/Carthage/blob/a91d086ceaffef65c4a4a761108f3f32c519940c/Documentation/Xcode12Workaround.md) for creating a
platform-specific framework bundles only works with Xcode 12.
Carthage has encouraged its users [to use XCFrameworks](https://github.com/Carthage/Carthage/tree/a91d086ceaffef65c4a4a761108f3f32c519940c#getting-started)
since version 0.37.0, released in January 2021. Therefore, it's acceptable to use XCFrameworks for Carthage users.

## Remove the permissions feature

Date: December 14, 2022

We [removed](https://github.com/getsentry/sentry-cocoa/pull/2529) the permissions feature that we added in [7.24.0](https://github.com/getsentry/sentry-cocoa/releases/tag/7.24.0). Multiple people reported getting denied in app review because of permission access without the corresponding Info.plist entry: see [#2528](https://github.com/getsentry/sentry-cocoa/issues/2528) and [2065](https://github.com/getsentry/sentry-cocoa/issues/2065).

## Rename master to main

Date: January 16th, 2023
Contributors: @kahest, @brustolin and @philipphofmann

With 8.0.0, we rename the default branch from `master` to `main`. We will keep the `master` branch for backwards compatibility for package managers pointing to the `master` branch.

## SentrySwiftUI version

Date: January 18th, 2023
Contributors: @brustolin and @philipphofmann

We release experimental SentrySwiftUI cocoa package with the version 8.0.0 because all podspecs file in a repo need to have the same version.

## Tracking package managers

To be able to identify the package manager(PM) being used by the user, we need that the PM identify itself.
Luckily all of the 3 PMs we support do this in some way, mostly by exposing a compiler directive (SPM, COCOA)
or a build setting (CARTHAGE). With this information we can create a conditional compilation that injects the name of
the PM. You can find this in `SentrySDKInfo.m`.

## Usage of `__has_include`

Some private headers add a dependency of a public header, when those private headers are used in a sample project, or referenced from a hybrid SDK, it is treated as part of the project using it, therefore, if it points to a header that is not part of said project, a compilation error will occur. To solve this we make use of `__has_include` to try to point to the SDK version of the header, or to fallback to the direct reference when compiling the SDK.

## Remove running unit tests on iOS 12 simulators <a name="remove-ios-12-simulators"></a>

Date: April 12th 2023
Contributors: @philipphofmann

We use [`xcode-install`](https://github.com/xcpretty/xcode-install) to install some older iOS simulators for test runs [here](https://github.com/getsentry/sentry-cocoa/blob/ff5c1d83bf601bbcd0f5f1070c3abf05310881bd/.github/workflows/test.yml#L174) and [here](https://github.com/getsentry/sentry-cocoa/blob/ff5c1d83bf601bbcd0f5f1070c3abf05310881bd/.github/workflows/test.yml#L343). That project is being sunset, so we would have to find an alternative.

Installing the simulator can take up to 15 minutes, so the current solution slows CI and sometimes leads to timeouts.
We want our CI to be fast and reliable. Instead of running the unit tests on iOS 12, we run UI tests on an iPhone with iOS 12,
which reduces the risk of breaking users on iOS 12. Our unit tests should primarily focus on business logic and shouldn't depend
on specific iOS versions. If we have functionality that risks breaking on older iOS versions, we should write UI tests instead.
For the swizzling of UIViewControllers and NSURLSession, we have UI tests running on iOS 12. Therefore, dropping running unit
tests on iOS 12 simulators is acceptable. This decision reverts [manually installing iOS 12 simulators](#ios-12-simulators).

Related to [GH-2862](https://github.com/getsentry/sentry-cocoa/issues/2862) and

## Remove integration tests from CI <a name="remove-integration-tests-from-ci"></a>

Date: April 17th 2023
Contributors: @brustolin @philipphofmann

Both Alamofire and Home Assistance integration tests are no longer reliable as they keep failing and causing more problems than adding value.
These tests used to work for a while, and we know that the Sentry SDK was not breaking these projects.
Therefore, we have decided to remove the tests and add some key files to our list of risk files.
This way, if these files are changed, we will be reminded to test the changes with other projects.
Additionally, two new 'make' commands(test-alamofire, test-homekit) are being added to the project to assist in testing the Sentry SDK in third-party projects.

Related to [GH-2916](https://github.com/getsentry/sentry-cocoa/pull/2916)

## Async SDK init on main thread

Date: October 11th 2023
Contributors: @philipphofmann, @brustolin

We decided to initialize the SDK on the main thread async when being initialized from a background thread.
We accept the tradeoff that the SDK might not be fully initialized directly after initializing it on a background
thread because scheduling the init synchronously on the main thread could lead to deadlocks, such as https://github.com/getsentry/sentry-cocoa/issues/3277.

Related links:

- https://github.com/getsentry/sentry-cocoa/pull/3291

## Dependency Injection Strategy

Date: November 10th 2023
Contributors: @philipphofmann, @armcknight

Internal classes should ask for all dependencies via their constructor to improve testability.
Public classes should use constructor only asking for a minimal set of public classes and use the
`SentryDependencyContainer`` for resolving internal dependencies. They can and should use an
internal constructor asking for all dependencies like internal classes to improve testability.
A good example of a public class is [SentryClient](https://github.com/getsentry/sentry-cocoa/blob/e89dc54f3fd0c7ad010d9a6c7cb02ac178f3fc33/Sources/Sentry/Public/SentryClient.h#L15-L20),
and for an internal one [SentryTransport](https://github.com/getsentry/sentry-cocoa/blob/e89dc54f3fd0c7ad010d9a6c7cb02ac178f3fc33/Sources/Sentry/include/SentryHttpTransport.h).

Related links:

- [GH PR discussion](https://github.com/getsentry/sentry-cocoa/pull/3246#discussion_r1385134001)

## Move UI tests from SauceLabs to GH action simulators <a name="move-ui-tests-to-gh-actions"></a>

Date: February 20th 2024
Contributors: @brustolin, @philipphofmann, @kahest

As of February 20, 2024, we have severe problems with the UI tests on SauceLabs:

1. Running the UI tests on iOS 16 continuously fails with an internal server error.

```bash
08:43:42 ERR Failed to pass threshold suite=iOS-16
08:43:43 ERR Suite finished. passed=false suite=iOS-16 url=https://app.saucelabs.com/tests/92e4f31ed2e0464caa069ac36fed4a1a
08:43:50 WRN Failed to retrieve the console output. error="internal server error" suite=iOS-16
08:43:52 INF Suites in progress: 0
08:43:59 WRN unable to report result to insights error="internal server error" action=loading-xml-report
08:43:59 WRN unable to report result to insights error="internal server error" action=parsingXML jobID=92e4f31ed2e0464caa069ac36fed4a1a
```

2. The test runs for iOS 17 keep hanging forever and frequently time out.
3. Until February 19, 2024 we had a retry mechanism for running SauceLabs UI tests because they
   frequently failed to tun.

Working with such an unreliable tool in CI is a killer for developer productivity. When looking at
our UI test suite, we currently have one UI test that should run on an actual device: . This test
validates the data from our screen frames logic, and validating that it works correctly on an iPhone
Pro with 120 fps makes sense. Apart from that, running all the UI tests on different simulators in
CI should be enough to surface most of our bugs. Fighting against SauceLabs and not relying on it is
worse than running UI tests on simulators and accepting the fact that they might not capture 100% of
bugs and regressions.

Another major reason why we chose SauceLabs in the past was the support of running UI tests on older
iOS versions, which are not supported on GH action simulators. This was vital when we dealt with
severe bugs when swizzling UIViewControllers. We don’t face that challenge anymore because the
solution is stable, and we don’t receive any bugs anymore. The lowest supported simulator version on
GH actions is currently iOS 13. Given the low market share of iOS 12, it’s acceptable to not run our
UI tests on iOS 12 and lower even though we support them.

All that said, we should replace running UI tests in SauceLabs with running them on different iOS
versions with GH actions.

It’s worth noting that we want to keep running benchmark tests on SauceLabs as they run stable.

## Removing SentryPrivate <a name="removing-sentryprivate"></a>

Date: March 4th 2024
Contributors: @brustolin, @philipphofmann, @kahest

With the necessity of using Swift, we introduced a secondary framework that was a Sentry dependency.
That means we could not write a public API in Swift or access the core classes from Swift code.
Another problem is that some users were experiencing issues when compiling the framework in CI.

Swift is the present and has a long future ahead of it for Apple development. It's less verbose,
requires fewer files, and is more powerful when it comes to language features.

Because of all of this, we decided that we want Swift for the core framework. The only obstacle
is that SPM doesn't support two languages for the same target. To solve this, we exposed
Sentry as a pre-built binary for SPM. This adds the benefit of Sentry not being
compiled with the project, which speeds up build time.

Another challenge we face with this decision is where to host the pre-compiled framework.
We choose to use git release assets. To understand CI changes needed to publish the framework
please refer to this [PR](https://github.com/getsentry/sentry-cocoa/pull/3623).

When coding with Swift be aware of two things:

1. If you want to use swift code in an Objc file: `#import "SentrySwift.h"`
2. If you want to use Objc code from Swift, first add the desired header file to `SentryInternal.h`, then, in your Swift file, `@_implementationOnly import _SentryPrivate` (the underscore makes auto-complete ignore it since we dont want users importing this module).

## Enabling C++/Objective-c++ interoperability for visionOS

Date: October 23, 2024
Contributors: @brustolin, @philipphofmann

To enable visionOS support with the Sentry static framework, you need to set the `SWIFT_OBJC_INTEROP_MODE` build setting to `objcxx`. This setting will only be applied for visionOS, but because much of the codebase is shared across platforms, this change introduces a limitation: we won’t be able to call C functions directly from Swift code.

However, C functions can still be accessed from code that is conditionally compiled using directives, such as `#if os(iOS)`.

## Deserializing Events

Date: January 16, 2025
Contributors: @brustolin, @philipphofmann, @armcknight, @philprime

Decision: Mutual Agreement on Option B

Comments:

1. @philprime: I would prefer to manually (because automatically is not possible without external tools) write extensions of existing Objective-C classes to conform to Decodable, then use the JSONDecoder. If the variables of the classes/structs do not match the JSON spec (i.e. ipAddress in Swift, but ip_address serialized), we might have to implement custom CodingKeys anyways.
2. @brustolin: I agree with @philprime , manually writing the Decodable extensions for ObjC classes seems to be the best approach right now.
3. @armcknight: I think the best bet to get the actual work done that is needed is to go with option B, vs all the refactors that would be needed to use Codable to go with A. Then, protocol APIs could be migrated from ObjC to Swift as-needed and converted to Codable.
4. @philipphofmann: I think Option B/ manually deserializing is the way to go for now. I actually tried it and it seemed a bit wrong. I evaluated the other options and with all your input, I agree with doing it manually. We do it once and then all good. Thanks everyone.

### Background

To report fatal app hangs and measure how long an app hangs lasts ([GH Epic](https://github.com/getsentry/sentry-cocoa/issues/4261)), we need to serialize events to disk, deserialize, modify, and send them to Sentry. As of January 14, 2025, the Cocoa SDK doesn’t support deserializing events. As the fatal app hangs must go through beforeSend, we can’t simply modify the serialized JSON stored on disk. Instead, we must deserialize the event JSON and initialize a SentryEvent so that it can go through beforeSend.

As of January 14, 2025, all the serialization is custom-made with the [SentrySerializable](https://github.com/getsentry/sentry-cocoa/blob/main/Sources/Sentry/Public/SentrySerializable.h) protocol:

```objectivec
@protocol SentrySerializable <NSObject>

- (NSDictionary<NSString *, id> *)serialize;

@end
```

The SDK manually creates a JSON-like dict:

```objectivec
- (NSDictionary<NSString *, id> *)serialize
{
    return @{ @"city" : self.city, @"country_code" : self.countryCode, @"region" : self.region };
}
```

And then the [SentryEnvelope](https://github.com/getsentry/sentry-cocoa/blob/72e34fae44b817d8c12490bbc5c1ce7540f86762/Sources/Sentry/SentryEnvelope.m#L70-L90) calls serialize on the event and then converts it to JSON data.

```objectivec
NSData *json = [SentrySerialization dataWithJSONObject:[event serialize]];
```

To implement a deserialized method, we would need to manually implement the counterparts, which is plenty of code. As ObjC is slowly dying out and the future is Swift, we would like to avoid writing plenty of ObjC code that we will convert to Swift in the future.

### Option A: Use Swifts Built In Codable and convert Serializable Classes to Swift

As Swift has a built-in [Decoding and Encoding](https://developer.apple.com/documentation/foundation/archives_and_serialization/encoding_and_decoding_custom_types) mechanisms it makes sense to explore this option.

Serializing a struct in Swift to JSON is not much code:

```objectivec
struct Language: Codable {
    var name: String
    var version: Int
}

let swift = Language(name: "Swift", version: 6)

let encoder = JSONEncoder()
if let encoded = try? encoder.encode(swift) {
    // save `encoded` somewhere
}
```

The advantage is that we don’t have to manually create the dictionaries in serialize and a potential deserialize method. The problem is that this only works with Swift structs and classes. We can’t use Swift structs, as they’re not working in ObjC. So, we need to convert the classes to serialize and deserialize to Swift.

The major challenge is that doing this without breaking changes for both Swift and ObjC is extremely hard to achieve. One major problem is that some existing classes such as SentryUser overwrite the `- (NSUInteger)hash` method, which is `var hash: [Int](https://developer.apple.com/documentation/swift/int) { get }` in Swift. When converting SentryUser to Swift, calling `user.hash()` converts to `user.hash`. While most of our users don’t call this method, it still is a breaking change. And that’s only one issue we found when converting classes to Swift.

To do this conversion safely, we should do it in a major release. We need to convert all public protocol classes to Swift. Maybe it even makes sense to convert all public classes to Swift to avoid issues with our package managers that get confused when there is a mix of public classes of Swift and ObjC. SPM, for example, doesn’t allow this, and we need to precompile our SDK to be compatible.

The [SentryEnvelope](https://github.com/getsentry/sentry-cocoa/blob/72e34fae44b817d8c12490bbc5c1ce7540f86762/Sources/Sentry/SentryEnvelope.m#L70-L90) first creates a JSON dict and then converts it to JSON data. Instead, we could directly use the Swift JSONEncoder to save one step in between. This would convert the classes to JSON data directly.

```objectivec
NSData *json = [SentrySerialization dataWithJSONObject:[event serialize]];
```

All that said, I suggest converting all public protocol classes to Swift and switching to Swift Codable for serialization, cause it will be less code and more future-proof. Of course, we will run into problems and challenges on the way, but it’s worth doing it.

#### Pros

1. Less code.
2. More Swift code is more future-proof.

#### Cons

- Major release
- Risk of adding bugs

### Option B: Add Deserialize in Swift

We could implement all deserializing code in Swift without requiring a major version. The implementation would be the counterpart of ObjC serialize implementations, but written in Swift.

#### Pros

1. No major
2. Low risk of introducing bugs
3. Full control of serializing and deserializing

#### Cons

1. Potentially slightly higher maintenance effort, which is negligible as we hardly change the protocol classes.

_Sample for implementation of Codable:_

```swift
@_implementationOnly import _SentryPrivate
import Foundation

// User is the Swift name of SentryUser
extension User: Codable {
    private enum CodingKeys: String, CodingKey {
        case id
        case email
        case username
        case ipAddress
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userId, forKey: .id)
        try container.encode(email, forKey: .email)
        try container.encode(username, forKey: .username)
        try container.encode(ipAddress, forKey: .ipAddress)
    }

    public required convenience init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(userId: try container.decode(String.self, forKey: .id))
        email = try container.decode(String.self, forKey: .email)
        username = try container.decode(String.self, forKey: .username)
        ipAddress = try container.decode(String.self, forKey: .ipAddress)
    }
}
```

### Option C: Duplicate protocol classes and use Swift Codable

We do option A, but we keep the public ObjC classes, duplicate them in Swift, and use the internal Swift classes only for serializing and deserializing. Once we have a major release, we replace the ObjC classes with the internal Swift classes.

We can also start with this option to evaluate Swift Codable and switch to option A once we’re confident it’s working correctly.

#### Pros

1. No major.
2. We can refactor it step by step.
3. The risk of introducing bugs can be distributed across multiple releases.

#### Cons

1. Duplicate code.

## Platform version support

Date: March 11, 2025
Contributors: @armcknight, @philipphofmann, @kahest

We will support versions of each platform going back 4 major versions, but we support no version which is not debuggable by the current Xcode required to submit apps to stores. There are 3 considerations:

1. The distribution of events we receive from the various versions of iOS etc in the wild.
1. Xcode support. As of the time of this writing, the oldest version of Xcode that can still submit apps to the app store is Xcode 15, which supports back to iOS 12, while the current is iOS 18.
1. GitHub Actions support. This dictates which versions we can automatically test. Their oldest [macOS runner image](https://github.com/actions/runner-images/tree/main/images/macos) is `macos-13` with support going back to iOS 16.1

Our major-4 standard would place us right in the middle of the earliest Xcode and GitHub Actions supported versions, which seems like a reasonable standard.

Those versions that cannot be automatically tested with GitHub Actions shall be declared as "best effort" support.

See previous discussion at https://github.com/getsentry/sentry-cocoa/issues/3846.

## Use preinstalled GH actions simulators

Creating simulators in GH actions can take up to five minutes or more. Instead, we use the preinstalled simulators for unit and UI tests to speed up CI. We also noticed that tests are more likely to flake due to being unable to launch the app for UI tests and such. We don't have hard evidence to prove this, and these problems could vanish if GH action runners improve. It makes sense to work with what's preinstalled instead and not messing around with the CI environment. If we need to test on a specific OS version, we should use a GH action image with an Xcode version tied to that specific OS version.

## Do not use Swift String constants in ObjC code

Date: April 11, 2025
Contributors: @philipphofmann, @philprime, @kahest

Due to a potential memory-management bug in the Swift standard library for bridging `String` to Objective-C, we experienced SDK crashes when accessing Swift String constants from an Objective-C `NSBlock` closure.

To avoid this issue, we should not use Swift String constants in Objective-C code and instead define them as Objective-C constants.

Related links:

- https://github.com/getsentry/sentry-cocoa/issues/4887
- https://github.com/getsentry/sentry-cocoa/pull/4910

## Decodable conformances to ObjC types

A few types that are defined in ObjC have Decodable conformances in "Sources/Swift/Protocol/Codable/". This works for xcodebuild where ObjC and Swift are in the same target
but not for SPM where ObjC and Swift have to be in different targets. This is because Swift does not support adding a protocol conformance to a type in a different module
than the one the type/protocol is defined in. To work around this Swift code subclasses the ObjC type and adds the conformance to the subclass. It is then decoded as a
subclass and cast back to the superclass. This is only done for SPM, not xcodebuild, because the Codable conformance is part of the public API and therefore requires a
major version bump to change.

Future types conforming to Decodable can be written in Swift from the start and therefore have the conformance added directly to the type.

## v9

Work on the v9 SDK is being done behind the compiler flag `SDK_V9`. CI builds the SDK with this flag enabled to ensure it does not break during the course of non-v9 development. This SDK version will focus on quality and be a part of Sentry’s quality quarter initiative. Notably, the minimum supported OS version will be bumped in this release. The changelog for this release is being tracked in [CHANGELOG-v9.md](../CHANGELOG-v9.md).
