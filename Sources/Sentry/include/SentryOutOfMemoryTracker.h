#import "SentryDefines.h"

@class SentryOptions, SentryCurrentDateProvider, SentryCrashAdapter, SentryDispatchQueueWrapper;

NS_ASSUME_NONNULL_BEGIN

static NSString *const SentryOutOfMemoryExceptionType = @"Out Of Memory";
static NSString *const SentryOutOfMemoryExceptionValue
    = @"The OS most likely terminated your app because it over-used RAM.";

/**
 * Detect OOMs based on heuristics described in a blog post:
 * https://engineering.fb.com/2015/08/24/ios/reducing-fooms-in-the-facebook-ios-app/ If a OOM is
 * detected, the SDK sends it as crash event. Only works for iOS, tvOS and macCatalyst.
 */
@interface SentryOutOfMemoryTracker : NSObject
SENTRY_NO_INIT

- (instancetype)initWithOptions:(SentryOptions *)options
                   crashAdapter:(SentryCrashAdapter *)crashAdatper
           dispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper;

- (void)start;
- (void)stop;

@end

NS_ASSUME_NONNULL_END
