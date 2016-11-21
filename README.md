# sentry-swift

[![Travis](https://img.shields.io/travis/getsentry/sentry-swift.svg?maxAge=2592000)](https://travis-ci.org/getsentry/sentry-swift)
![platforms](https://img.shields.io/badge/platforms-iOS%20%7C%20tvOS%20%7C%20OSX-333333.svg)
![langauges](https://img.shields.io/badge/languages-Swift%20%7C%20ObjC-333333.svg)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![codecov](https://codecov.io/gh/getsentry/sentry-swift/branch/master/graph/badge.svg)](https://codecov.io/gh/getsentry/sentry-swift)

Swift client for [Sentry](https://www.getsentry.com/welcome/). This client was writen in Swift but works with both Swift *and* Objective-C projects.

```swift
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
- Example Projects
  - [Swift Project](/Examples/SwiftExample) - Full project
    - [ViewController.swift](/Examples/SwiftExample/SwiftExample/ViewController.swift) - Implementation
  - [Objective-C Project](/Examples/ObjCExample) - Full project
    - [ViewController.m](/Examples/ObjCExample/ObjCExample/ViewController.m) - Implementation
