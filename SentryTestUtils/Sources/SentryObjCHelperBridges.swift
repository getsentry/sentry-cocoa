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
        // Preserve the original ObjC helper's id<SentryScopeObserver> cast: the legacy
        // observer implements these selectors without formally declaring conformance.
        unsafeBitCast(makeScopeObserver(maxBreadcrumbs: maxBreadcrumbs), to: SentryScopeObserver.self)
    }
}
#endif
