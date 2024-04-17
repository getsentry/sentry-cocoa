#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * An interface to the new continuous profiling implementation.
 */
@interface SentryContinuousProfiler : NSObject

/** Start a continuous  profiling session if one doesn't already exist. */
+ (void)start;

/** Stop a continuous profiling session if there is one ongoing. */
+ (void)stop;

@end

NS_ASSUME_NONNULL_END
