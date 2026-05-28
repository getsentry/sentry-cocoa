#import <Foundation/Foundation.h>
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCDefines.h"
#else
#    import <SentryObjC/SentryObjCDefines.h>
#endif

NS_ASSUME_NONNULL_BEGIN

/**
 * The unit of measurement of a metric value.
 * @discussion Units augment metric values by giving them a magnitude and semantics. There are
 * certain types of units that are subdivided in their precision, such as duration for time
 * measurements. The following unit categories are available: duration, information, and fraction.
 * @note When using the units for custom measurements, Sentry will apply formatting to display
 * measurement values in the UI.
 */
@interface SentryObjCMeasurementUnit : NSObject
SENTRY_NO_INIT

/**
 * The @c NSString representation of the measurement unit.
 */
@property (nonatomic, readonly, copy) NSString *unit;

/**
 * Returns an initialized @c SentryObjCMeasurementUnit with a custom measurement unit.
 * @param unit Your own custom unit without built-in conversion in Sentry.
 */
- (instancetype)initWithUnit:(NSString *)unit;

/// Untyped value without a unit.
@property (nonatomic, class, readonly, copy) SentryObjCMeasurementUnit *none;

// MARK: - Duration

/// Nanosecond, 10^-9 seconds.
@property (nonatomic, class, readonly, copy) SentryObjCMeasurementUnit *nanosecond;

/// Microsecond, 10^-6 seconds.
@property (nonatomic, class, readonly, copy) SentryObjCMeasurementUnit *microsecond;

/// Millisecond, 10^-3 seconds.
@property (nonatomic, class, readonly, copy) SentryObjCMeasurementUnit *millisecond;

/// Full second.
@property (nonatomic, class, readonly, copy) SentryObjCMeasurementUnit *second;

/// Minute, 60 seconds.
@property (nonatomic, class, readonly, copy) SentryObjCMeasurementUnit *minute;

/// Hour, 3600 seconds.
@property (nonatomic, class, readonly, copy) SentryObjCMeasurementUnit *hour;

/// Day, 86,400 seconds.
@property (nonatomic, class, readonly, copy) SentryObjCMeasurementUnit *day;

/// Week, 604,800 seconds.
@property (nonatomic, class, readonly, copy) SentryObjCMeasurementUnit *week;

// MARK: - Information

/// Bit, corresponding to 1/8 of a byte.
@property (nonatomic, class, readonly, copy) SentryObjCMeasurementUnit *bit;

/// Byte.
@property (nonatomic, class, readonly, copy) SentryObjCMeasurementUnit *byte;

/// Kilobyte, 10^3 bytes.
@property (nonatomic, class, readonly, copy) SentryObjCMeasurementUnit *kilobyte;

/// Kibibyte, 2^10 bytes.
@property (nonatomic, class, readonly, copy) SentryObjCMeasurementUnit *kibibyte;

/// Megabyte, 10^6 bytes.
@property (nonatomic, class, readonly, copy) SentryObjCMeasurementUnit *megabyte;

/// Mebibyte, 2^20 bytes.
@property (nonatomic, class, readonly, copy) SentryObjCMeasurementUnit *mebibyte;

/// Gigabyte, 10^9 bytes.
@property (nonatomic, class, readonly, copy) SentryObjCMeasurementUnit *gigabyte;

/// Gibibyte, 2^30 bytes.
@property (nonatomic, class, readonly, copy) SentryObjCMeasurementUnit *gibibyte;

/// Terabyte, 10^12 bytes.
@property (nonatomic, class, readonly, copy) SentryObjCMeasurementUnit *terabyte;

/// Tebibyte, 2^40 bytes.
@property (nonatomic, class, readonly, copy) SentryObjCMeasurementUnit *tebibyte;

/// Petabyte, 10^15 bytes.
@property (nonatomic, class, readonly, copy) SentryObjCMeasurementUnit *petabyte;

/// Pebibyte, 2^50 bytes.
@property (nonatomic, class, readonly, copy) SentryObjCMeasurementUnit *pebibyte;

/// Exabyte, 10^18 bytes.
@property (nonatomic, class, readonly, copy) SentryObjCMeasurementUnit *exabyte;

/// Exbibyte, 2^60 bytes.
@property (nonatomic, class, readonly, copy) SentryObjCMeasurementUnit *exbibyte;

// MARK: - Fraction

/// Floating point fraction of @c 1.
@property (nonatomic, class, readonly, copy) SentryObjCMeasurementUnit *ratio;

/// Ratio expressed as a fraction of @c 100. @c 100% equals a ratio of @c 1.0.
@property (nonatomic, class, readonly, copy) SentryObjCMeasurementUnit *percent;

@end

NS_ASSUME_NONNULL_END
