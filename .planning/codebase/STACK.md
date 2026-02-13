# Technology Stack

**Analysis Date:** 2026-02-13

## Languages

**Primary:**

- Objective-C - Core SDK implementation for crash handling and runtime integration
- Swift - Modern API surface, integrations, and utilities
- C/C++ - Low-level crash handling via SentryCrash (C++14 standard)

**Secondary:**

- Ruby - Development tooling and build automation via Fastlane
- Python - Code analysis and formatting tools
- Shell/Bash - Build scripts and CI automation

## Runtime

**Environment:**

- Apple platforms (iOS, macOS, tvOS, watchOS, visionOS)
- No external runtime dependency; uses native Apple frameworks

**Package Manager:**

- CocoaPods - Primary distribution mechanism
- Swift Package Manager (SPM) - Alternative distribution with XCFramework binaries
- Homebrew - Development tool management

**Lockfile:**

- `Gemfile.lock` (Ruby) - Development dependencies
- No package-lock.json equivalent (CocoaPods and SPM use built-in versioning)

## Frameworks

**Core (Apple System Frameworks):**

- Foundation - Required framework for all SDK operations
- CoreCrash - Implicit via SentryCrash for crash reporting
- WatchKit - Conditionally linked on watchOS platform only

**Testing:**

- XCTest - Native iOS/macOS testing framework
- XCTVapor - Vapor web framework testing (test server only)

**Build/Dev:**

- xcodegen - Generates Xcode projects from YAML specifications
- xcbeautify - Formats Xcode build output
- SwiftLint - Swift code linting and formatting
- Clang-Format - Objective-C/C/C++ formatting
- dprint - Multi-language formatter (Markdown, JSON, YAML)
- Fastlane - Build automation and deployment (Ruby-based)
- pre-commit - Git hook framework for code quality checks

## Key Dependencies

**Critical:**

- SentryCrash (embedded) - Crash capturing and reporting system
- Vapor 4.65.2+ - Test server web framework (development only)
- cocoapods >= 1.9.1 - Dependency manager
- fastlane - Build automation framework

**Infrastructure:**

- bundler >= 2 - Ruby dependency management
- slather - Code coverage reporting
- rest-client - Ruby HTTP client for build scripts

## Configuration

**Environment:**

- DSN configuration via `SENTRY_DSN` environment variable (on macOS only in Options.swift:8)
- SDK initialized with `Options` class (`Sources/Swift/Options.swift`)
- Multiple deployment target versions per platform (iOS 15.0+, macOS 12+, tvOS 15.0+, watchOS 8.0+, visionOS 1.0+)

**Build:**

- `Sentry.podspec` - CocoaPods specification (v9.4.1)
- `Package.swift` - Swift Package Manager manifest with XCFramework binaries
- `SentrySwiftUI.podspec` - SwiftUI subspec
- `.swiftlint.yml` - SwiftLint configuration at `Sources/Sentry/include/module.modulemap`
- `Makefile` - Comprehensive build automation (706 lines, extensive platform support)
- `.clang-format` - C/Objective-C formatting rules
- `dprint.json` - Multi-language formatter configuration
- Xcode project generation via `xcodegen` YAML specs in `Samples/` directories

## Platform Requirements

**Development:**

- macOS 10.15+ (for test server)
- Xcode with support for iOS 15.0+ deployment targets
- Swift 5.5+ compiler
- C++14 support for SentryCrash compilation
- Python 3 for analysis scripts
- Ruby 3.x (via rbenv, specified in `.ruby-version`)
- Pre-commit hooks via `pre-commit` framework
- Homebrew for tool installation

**Production:**

- iOS 15.0+ (minimum deployment target)
- macOS 10.14+ for SPM, 12+ for CocoaPods
- tvOS 15.0+
- watchOS 8.0+
- visionOS 1.0+
- Requires valid Sentry DSN for operation

**Additional Platforms Supported:**

- Mac Catalyst (macOS compatibility layer)
- All variant architectures: standard and ARM64e
- Dynamic and static framework variants available

---

_Stack analysis: 2026-02-13_
