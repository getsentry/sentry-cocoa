# Sentry client for iOS/macOS/tvOS/watchOS<sup>(1)</sup>.

[![Travis](https://img.shields.io/travis/getsentry/sentry-swift.svg?maxAge=2592000)](https://travis-ci.org/getsentry/sentry-swift)
![platforms](https://img.shields.io/badge/platforms-iOS%20%7C%20tvOS%20%7C%20OSX-333333.svg)
![langauges](https://img.shields.io/badge/languages-Swift%20%7C%20ObjC-333333.svg)
[![CocoaPods Shield](https://img.shields.io/cocoapods/v/Sentry.svg)](https://cocoapods.org/pods/Sentry)
[![CocoaPods Shield](https://img.shields.io/cocoapods/dt/Sentry.svg)](https://cocoapods.org/pods/Sentry)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![codecov](https://codecov.io/gh/getsentry/sentry-swift/branch/master/graph/badge.svg)](https://codecov.io/gh/getsentry/sentry-swift)

Offical client for [Sentry](https://www.sentry.io/).

This client is written in Objective-C but also works for Swift projects.

```swift
import Sentry

func application(application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {

    // Create a Sentry client and start crash handler
    do {
        Client.shared = try Client(dsn: "___DSN___")
        try Client.shared?.startCrashHandler()
    } catch let error {
        print("\(error)")
        // Wrong DSN or KSCrash not installed
    }

    return true
}
```

- [Documentation](https://docs.sentry.io/clients/cocoa/)

<sup>(1)</sup>limited symbolication support
