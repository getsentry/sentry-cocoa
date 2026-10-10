#if SWIFT_PACKAGE
@_spi(Private) import SentrySwift
#else
@_spi(Private) import Sentry
#endif
import SentryTestUtilsObjC

@_spi(Private)
public func makeTestHttpTransport(
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
    requireTestBridgeValue(SentryHttpTransportWrapper.makeHttpTransport(
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
