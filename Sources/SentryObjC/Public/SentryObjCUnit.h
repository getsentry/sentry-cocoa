#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Type-safe units for telemetry data (Metrics, Spans, and Logs).
 *
 * These units help Sentry display metric values in a human-readable format.
 * Use the predefined class properties for common units, or initialize with a custom string
 * for custom units.
 *
 * @see https://develop.sentry.dev/sdk/telemetry/attributes/#units
 */
@interface SentryObjCUnit : NSObject

/// The string representation of the unit.
@property (nonatomic, readonly, copy) NSString *rawValue;

/// Creates a unit from its string representation.
- (instancetype)initWithRawValue:(NSString *)rawValue;

// Duration

/// Nanosecond duration unit.
@property (nonatomic, class, readonly, strong) SentryObjCUnit *nanosecond;
/// Microsecond duration unit.
@property (nonatomic, class, readonly, strong) SentryObjCUnit *microsecond;
/// Millisecond duration unit.
@property (nonatomic, class, readonly, strong) SentryObjCUnit *millisecond;
/// Second duration unit.
@property (nonatomic, class, readonly, strong) SentryObjCUnit *second;
/// Minute duration unit.
@property (nonatomic, class, readonly, strong) SentryObjCUnit *minute;
/// Hour duration unit.
@property (nonatomic, class, readonly, strong) SentryObjCUnit *hour;
/// Day duration unit.
@property (nonatomic, class, readonly, strong) SentryObjCUnit *day;
/// Week duration unit.
@property (nonatomic, class, readonly, strong) SentryObjCUnit *week;

// Information

/// Bit information unit.
@property (nonatomic, class, readonly, strong) SentryObjCUnit *bit;
/// Byte information unit.
@property (nonatomic, class, readonly, strong) SentryObjCUnit *byte;
/// Kilobyte information unit (1000 bytes).
@property (nonatomic, class, readonly, strong) SentryObjCUnit *kilobyte;
/// Kibibyte information unit (1024 bytes).
@property (nonatomic, class, readonly, strong) SentryObjCUnit *kibibyte;
/// Megabyte information unit (1000^2 bytes).
@property (nonatomic, class, readonly, strong) SentryObjCUnit *megabyte;
/// Mebibyte information unit (1024^2 bytes).
@property (nonatomic, class, readonly, strong) SentryObjCUnit *mebibyte;
/// Gigabyte information unit (1000^3 bytes).
@property (nonatomic, class, readonly, strong) SentryObjCUnit *gigabyte;
/// Gibibyte information unit (1024^3 bytes).
@property (nonatomic, class, readonly, strong) SentryObjCUnit *gibibyte;
/// Terabyte information unit (1000^4 bytes).
@property (nonatomic, class, readonly, strong) SentryObjCUnit *terabyte;
/// Tebibyte information unit (1024^4 bytes).
@property (nonatomic, class, readonly, strong) SentryObjCUnit *tebibyte;
/// Petabyte information unit (1000^5 bytes).
@property (nonatomic, class, readonly, strong) SentryObjCUnit *petabyte;
/// Pebibyte information unit (1024^5 bytes).
@property (nonatomic, class, readonly, strong) SentryObjCUnit *pebibyte;
/// Exabyte information unit (1000^6 bytes).
@property (nonatomic, class, readonly, strong) SentryObjCUnit *exabyte;
/// Exbibyte information unit (1024^6 bytes).
@property (nonatomic, class, readonly, strong) SentryObjCUnit *exbibyte;

// Fraction

/// Ratio fraction unit (value between 0 and 1).
@property (nonatomic, class, readonly, strong) SentryObjCUnit *ratio;
/// Percent fraction unit (value between 0 and 100).
@property (nonatomic, class, readonly, strong) SentryObjCUnit *percent;

@end

NS_ASSUME_NONNULL_END
