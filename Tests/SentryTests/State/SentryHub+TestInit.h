#import <Sentry/Sentry.h>

NS_ASSUME_NONNULL_BEGIN

/** Expose the internal test init for testing. */
@interface
SentryHub (TestInit)

- (instancetype)initWithClient:(SentryClient *_Nullable)client
                      andScope:(SentryScope *_Nullable)scope
        andCurrentDateProvider:(id<SentryCurrentDateProvider>)currentDateProvider;

@end

NS_ASSUME_NONNULL_END
