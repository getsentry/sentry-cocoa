#import "SentryDefines.h"

@class SentryOptions, SentryWatchdogTerminationLogic, SentryDispatchQueueWrapper,
    SentryAppStateManager, SentryFileManager;

NS_ASSUME_NONNULL_BEGIN

static NSString *const SentryWatchdogTerminationExceptionType = @"WatchdogTermination";
static NSString *const SentryWatchdogTerminationExceptionValue
    = @"The OS watchdog terminated your app.";
static NSString *const SentryWatchdogTerminationMechanismType = @"watchdog_termination";

static NSString *const SentryOOMTerminationExceptionType = @"OutOfMemoryTermination";
static NSString *const SentryOOMTerminationExceptionValue
= @"The OS watchdog terminated your app because it overused RAM.";
static NSString *const SentryOOMTerminationMechanismType = @"oom_termination";

/**
 * Detect OOMs based on heuristics described in a blog post:
 * https://engineering.fb.com/2015/08/24/ios/reducing-fooms-in-the-facebook-ios-app/ If a OOM is
 * detected, the SDK sends it as crash event. Only works for iOS, tvOS and macCatalyst.
 */
@interface SentryWatchdogTerminationTracker : NSObject
SENTRY_NO_INIT

- (instancetype)initWithOptions:(SentryOptions *)options
       watchdogTerminationLogic:(SentryWatchdogTerminationLogic *)watchdogTerminationLogic
                appStateManager:(SentryAppStateManager *)appStateManager
           dispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper
                    fileManager:(SentryFileManager *)fileManager;

- (void)start;
- (void)stop;

@end

NS_ASSUME_NONNULL_END
