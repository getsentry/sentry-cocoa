#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * A wrapper around sysctl for testability.
 */
@interface SentrySysctl : NSObject

/**
 * Returns the time the system was booted with a precision of microseconds.
 */
@property (readonly) NSDate *systemBootTimestamp;

@property (readonly) NSDate *processStartTimestamp;

/**
 * The system time that the process started, as measured in @c SentrySysctl.load, essentially the
 * earliest time we can record a system timestamp, which is the number of nanoseconds since the
 * device booted, which is why we can't simply convert @c processStartTimestamp to the nanosecond
 * representation of its @c timeIntervalSinceReferenceDate .
 */
@property (readonly) uint64_t runtimeInitSystemTimestamp;

@property (readonly) NSDate *runtimeInitTimestamp;

@property (readonly) NSDate *moduleInitializationTimestamp;

@end

NS_ASSUME_NONNULL_END
