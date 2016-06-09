# sentry-swift

[![Travis](https://img.shields.io/travis/getsentry/sentry-swift.svg?maxAge=2592000)](https://travis-ci.org/getsentry/sentry-swift)
![platforms](https://img.shields.io/badge/platforms-iOS%20%7C%20tvOS%20%7C%20OSX-333333.svg)
![langauges](https://img.shields.io/badge/languages-Swift%20%7C%20ObjC-333333.svg)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)

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

## Contents

- [Installation](#installation)
  - [CocoaPods](#cocoapods)
  - [Carthage](#carthage)
- [Usage](#usage)
  - [Configuration](#configuration)
  - [Sending Messages](#sending-messages)
- [dSYM Upload Instructions](#dsym-upload-instructions)
  - [Fastlane Action](#upload-with-fastlane-action) (Recommended)
  - [sentry-cli](https://github.com/getsentry/sentry-cli)
    - [Run Script with sentry-cli](#run-script-with-sentry-cli)
    - [Manually with sentry-cli](#manually-with-sentry-cli)
- Example Projects
  - [Swift Project](/Examples/SwiftExample) - Full project
    - [ViewController.swift](/Examples/SwiftExample/SwiftExample/ViewController.swift) - Implementation
  - [Objective-C Project](/Examples/ObjCExample) - Full project
    - [ViewController.m](/Examples/ObjCExample/ObjCExample/ViewController.m) - Implementation

## Installation

> **Embedded frameworks require a minimum deployment target of iOS 8 or OS X Mavericks (10.9).**

### CocoaPods

[CocoaPods](http://cocoapods.org) is a dependency manager for Cocoa projects. You can install it with the following command:

```bash
$ gem install cocoapods
```

> CocoaPods 0.39.0+ is required to build SentrySwift.

To integrate SentrySwift into your Xcode project using CocoaPods, specify it in your `Podfile`:

```ruby
source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '8.0'
use_frameworks!

pod 'SentrySwift'
```

Then, run the following command:

```bash
$ pod install
```

### Carthage

[Carthage](https://github.com/Carthage/Carthage) is a decentralized dependency manager that builds your dependencies and provides you with binary frameworks.

You can install Carthage with [Homebrew](http://brew.sh/) using the following command:

```bash
$ brew update
$ brew install carthage
```

To integrate SentrySwift into your Xcode project using Carthage, specify it in your `Cartfile`:

```ogdl
github "getsentry/sentry-swift"
```

Run `carthage update` to build the framework and drag the built `SentrySwift.framework` and `KSCrash.framework` into your Xcode project.

## Usage

### Configuration

```swift
func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {

	// Create a Sentry client and start crash handler
	SentryClient.shared = SentryClient(dsnString: "https://username:password@app.getsentry.com/12345")	
	SentryClient.shared?.startCrashHandler()
	
	return true
}
```

If you do not want to send events in a debug build, you can wrap the above code in something like...

```swift
// Create a Sentry client and start crash handler when not in debug
if !DEBUG {
	SentryClient.shared = SentryClient(dsnString: "https://username:password@app.getsentry.com/12345")	
	SentryClient.shared?.startCrashHandler()
}
```

#### Client information

A user, tags, and extra information can be stored on a `SentryClient`. This information will get sent with every message/exception in which that `SentryClient` sends up the Sentry. They can be used like...

```swift
SentryClient.shared?.user = User(id: "3",
	email: "example@example.com",
	username: "Example",
	extra: ["is_admin": false]
)

SentryClient.shared?.tags = [
	"environment": "production"
]

SentryClient.shared?.extra = [
	"a_thing": 3,
	"some_things": ["green", "red"],
	"foobar": ["foo": "bar"]
]
```

All of the above (`user`, `tags`, and `extra`) can all be set at anytime and can also be set to nil to clear.

### Sending Messages

Sending a basic message (no stacktrace) can be done with `captureMessage`.

```swift
SentryClient.shared?.captureMessage("Hehehe, this is totes not useful", level: .Debug)
```

If more detailed information is required, `Event` has a large constructor that allows for passing in of all the information or a `build` function can be called to build the `Event` object like below.

```swift
let event = Event.build("Another example") {
	$0.level = .Debug
	$0.tags = ["status": "test"]
	$0.extra = [
		"name": "Donatello",
		"favorite_power_ranger": "green/white"
	]
}
SentryClient.shared?.captureEvent(event)
```

## dSYM Upload Instructions

A dSYM upload is required for Sentry to symoblicate your crash logs for viewing. The symoblication process unscrambles Apple's crash logs to reveal the function, variables, file names, and line numbers of the crash. The dSYM file can be uploaded through the [sentry-cli](https://github.com/getsentry/sentry-cli) tool or through a [Fastlane](https://fastlane.tools/)) action.

### With Bitcode
If [Bitcode](https://developer.apple.com/library/ios/documentation/IDEs/Conceptual/AppDistributionGuide/AppThinning/AppThinning.html#//apple_ref/doc/uid/TP40012582-CH35-SW2) **is enabled** in your project, you will have to upload the dSYM to Sentry **after** it has finished processing in the iTunesConnect. The dSYM can be downloaded in three ways...

#### Use Fastlane

Use the [Fastlane's](https://github.com/fastlane/fastlane) action, `download_dsyms`, to download the dSYMs from iTunesConnect and upload to Sentry. The dSYM won't be generated unitl **after** the app is done processing on iTunesConnect so this should be run in its own lane.

```ruby
lane :upload_symbols do
  download_dsyms
  upload_symbols_to_sentry(
    api_key: '...',
    org_slug: '...',
    project_slug: '...',
  )
end
```

#### Use 'sentry-cli`
There are two ways to download the dSYM from iTunesConnect. After you do one of the two following ways, you can upload the dSYM using [sentry-cli](https://github.com/getsentry/sentry-cli/releases)

1. Open Xcode Oraganizer, go to your app, and click "Download dSYMs..."
2. Login to iTunes Connect, go to your app, go to "Activity, click the build number to go into the detail page, and click "Download dSYM"

```
sentry-cli --api-key YOUR_API_KEY upload-dsym --org YOUR_ORG_SLUG --project YOUR_PROJECT_SLUG PATH_TO_DSYM"
```

### Without Bitcode

#### Use Fastlane

```ruby
lane :build do
  gym
  upload_symbols_to_sentry(
    api_key: '...',
    org_slug: '...',
    project_slug: '...',
  )
end
```

#### Run Script with `sentry-cli`
Your project's dSYM can be upload during the build phase as a "Run Script". By default, an Xcode project will only have `DEBUG_INFORMATION_FORMAT` set to `DWARF with dSYM File` in `Release` so make sure everything is set in your build settings properly.

1. You will need to copy the below into a new `Run Script` and set your `API_KEY`, `ORG_SLUG`, and `PROJECT_SLUG`
2. Download and install [sentry-cli](https://github.com/getsentry/sentry-cli/releases)
  - The best place to put this is in the `/usr/local/bin/` directory

Shell: `/usr/bin/ruby`

```rb
API_KEY = "your-api-key"
ORG_SLUG = "your-org-slug"
PROJECT_SLUG = "your-project-slug"

Dir["#{ENV["DWARF_DSYM_FOLDER_PATH"]}/*.dSYM"].each do |dsym|
cmd = "sentry-cli --api-key #{API_KEY} upload-dsym --org #{ORG_SLUG} --project #{PROJECT_SLUG} #{dsym}"
Process.detach(fork {system cmd })
end
```

#### Manually with `sentry-cli`

Your dSYM file can be upload manually by you (or some automated process) with the `sentry-cli` tool. You will need to know the following information:

- API Key
- Organization slug
- Project slug
- Path to the build's dSYM

1. Download and install [sentry-cli](https://github.com/getsentry/sentry-cli/releases)
  - The best place to put this is in the `/usr/local/bin/` directory

```
sentry-cli --api-key YOUR_API_KEY upload-dsym --org YOUR_ORG_SLUG --project YOUR_PROJECT_SLUG PATH_TO_DSYM"
```
