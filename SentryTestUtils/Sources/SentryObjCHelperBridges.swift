#if SWIFT_PACKAGE
@_spi(Private) import SentrySwift
#else
@_spi(Private) import Sentry
#endif
// Swift tests get both Swift and Objective-C helpers through SentryTestUtils.
@_exported import SentryTestUtilsObjC

// Clang modules cannot declare conformance to a Swift-owned protocol. SwiftPM knows both
// types belong to this package; Xcode treats them as foreign modules.
#if SWIFT_PACKAGE
@_spi(Private) extension SentryTestObjCRuntimeWrapper: SentryObjCRuntimeWrapper {}
#else
@_spi(Private) extension SentryTestObjCRuntimeWrapper: @retroactive SentryObjCRuntimeWrapper {}
#endif

#if !SDK_V10
extension SentryCrashScopeHelper {
    @_spi(Private) public static func getScopeObserver(withMaxBreacdrumb maxBreadcrumbs: Int) -> SentryScopeObserver {
        // The helper returns NSObject. SentryCrashScopeObserver adopts SentryScopeObserver in its
        // implementation file, which this Swift file cannot name without an import cycle.
        unsafeBitCast(makeScopeObserver(maxBreadcrumbs: maxBreadcrumbs), to: SentryScopeObserver.self)
    }
}
#endif
