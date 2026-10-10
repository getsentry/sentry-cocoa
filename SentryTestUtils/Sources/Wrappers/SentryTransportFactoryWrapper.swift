#if SWIFT_PACKAGE
@_spi(Private) import SentrySwift
#else
@_spi(Private) import Sentry
#endif
import SentryTestUtilsObjC

@_spi(Private)
public enum TestTransportFactory {
    public static var httpTransportClass: AnyClass {
        SentryHttpTransportWrapper.httpTransportClass()
    }

    public static func initTransports(
        _ options: Options,
        dateProvider: SentryCurrentDateProvider,
        sentryFileManager: SentryFileManager,
        rateLimits: RateLimits,
        reachability: SentryReachability
    ) -> [Transport] {
        requireTestBridgeValue(TransportInitializer.initTransports(
            options,
            dateProvider: dateProvider,
            sentryFileManager: sentryFileManager,
            rateLimits: rateLimits,
            reachability: reachability
        ))
    }
}
