#import "SentryCurrentDateProvider.h"
#import "SentryDefines.h"

@class SentryOptions, SentryDispatchQueueWrapper, SentryAppStateManager, SentrySysctl;

NS_ASSUME_NONNULL_BEGIN

@interface SentryAppStartTracker : NSObject
SENTRY_NO_INIT

- (instancetype)initWithOptions:(SentryOptions *)options
            currentDateProvider:(id<SentryCurrentDateProvider>)currentDateProvider
           dispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper
                appStateManager:(SentryAppStateManager *)appStateManager
                         sysctl:(SentrySysctl *)sysctl;

- (void)start;
- (void)stop;

@end

NS_ASSUME_NONNULL_END
