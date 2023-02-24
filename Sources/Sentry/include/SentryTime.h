#import "SentryCompiler.h"
#import "SentryProfilingConditionals.h"
#import <Foundation/Foundation.h>
#import <stdint.h>

NS_ASSUME_NONNULL_BEGIN

SENTRY_EXTERN_C_BEGIN

/**
 * Given a fractional amount of seconds in a @c double from a Cocoa API like @c -[NSDate @c
 * timeIntervalSinceDate:], return an integer representing the amount of nanoseconds.
 */
uint64_t timeIntervalToNanoseconds(double seconds);

/**
 * Returns the absolute timestamp, which has no defined reference point or unit
 * as it is platform dependent.
 */
uint64_t getAbsoluteTime(void);

/**
 * @Returns The duration in nanoseconds between two absolute timestamps, as a @c NSNumber wrapping
 * an unsigned 64 bit integer, or @c nil if the inputs were not ordered in such a way that the end
 * input is earlier than the beginning input, which would return a negative duration.
 */
NSNumber *_Nullable getDurationNs(uint64_t startTimestamp, uint64_t endTimestamp);

SENTRY_EXTERN_C_END

NS_ASSUME_NONNULL_END
