#import "SentryDefines.h"
#import "SentrySwift.h"

@class SentryTransportAdapter;

NS_ASSUME_NONNULL_BEGIN

/**
 * Default implementation of SentryTelemetryProcessorTransport that sends telemetry envelopes
 * through the transport layer.
 */
@interface SentryDefaultTelemetryProcessorTransport : NSObject <SentryTelemetryProcessorTransport>
SENTRY_NO_INIT

- (instancetype)initWithTransportAdapter:(SentryTransportAdapter *)transportAdapter;

@end

NS_ASSUME_NONNULL_END
