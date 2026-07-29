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

/// Captures an envelope whose unhandled exceptions did not terminate the process.
///
/// Use this instead of @c capture: in runtimes that keep the process alive after an unhandled
/// exception. The current session keeps running with the same ID and only its error count
/// increases, but it ends with the @c unhandled status instead of @c exited. A later crash or
/// abnormal exit still takes precedence over @c unhandled.
- (void)captureNonTerminating:(SentryObjCEnvelope *)envelope;

/// Deserializes an envelope from raw data.
- (nullable SentryObjCEnvelope *)deserializeFrom:(NSData *)data;

@end

NS_ASSUME_NONNULL_END
