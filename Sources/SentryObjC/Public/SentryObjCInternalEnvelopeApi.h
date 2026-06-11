#import <Foundation/Foundation.h>

@class SentryObjCEnvelope;

NS_ASSUME_NONNULL_BEGIN

/// Envelope APIs for Sentry hybrid SDKs.
///
/// These methods may change in any minor release without deprecation.
@interface SentryObjCInternalEnvelopeApi : NSObject

/// Stores an envelope synchronously to disk.
- (void)store:(SentryObjCEnvelope *)envelope;

/// Captures an envelope, sending it to Sentry.
- (void)capture:(SentryObjCEnvelope *)envelope;

/// Deserializes an envelope from raw data.
/// @return The deserialized envelope, or @c nil if the data is invalid.
- (nullable SentryObjCEnvelope *)deserializeFrom:(NSData *)data;

@end

NS_ASSUME_NONNULL_END
