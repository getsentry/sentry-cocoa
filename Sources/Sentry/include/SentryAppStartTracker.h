#import "SentryCurrentDateProvider.h"
#import "SentryDefines.h"

@class SentryOptions, SentryDispatchQueueWrapper, SentryAppStateManager, SentrySystemInfo;

NS_ASSUME_NONNULL_BEGIN

@interface SentryAppStartTracker : NSObject
SENTRY_NO_INIT

- (instancetype)initWithOptions:(SentryOptions *)options
            currentDateProvider:(id<SentryCurrentDateProvider>)currentDateProvider
           dispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper
                appStateManager:(SentryAppStateManager *)appStateManager
                    processInfo:(SentrySystemInfo *)processInfo;

- (void)start;
- (void)stop;

@end

NS_ASSUME_NONNULL_END
