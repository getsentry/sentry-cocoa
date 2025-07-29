#import "SentryDataCategory.h"
#import "SentryDiscardReason.h"

@class SentryEnvelope;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SentryFlushResult) {
    kSentryFlushResultSuccess = 0,
    kSentryFlushResultTimedOut,
    kSentryFlushResultAlreadyFlushing,
};

NS_SWIFT_NAME(Transport)
@protocol SentryTransport <NSObject>

- (void)sendEnvelope:(SentryEnvelope *)envelope NS_SWIFT_NAME(send(envelope:));

- (void)storeEnvelope:(SentryEnvelope *)envelope;

- (void)recordLostEvent:(SentryDataCategory)category reason:(SentryDiscardReason)reason;

- (void)recordLostEvent:(SentryDataCategory)category
                 reason:(SentryDiscardReason)reason
               quantity:(NSUInteger)quantity;

- (SentryFlushResult)flush:(NSTimeInterval)timeout;

@end

NS_ASSUME_NONNULL_END
