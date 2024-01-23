#import "SentryDefines.h"
#import "SentrySDK.h"

@class SentryEnvelope;
@class SentryHub;

NS_ASSUME_NONNULL_BEGIN

SENTRY_EXTERN BOOL shouldProfileNextLaunch(SentryOptions *options);

@interface
SentrySDK ()

+ (void)setCurrentHub:(nullable SentryHub *)hub;

+ (void)captureEnvelope:(SentryEnvelope *)envelope;

+ (void)storeEnvelope:(SentryEnvelope *)envelope;

@end

NS_ASSUME_NONNULL_END
