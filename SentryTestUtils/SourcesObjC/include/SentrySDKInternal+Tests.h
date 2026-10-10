#import "SentryDefines.h"
@import _SentryPrivate;

NS_ASSUME_NONNULL_BEGIN

@interface SentrySDKInternal (Tests)

+ (void)setCurrentHub:(nullable SentryHubInternal *)hub;

+ (void)setStartOptions:(nullable SENTRY_SWIFT_MIGRATION_ID(SentryOptions))options
    NS_SWIFT_NAME(test_setStart(with:));

+ (void)captureEnvelope:(SENTRY_SWIFT_MIGRATION_ID(SentryEnvelope))envelope
    NS_SWIFT_NAME(test_captureEnvelope(_:));

+ (void)storeEnvelope:(SENTRY_SWIFT_MIGRATION_ID(SentryEnvelope))envelope
    NS_SWIFT_NAME(test_storeEnvelope(_:));

@end

NS_ASSUME_NONNULL_END
