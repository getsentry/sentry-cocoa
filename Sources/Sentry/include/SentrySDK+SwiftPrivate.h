#import "SentrySDKInternal.h"

@class SentryScope;

NS_ASSUME_NONNULL_BEGIN

// Event is a Swift class, so these declarations use id.

@interface SentrySDKInternal (SwiftPrivate)

+ (SentryId *)captureEvent:(SENTRY_SWIFT_MIGRATION_ID(SentryEvent))event
    NS_SWIFT_NAME(capture(event:));

+ (SentryId *)captureEvent:(SENTRY_SWIFT_MIGRATION_ID(SentryEvent))event
                 withScope:(SentryScope *)scope NS_SWIFT_NAME(capture(event:scope:));

+ (SentryId *)captureEvent:(SENTRY_SWIFT_MIGRATION_ID(SentryEvent))event
            withScopeBlock:(void (^)(SentryScope *scope))block NS_SWIFT_NAME(capture(event:block:));

+ (SentryId *)captureEvent:(SENTRY_SWIFT_MIGRATION_ID(SentryEvent))event
                 withScope:(SentryScope *)scope
                      hint:(SENTRY_SWIFT_MIGRATION_ID(SentryHint))hint
    NS_SWIFT_NAME(capture(event:scope:hint:));

+ (void)captureFatalEvent:(SENTRY_SWIFT_MIGRATION_ID(SentryEvent))event
    NS_SWIFT_NAME(captureFatalEvent(_:));

+ (void)captureFatalEvent:(SENTRY_SWIFT_MIGRATION_ID(SentryEvent))event
                withScope:(SentryScope *)scope NS_SWIFT_NAME(captureFatalEvent(_:with:));

#if SENTRY_HAS_UIKIT && !SDK_V10
+ (void)captureFatalAppHangEvent:(SENTRY_SWIFT_MIGRATION_ID(SentryEvent))event
    NS_SWIFT_NAME(captureFatalAppHang(_:));
#endif // SENTRY_HAS_UIKIT && !SDK_V10

@end

NS_ASSUME_NONNULL_END
