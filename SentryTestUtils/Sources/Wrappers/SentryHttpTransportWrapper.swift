#if SWIFT_PACKAGE && !SDK_V10
@_spi(Private) import SentrySwift
#else
@_spi(Private) import Sentry
#endif
import SentryTestUtilsObjC

extension SentryHttpTransportWrapper {
    @_spi(Private) @nonobjc
    public static func make(
        dsn: SentryDsn,
        sendClientReports: Bool,
        cachedEnvelopeSendDelay: TimeInterval,
        dateProvider: SentryCurrentDateProvider,
        fileManager: SentryFileManager,
        requestManager: RequestManager,
        requestBuilder: SentryNSURLRequestBuilder,
        rateLimits: RateLimits,
        envelopeRateLimit: EnvelopeRateLimit,
        dispatchQueueWrapper: SentryDispatchQueueWrapper,
        reachability: SentryReachability
    ) -> Transport {
        requireTestBridgeValue(makeHttpTransport(
            withDsn: dsn,
            sendClientReports: sendClientReports,
            cachedEnvelopeSendDelay: cachedEnvelopeSendDelay,
            dateProvider: dateProvider,
            fileManager: fileManager,
            requestManager: requestManager,
            requestBuilder: requestBuilder,
            rateLimits: rateLimits,
            envelopeRateLimit: envelopeRateLimit,
            dispatchQueueWrapper: dispatchQueueWrapper,
            reachability: reachability
        ))
    }
}
