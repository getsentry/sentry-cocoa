#import <Sentry/Sentry.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentrySDK (Tests)

+ (void)setCurrentHub:(SentryHub *)hub;

+ (void)captureEnvelope:(SentryEnvelope *)envelope;

+ (void)storeEnvelope:(SentryEnvelope *)envelope;

@end

NS_ASSUME_NONNULL_END
