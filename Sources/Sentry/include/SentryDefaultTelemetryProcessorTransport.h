#import "SentryDefines.h"

@class SentryTransportAdapter;

NS_ASSUME_NONNULL_BEGIN

/**
 * Default implementation of SentryTelemetryProcessorTransport that sends telemetry envelopes
 * through the transport layer.
 */
@interface SentryDefaultTelemetryProcessorTransport : NSObject
SENTRY_NO_INIT

- (instancetype)initWithTransportAdapter:(SENTRY_SWIFT_MIGRATION_ID(
                                             SentryTransportAdapter))transportAdapter;

@end

NS_ASSUME_NONNULL_END
