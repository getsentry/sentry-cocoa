#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/** A wrapper around SentryCrash for testability.
 */
@interface SentryCrashWrapper : NSObject

- (BOOL)crashedLastLaunch;

- (NSTimeInterval)activeDurationSinceLastCrash;

@end

NS_ASSUME_NONNULL_END
