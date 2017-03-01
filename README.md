# Sentry client for iOS/macOS/tvOS/watchOS<sup>(1)</sup>.

[![Travis](https://img.shields.io/travis/getsentry/sentry-swift.svg?maxAge=2592000)](https://travis-ci.org/getsentry/sentry-swift)
![platforms](https://img.shields.io/badge/platforms-iOS%20%7C%20tvOS%20%7C%20OSX-333333.svg)
![langauges](https://img.shields.io/badge/languages-Swift%20%7C%20ObjC-333333.svg)
[![CocoaPods Shield](https://img.shields.io/cocoapods/v/Sentry.svg)](https://cocoapods.org/pods/Sentry)
[![CocoaPods Shield](https://img.shields.io/cocoapods/dt/Sentry.svg)](https://cocoapods.org/pods/Sentry)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![codecov](https://codecov.io/gh/getsentry/sentry-swift/branch/master/graph/badge.svg)](https://codecov.io/gh/getsentry/sentry-swift)

Offical client for [Sentry](https://www.sentry.io/).

This client was written in Swift but works with both Swift >= 2.3 *and* Objective-C projects.

```swift
import Sentry

// Create client and start crash handler
SentryClient.shared = SentryClient(dsnString: "your-dsn")
SentryClient.shared?.startCrashHandler()

// Set
SentryClient.shared?.user = User(id: "3",
	email: "example@example.com",
	username: "some_user",
	extra: ["is_admin": false]
)
```

- [Documentation](https://docs.sentry.io/clients/cocoa/)

**Example Projects**

- [iOS Swift 2.3 Project](/Examples/SwiftExample) - Full project
  - [ViewController.swift](/Examples/SwiftExample/SwiftExample/ViewController.swift) - Implementation
- [Objective-C Project](/Examples/ObjCExample) - Full project
  - [ViewController.m](/Examples/ObjCExample/ObjCExample/ViewController.m) - Implementation
- [tvOS Swift 3 Project](/Examples/SwiftTVOSExample) - Full project
  - [ViewController.swift](/Examples/SwiftTVOSExample/SwiftTVOSExample/ViewController.swift) - Implementation
- [macOS Swift 3 Project](/Examples/MacExample) - Full project
  - [ViewController.swift](/Examples/MacExample/MacExample/ViewController.swift) - Implementation
- [watchOS Swift 3 Project](/Examples/SwiftWatchOSExample) - Full project
  - [ViewController.swift](/Examples/SwiftWatchOSExample/SwiftWatchOSExample/ViewController.swift) - Implementation

<sup>(1)</sup>limited symbolication support
