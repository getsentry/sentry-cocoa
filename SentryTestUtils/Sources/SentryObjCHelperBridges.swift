// Swift tests get both Swift and Objective-C helpers through SentryTestUtils.
@_exported import SentryTestUtilsObjC
@_spi(Private) import Sentry

// Clang modules cannot declare conformance to a Swift-owned protocol. SwiftPM knows both
// types belong to this package; Xcode treats them as foreign modules.
#if SWIFT_PACKAGE
@_spi(Private) extension SentryTestObjCRuntimeWrapper: SentryObjCRuntimeWrapper {}
#else
@_spi(Private) extension SentryTestObjCRuntimeWrapper: @retroactive SentryObjCRuntimeWrapper {}
#endif
