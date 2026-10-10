#if SWIFT_PACKAGE
@_spi(Private) import SentrySwift
#else
@_spi(Private) import Sentry
#endif
import SentryTestUtilsObjC

#if !SDK_V10
extension SentryCrashScopeHelper {
    @_spi(Private) public static func getScopeObserver(withMaxBreacdrumb maxBreadcrumbs: Int) -> SentryScopeObserver {
        // Preserve the original ObjC helper's id<SentryScopeObserver> cast: the legacy
        // observer implements these selectors without formally declaring conformance.
        unsafeBitCast(makeScopeObserver(maxBreadcrumbs: maxBreadcrumbs), to: SentryScopeObserver.self)
    }
}
#endif
