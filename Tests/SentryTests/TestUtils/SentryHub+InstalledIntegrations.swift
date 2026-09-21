#if SWIFT_PACKAGE
@_spi(Private) import SentrySwift
import SentryTestsObjCHelpers
#else
@_spi(Private) import Sentry
#endif

func testInstalledIntegrations(_ hub: SentryHubInternal) -> [Any] {
    #if SWIFT_PACKAGE
    return SentryTestInstalledIntegrations(hub)
    #else
    return hub.installedIntegrations()
    #endif
}
