#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryUnit : NSObject <NSCopying>
SENTRY_NO_INIT

- (instancetype)initWithUnit:(NSString *)unit;

@property (readonly, copy) NSString *unit;

@end

@interface SentryUnitDuration : SentryUnit
SENTRY_NO_INIT

/** Nanosecond, 10^-9 seconds. */
@property (class, readonly, copy) SentryUnitDuration *nanosecond;

/** Microsecond , 10^-6 seconds. */
@property (class, readonly, copy) SentryUnitDuration *microsecond;

/** Millisecond, 10^-3 seconds. */
@property (class, readonly, copy) SentryUnitDuration *millisecond;

/** Full second. */
@property (class, readonly, copy) SentryUnitDuration *second;

/** Minute, 60 seconds. */
@property (class, readonly, copy) SentryUnitDuration *minute;

/** Hour, 3600 seconds. */
@property (class, readonly, copy) SentryUnitDuration *hour;

/** Day, 86,400 seconds. */
@property (class, readonly, copy) SentryUnitDuration *day;

/** Week, 604,800 seconds. */
@property (class, readonly, copy) SentryUnitDuration *week;

@end

@interface SentryUnitInformation : SentryUnit
SENTRY_NO_INIT

/** Bit, corresponding to 1/8 of a byte. */
@property (class, readonly, copy) SentryUnitInformation *bit;

/** Byte. */
@property (class, readonly, copy) SentryUnitInformation *byte;

/** Kilobyte, 10^3 bytes. */
@property (class, readonly, copy) SentryUnitInformation *kilobyte;

/** Kibibyte, 2^10 bytes. */
@property (class, readonly, copy) SentryUnitInformation *kibibyte;

/** Megabyte, 10^6 bytes. */
@property (class, readonly, copy) SentryUnitInformation *megabyte;

/** Mebibyte, 2^20 bytes. */
@property (class, readonly, copy) SentryUnitInformation *mebibyte;

/** Gigabyte, 10^9 bytes. */
@property (class, readonly, copy) SentryUnitInformation *gigabyte;

/** Gibibyte, 2^30 bytes. */
@property (class, readonly, copy) SentryUnitInformation *gibibyte;

/** Terabyte, 10^12 bytes. */
@property (class, readonly, copy) SentryUnitInformation *terabyte;

/** Tebibyte, 2^40 bytes. */
@property (class, readonly, copy) SentryUnitInformation *tebibyte;

/** Petabyte, 10^15 bytes. */
@property (class, readonly, copy) SentryUnitInformation *petabyte;

/** Pebibyte, 2^50 bytes. */
@property (class, readonly, copy) SentryUnitInformation *pebibyte;

/** Exabyte, 10^18 bytes. */
@property (class, readonly, copy) SentryUnitInformation *exabyte;

/** Exbibyte, 2^60 bytes. */
@property (class, readonly, copy) SentryUnitInformation *exbibyte;

@end

@interface SentryUnitFraction : SentryUnit
SENTRY_NO_INIT

/** Floating point fraction of `1`. */
@property (class, readonly, copy) SentryUnitFraction *ratio;

/** Ratio expressed as a fraction of `100`. `100%` equals a ratio of `1.0`. */
@property (class, readonly, copy) SentryUnitFraction *percent;

@end

NS_ASSUME_NONNULL_END
