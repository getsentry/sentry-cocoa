#import "SentryDefines.h"

@class SentryEnvelope;
@class SentryHub;

NS_ASSUME_NONNULL_BEGIN

@interface SentrySDKInternal ()

+ (void)setCurrentHub:(nullable SentryHubInternal *)hub;

+ (void)setStartOptions:(nullable SentryOptionsInternal *)options NS_SWIFT_NAME(setStart(with:));

+ (void)captureEnvelope:(SentryEnvelope *)envelope;

+ (void)storeEnvelope:(SentryEnvelope *)envelope;

@end

NS_ASSUME_NONNULL_END
