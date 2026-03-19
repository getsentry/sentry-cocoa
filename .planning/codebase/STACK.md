# Technology Stack

**Analysis Date:** 2026-03-19

## Languages

**Primary:**

- Swift 5.5+ - Main SDK implementation, integrations, networking, persistence
- Objective-C - Core SDK interfaces, file manager, session management, crash reporting
- C/C++ - Profiling, crash handling (SentryCrash fork), backtrace support

**Secondary:**

- Ruby 3.4.7 - Build tooling (Gemfile), Fastlane automation, cocoapods management

## Runtime

**Environment:**

- Apple platforms: iOS 15+, macOS 10.14+, tvOS 15+, watchOS 8+, visionOS 1+
- Xcode build system (via `.xcodebuild` scripts)
- Swift Package Manager 6.0+

**Package Manager:**

- Swift Package Manager (SPM) 6.0 - Primary distribution (Package.swift, Package@swift-6.1.swift)
- CocoaPods 1.9.1+ - Legacy support (deprecated, read-only after June 2026)
- Lockfile: CocoaPods (Gemfile.lock present)

## Frameworks

**Core:**

- Foundation - Base framework for all platforms
- UIKit - iOS/tvOS UI integration
- AppKit - macOS UI integration
- WatchKit - watchOS integration
- SwiftUI - SwiftUI-specific layer at `Sources/SentrySwiftUI`

**Testing:**

- XCTest - Native Apple test framework
- Xcode test infrastructure (via Make targets)

**Build/Dev:**

- Xcode (build system, project management)
- Fastlane - Mobile app automation (in Gemfile)
- Slather - Code coverage tool (in Gemfile)
- xcbeautify - Build output formatting
- pre-commit - Git hooks for validation (`.pre-commit-config.yaml`)
- dprint - Dart/code formatting

## Key Dependencies

**Critical:**

- No external runtime dependencies - SDK is self-contained
- SentryCrash (fork) - C/C++ crash reporting library at `Sources/SentryCrash/`
- SentryCppHelper - C++ support library for sampling profiler and backtrace handling

**Infrastructure:**

- libc++ - C++ standard library (linked via Package.swift)
- CoreData - Optional performance tracing integration (enable via `enableCoreDataTracing`)
- MetricKit - Optional crash metrics (imported conditionally for macOS/iOS)

## Configuration

**Environment:**

- SENTRY_DSN - Environment variable support (checked at `Sources/Swift/Options.swift:8`)
- `.env` file present - Contains build configuration (not secrets per CLAUDE.md)
- Configuration flags: `SENTRY_NO_UI_FRAMEWORK`, `SENTRY_TARGET_PROFILING_SUPPORTED`

**Build:**

- Package.swift - SwiftPM configuration, defines 7 library targets
- Sentry.podspec - CocoaPods specification (version 9.8.0)
- .swiftlint.yml - Swift linting rules and style enforcement
- .clang-format - C/ObjC formatting rules (WebKit style, 4-space indent, 100 col limit)
- dprint.json - Formatting configuration
- Makefile - 40+ build and test targets for all platforms

## Platform Requirements

**Development:**

- Xcode 13+ (implicit from iOS 15+ minimum)
- Ruby 3.4.7 (via .ruby-version)
- Homebrew for tooling (pre-commit, dprint, xcbeautify)
- Python 3 (for pre-commit hooks)

**Production:**

- iOS: 15.0+
- macOS: 10.14+
- tvOS: 15.0+
- watchOS: 8.0+
- visionOS: 1.0+

## Compiler Settings

**C/C++:**

- C++ standard: C++14 (CLANG_CXX_LANGUAGE_STANDARD)
- C++ library: libc++ (CLANG_CXX_LIBRARY)
- C++ exceptions: Enabled (GCC_ENABLE_CPP_EXCEPTIONS)
- Language mode: Swift 5 (swiftLanguageModes)

**ObjC:**

- Automatic Reference Counting (ARC) required
- Module system enabled (APPLICATION_EXTENSION_API_ONLY = NO)
- Header search paths configured for SentryCrash, profiling, and tools

---

_Stack analysis: 2026-03-19_
