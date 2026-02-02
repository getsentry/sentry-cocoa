#import "SentryDefines.h"
#import <Foundation/Foundation.h>

#if SENTRY_HAS_UIKIT

NS_ASSUME_NONNULL_BEGIN

/**
 * Helper class for SentryAppStartTracker that captures app start timing information
 * as early as possible via the +load method and sets the values in SentryAppStartTracker.
 */
@interface SentryAppStartTrackerHelper : NSObject

- (NSDate *)runtimeInitTimestamp;
- (BOOL)isActivePrewarm;

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
