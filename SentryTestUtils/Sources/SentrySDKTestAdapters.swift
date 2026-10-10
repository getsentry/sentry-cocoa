#if SWIFT_PACKAGE
@_spi(Private) import SentrySwift
#else
@_spi(Private) import Sentry
#endif
import SentryTestUtilsObjC

// Keep the SDK's names and nonthrowing signatures. Explicitly erased arguments select the
// original ObjC methods rather than recursively calling these typed overloads.
extension EnvelopeRateLimit {
    @_spi(Private) public func removeRateLimitedItems(_ envelope: SentryEnvelope) -> SentryEnvelope {
        requireTestBridgeValue(removeRateLimitedItems(envelope as Any))
    }
}

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
    requireTestBridgeValue(SentryTestSDKBridge.makeHttpTransport(
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

@_spi(Private)
public enum TestTransportFactory {
    public static var httpTransportClass: AnyClass {
        SentryTestSDKBridge.httpTransportClass()
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
