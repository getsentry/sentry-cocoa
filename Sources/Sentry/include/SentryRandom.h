#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

@protocol SentryRandom

/**
 * Returns a random number uniformly distributed over the interval [0.0 , 1.0].
 */
- (double)nextNumber;

@end

@interface SentryRandom : SENTRY_BASE_OBJECT <SentryRandom>

- (double)nextNumber;

@end

NS_ASSUME_NONNULL_END
