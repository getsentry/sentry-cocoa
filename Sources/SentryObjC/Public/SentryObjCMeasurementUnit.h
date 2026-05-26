#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryObjCMeasurementUnit : NSObject

@property (nonatomic, readonly, copy) NSString *unit;

- (instancetype)initWithUnit:(NSString *)unit;

@property (nonatomic, class, readonly, copy) SentryObjCMeasurementUnit *none;

// Duration
@property (nonatomic, class, readonly, copy) SentryObjCMeasurementUnit *nanosecond;
@property (nonatomic, class, readonly, copy) SentryObjCMeasurementUnit *microsecond;
@property (nonatomic, class, readonly, copy) SentryObjCMeasurementUnit *millisecond;
@property (nonatomic, class, readonly, copy) SentryObjCMeasurementUnit *second;
@property (nonatomic, class, readonly, copy) SentryObjCMeasurementUnit *minute;
@property (nonatomic, class, readonly, copy) SentryObjCMeasurementUnit *hour;
@property (nonatomic, class, readonly, copy) SentryObjCMeasurementUnit *day;
@property (nonatomic, class, readonly, copy) SentryObjCMeasurementUnit *week;

// Information
@property (nonatomic, class, readonly, copy) SentryObjCMeasurementUnit *bit;
@property (nonatomic, class, readonly, copy) SentryObjCMeasurementUnit *byte;
@property (nonatomic, class, readonly, copy) SentryObjCMeasurementUnit *kilobyte;
@property (nonatomic, class, readonly, copy) SentryObjCMeasurementUnit *kibibyte;
@property (nonatomic, class, readonly, copy) SentryObjCMeasurementUnit *megabyte;
@property (nonatomic, class, readonly, copy) SentryObjCMeasurementUnit *mebibyte;
@property (nonatomic, class, readonly, copy) SentryObjCMeasurementUnit *gigabyte;
@property (nonatomic, class, readonly, copy) SentryObjCMeasurementUnit *gibibyte;
@property (nonatomic, class, readonly, copy) SentryObjCMeasurementUnit *terabyte;
@property (nonatomic, class, readonly, copy) SentryObjCMeasurementUnit *tebibyte;
@property (nonatomic, class, readonly, copy) SentryObjCMeasurementUnit *petabyte;
@property (nonatomic, class, readonly, copy) SentryObjCMeasurementUnit *pebibyte;
@property (nonatomic, class, readonly, copy) SentryObjCMeasurementUnit *exabyte;
@property (nonatomic, class, readonly, copy) SentryObjCMeasurementUnit *exbibyte;

// Fraction
@property (nonatomic, class, readonly, copy) SentryObjCMeasurementUnit *ratio;
@property (nonatomic, class, readonly, copy) SentryObjCMeasurementUnit *percent;

@end

NS_ASSUME_NONNULL_END
