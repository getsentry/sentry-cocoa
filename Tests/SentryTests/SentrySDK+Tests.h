#import "SentryDefines.h"
#import "SentrySDKInternal.h"

@class SentryEnvelope;
@class SentryHub;

NS_ASSUME_NONNULL_BEGIN

@interface SentrySDKInternal ()

+ (void)setCurrentHub:(nullable SentryHub *)hub;

+ (void)setStartOptions:(nullable SentryOptions *)options NS_SWIFT_NAME(setStart(with:));

+ (void)captureEnvelope:(SentryEnvelope *)envelope;

+ (void)storeEnvelope:(SentryEnvelope *)envelope;

@end

NS_ASSUME_NONNULL_END
