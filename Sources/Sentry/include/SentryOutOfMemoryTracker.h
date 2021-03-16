#import "SentryDefines.h"

@class SentryOptions, SentryCurrentDateProvider, SentryCrashAdapter;

NS_ASSUME_NONNULL_BEGIN

/**
 * Detect OOMs based on heuristics described in a blog post:
 * https://engineering.fb.com/2015/08/24/ios/reducing-fooms-in-the-facebook-ios-app/ If a OOM is
 * detected, the SDK sends it as crash event. Only works for iOS, tvOS and macCatalyst.
 */
@interface SentryOutOfMemoryTracker : NSObject
SENTRY_NO_INIT

- (instancetype)initWithOptions:(SentryOptions *)options
                   crashAdapter:(SentryCrashAdapter *)crashAdatper;

- (void)start;
- (void)stop;

@end

NS_ASSUME_NONNULL_END
