#import "SentryTransaction.h"

NS_ASSUME_NONNULL_BEGIN

@interface
SentryTransaction (Private)

/**
 * The absolute system timestamp at the time this transaction began.
 * @note Provided for use by profiling, which does not use @c NSDate as @c SentryTransaction does
 * for its normal timestamps. @c NSDate is not a safe API for time-sensitive measurements, because
 * the time can be changed in iOS settings, or by the system when it recalibrates with a remote
 * source of truth. The system time is based on the CPU clock.
 */
@property (assign, nonatomic) uint64_t absoluteStartTimeNs;

/**
 * The absolute system timestamp at the time this transaction finished.
 * @note Provided for use by profiling, which does not use @c NSDate as @c SentryTransaction does
 * for its normal timestamps. @c NSDate is not a safe API for time-sensitive measurements, because
 * the time can be changed in iOS settings, or by the system when it recalibrates with a remote
 * source of truth. The system time is based on the CPU clock.
 */
@property (assign, nonatomic) uint64_t absoluteEndTimeNs;

- (void)setMeasurementValue:(id)value forKey:(NSString *)key;

@end

NS_ASSUME_NONNULL_END
