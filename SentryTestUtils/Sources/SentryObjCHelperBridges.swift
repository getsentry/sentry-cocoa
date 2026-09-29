#if SWIFT_PACKAGE
@_spi(Private) import SentrySwift
import SentryTestUtilsObjC

// Clang modules imported by Swift cannot declare conformance to a Swift-owned protocol.
@_spi(Private) extension SentryTestObjCRuntimeWrapper: SentryObjCRuntimeWrapper {}

#if !SDK_V10
extension SentryCrashScopeHelper {
    @_spi(Private) public static func getScopeObserver(withMaxBreacdrumb maxBreadcrumbs: Int) -> SentryScopeObserver {
        // Preserve the original ObjC helper's id<SentryScopeObserver> cast: the legacy
        // observer implements these selectors without formally declaring conformance.
        unsafeBitCast(makeScopeObserver(maxBreadcrumbs: maxBreadcrumbs), to: SentryScopeObserver.self)
    }
}
#endif
#endif
