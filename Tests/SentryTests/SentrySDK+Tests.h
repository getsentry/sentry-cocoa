#import "SentryDefines.h"
#import "SentrySDK.h"

@class SentryEnvelope;
@class SentryHub;

NS_ASSUME_NONNULL_BEGIN

@interface
SentrySDK ()

+ (void)setCurrentHub:(nullable SentryHub *)hub;

+ (void)captureEnvelope:(SentryEnvelope *)envelope;

+ (void)storeEnvelope:(SentryEnvelope *)envelope;

@end

NS_ASSUME_NONNULL_END
