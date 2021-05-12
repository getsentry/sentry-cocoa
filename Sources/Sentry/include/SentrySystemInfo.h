#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * A wrapper around NSProcessInfo for testability.
 */
@interface SentrySystemInfo : NSObject

/**
 * Returns the time the system was booted with a precision of microseconds.
 */
@property (readonly) NSDate *systemBootTimestamp;

@end

NS_ASSUME_NONNULL_END
