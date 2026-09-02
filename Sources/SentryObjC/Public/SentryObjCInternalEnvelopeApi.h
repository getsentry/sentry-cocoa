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
/// exception. Applies the same session side effects as
/// @c updateSessionForDroppedEventNonTerminating:, then sends the envelope. The current session
/// keeps running with the same ID and only its error count increases, but it ends with the
/// @c unhandled status instead of @c exited. A later crash or abnormal exit still takes precedence
/// over @c unhandled.
///
/// Do not also call @c updateSessionForDroppedEventNonTerminating: for the same event.
- (void)captureNonTerminating:(SentryObjCEnvelope *)envelope;

/// Updates the current session for a non-terminating error that was dropped by sampling.
///
/// Does not capture an envelope. Hybrid SDKs should call this when an error is dropped by
/// sampling, so the native session still records the error. Do not call this for events dropped
/// by @c beforeSend or ignored exception types, and do not call it in addition to
/// @c captureNonTerminating: for the same event.
///
/// @param unhandled @c YES if the dropped error was unhandled (@c mechanism.handled=false).
- (void)updateSessionForDroppedEventNonTerminating:(BOOL)unhandled;

/// Deserializes an envelope from raw data.
- (nullable SentryObjCEnvelope *)deserializeFrom:(NSData *)data;

@end

NS_ASSUME_NONNULL_END
