#import <Foundation/Foundation.h>
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCDefines.h"
#else
#    import <SentryObjC/SentryObjCDefines.h>
#endif

@class SentryObjCEnvelope;

NS_ASSUME_NONNULL_BEGIN

/// Envelope APIs for Sentry hybrid SDKs.
///
/// These methods may change in any minor release without deprecation.
@interface SentryObjCInternalEnvelopeApi : NSObject
SENTRY_NO_INIT

/// Synchronously stores an envelope to disk.
- (void)store:(SentryObjCEnvelope *)envelope;

/// Captures an envelope and sends it to Sentry.
- (void)capture:(SentryObjCEnvelope *)envelope;

/// Deserializes an envelope from raw data.
- (nullable SentryObjCEnvelope *)deserializeFrom:(NSData *)data;

@end

NS_ASSUME_NONNULL_END
