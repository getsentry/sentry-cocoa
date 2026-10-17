#import "SentryDefines.h"
@import _SentryPrivate;

NS_ASSUME_NONNULL_BEGIN

@interface SentrySDKInternal (Tests)

+ (void)setCurrentHub:(nullable SentryHubInternal *)hub;

+ (void)setStartOptions:(nullable SENTRY_SWIFT_MIGRATION_ID(SentryOptions))options
    NS_SWIFT_NAME(setStart(with:));

+ (void)captureEnvelope:(SENTRY_SWIFT_MIGRATION_ID(SentryEnvelope))envelope
    NS_SWIFT_NAME(capture(_:));

+ (void)storeEnvelope:(SENTRY_SWIFT_MIGRATION_ID(SentryEnvelope))envelope NS_SWIFT_NAME(store(_:));

@end

@interface SentrySDKInternal (TestAccess)
+ (nullable SENTRY_SWIFT_MIGRATION_ID(SentryOptions))options NS_SWIFT_NAME(test_options());
@end

NS_ASSUME_NONNULL_END
