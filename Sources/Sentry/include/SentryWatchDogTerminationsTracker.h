#import "SentryDefines.h"

@class SentryOptions, SentryWatchDogTerminationsLogic, SentryDispatchQueueWrapper,
    SentryAppStateManager, SentryFileManager;

NS_ASSUME_NONNULL_BEGIN

static NSString *const SentryWatchDogTerminationExceptionType = @"WatchDogTermination";
static NSString *const SentryWatchDogTerminationExceptionValue
    = @"The OS terminated your app, possibly because it overused RAM.";
static NSString *const SentryWatchDogTerminationMechanismType = @"watchdog_termination";

/**
 * Detect OOMs based on heuristics described in a blog post:
 * https://engineering.fb.com/2015/08/24/ios/reducing-fooms-in-the-facebook-ios-app/ If a OOM is
 * detected, the SDK sends it as crash event. Only works for iOS, tvOS and macCatalyst.
 */
@interface SentryWatchDogTerminationsTracker : NSObject
SENTRY_NO_INIT

- (instancetype)initWithOptions:(SentryOptions *)options
      watchDogTerminationsLogic:(SentryWatchDogTerminationsLogic *)watchDogTerminationsLogic
                appStateManager:(SentryAppStateManager *)appStateManager
           dispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper
                    fileManager:(SentryFileManager *)fileManager;

- (void)start;
- (void)stop;

@end

NS_ASSUME_NONNULL_END
