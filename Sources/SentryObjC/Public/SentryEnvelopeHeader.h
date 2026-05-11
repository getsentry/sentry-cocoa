#import <Foundation/Foundation.h>

@class SentryId;
@class SentryTraceContext;

NS_ASSUME_NONNULL_BEGIN

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
