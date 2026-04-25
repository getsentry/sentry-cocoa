#import <Foundation/Foundation.h>

@class SentryId;
@class SentryTraceContext;

NS_ASSUME_NONNULL_BEGIN

// See SentryFeedback.h for an explanation of why SentryObjC's public headers alias
// the plain class name to the Swift-mangled class exported by Sentry.framework.
#if SWIFT_PACKAGE
@class _TtC11SentrySwift20SentryEnvelopeHeader;
@compatibility_alias SentryEnvelopeHeader _TtC11SentrySwift20SentryEnvelopeHeader;
#else
@class _TtC6Sentry20SentryEnvelopeHeader;
@compatibility_alias SentryEnvelopeHeader _TtC6Sentry20SentryEnvelopeHeader;
#endif

/**
 * Header of a Sentry envelope.
 */
@interface SentryEnvelopeHeader : NSObject

@property (nonatomic, readonly, strong, nullable) SentryId *eventId;
@property (nonatomic, strong, nullable) NSDate *sentAt;

- (instancetype)initWithId:(nullable SentryId *)eventId
              traceContext:(nullable SentryTraceContext *)traceContext;

@end

NS_ASSUME_NONNULL_END
