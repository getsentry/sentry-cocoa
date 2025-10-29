#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Captures early runtime initialization timestamps using Objective-C's +load method and constructor
 * attributes. This needs to be in ObjC because Swift doesn't support +load or early constructor
 * execution. Also provides bridging methods to access low-level sysctl C functions from Swift.
 */
@interface SentryRuntimeInit : NSObject

/**
 * The system time that the process started, as measured in @c SentryRuntimeInit.load, essentially
 * the earliest time we can record a system timestamp, which is the number of nanoseconds since the
 * device booted, which is why we can't simply convert a Date's timeIntervalSinceReferenceDate to
 * nanoseconds.
 */
@property (readonly) uint64_t runtimeInitSystemTimestamp;

/**
 * The timestamp when the runtime was initialized (captured in +load).
 */
@property (readonly) NSDate *runtimeInitTimestamp;

/**
 * The timestamp when the module was initialized (captured via constructor attribute).
 */
@property (readonly) NSDate *moduleInitializationTimestamp;

@end

NS_ASSUME_NONNULL_END
