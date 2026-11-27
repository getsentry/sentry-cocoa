@_spi(Private) import Sentry
import SentryTestUtilsObjC

extension TransportInitializer {
    @_spi(Private) @nonobjc public static func initTransports(
        _ options: Options,
        dateProvider: SentryCurrentDateProvider,
        sentryFileManager: SentryFileManager,
        rateLimits: RateLimits,
        reachability: SentryReachability
    ) -> [Transport] {
        requireTestBridgeValue(initTransports(
            options as Any,
            dateProvider: dateProvider,
            sentryFileManager: sentryFileManager,
            rateLimits: rateLimits,
            reachability: reachability
        ))
    }
}
