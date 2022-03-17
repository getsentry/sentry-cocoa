#import "SentryDefines.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/** A wrapper around SentryCrash for testability.
 */
@interface SentryCrashWrapper : NSObject
SENTRY_NO_INIT

+ (instancetype)sharedInstance;

- (BOOL)crashedLastLaunch;

- (NSTimeInterval)activeDurationSinceLastCrash;

- (BOOL)isBeingTraced;

- (BOOL)isApplicationInForeground;

- (void)installAsyncHooks;

- (void)deactivateAsyncHooks;

@end

NS_ASSUME_NONNULL_END
