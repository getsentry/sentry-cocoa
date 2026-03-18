#import <Foundation/Foundation.h>

#import "SentryObjCDefines.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * The unit of measurement of a metric value.
 *
 * @see SentrySpan
 */
@interface SentryMeasurementUnit : NSObject <NSCopying>

SENTRY_NO_INIT

/** Returns a custom measurement unit. */
- (instancetype)initWithUnit:(NSString *)unit;

/** The string representation of the measurement unit. */
@property (readonly, copy) NSString *unit;

/** Untyped value without a unit. */
@property (class, readonly, copy) SentryMeasurementUnit *none;

@end

/** Time duration units. */
@interface SentryMeasurementUnitDuration : SentryMeasurementUnit

SENTRY_NO_INIT

@property (class, readonly, copy) SentryMeasurementUnitDuration *nanosecond;
@property (class, readonly, copy) SentryMeasurementUnitDuration *microsecond;
@property (class, readonly, copy) SentryMeasurementUnitDuration *millisecond;
@property (class, readonly, copy) SentryMeasurementUnitDuration *second;
@property (class, readonly, copy) SentryMeasurementUnitDuration *minute;
@property (class, readonly, copy) SentryMeasurementUnitDuration *hour;
@property (class, readonly, copy) SentryMeasurementUnitDuration *day;
@property (class, readonly, copy) SentryMeasurementUnitDuration *week;

@end

/** Size of information units derived from bytes. */
@interface SentryMeasurementUnitInformation : SentryMeasurementUnit

SENTRY_NO_INIT

@property (class, readonly, copy) SentryMeasurementUnitInformation *bit;
@property (class, readonly, copy) SentryMeasurementUnitInformation *byte;
@property (class, readonly, copy) SentryMeasurementUnitInformation *kilobyte;
@property (class, readonly, copy) SentryMeasurementUnitInformation *kibibyte;
@property (class, readonly, copy) SentryMeasurementUnitInformation *megabyte;
@property (class, readonly, copy) SentryMeasurementUnitInformation *mebibyte;
@property (class, readonly, copy) SentryMeasurementUnitInformation *gigabyte;
@property (class, readonly, copy) SentryMeasurementUnitInformation *gibibyte;
@property (class, readonly, copy) SentryMeasurementUnitInformation *terabyte;
@property (class, readonly, copy) SentryMeasurementUnitInformation *tebibyte;
@property (class, readonly, copy) SentryMeasurementUnitInformation *petabyte;
@property (class, readonly, copy) SentryMeasurementUnitInformation *pebibyte;
@property (class, readonly, copy) SentryMeasurementUnitInformation *exabyte;
@property (class, readonly, copy) SentryMeasurementUnitInformation *exbibyte;

@end

/** Units of fraction. */
@interface SentryMeasurementUnitFraction : SentryMeasurementUnit

SENTRY_NO_INIT

@property (class, readonly, copy) SentryMeasurementUnitFraction *ratio;
@property (class, readonly, copy) SentryMeasurementUnitFraction *percent;

@end

NS_ASSUME_NONNULL_END
