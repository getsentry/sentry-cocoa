#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryObjCUnit : NSObject

@property (nonatomic, readonly, copy) NSString *rawValue;

- (instancetype)initWithRawValue:(NSString *)rawValue;

// Duration
@property (nonatomic, class, readonly, strong) SentryObjCUnit *nanosecond;
@property (nonatomic, class, readonly, strong) SentryObjCUnit *microsecond;
@property (nonatomic, class, readonly, strong) SentryObjCUnit *millisecond;
@property (nonatomic, class, readonly, strong) SentryObjCUnit *second;
@property (nonatomic, class, readonly, strong) SentryObjCUnit *minute;
@property (nonatomic, class, readonly, strong) SentryObjCUnit *hour;
@property (nonatomic, class, readonly, strong) SentryObjCUnit *day;
@property (nonatomic, class, readonly, strong) SentryObjCUnit *week;

// Information
@property (nonatomic, class, readonly, strong) SentryObjCUnit *bit;
@property (nonatomic, class, readonly, strong) SentryObjCUnit *byte;
@property (nonatomic, class, readonly, strong) SentryObjCUnit *kilobyte;
@property (nonatomic, class, readonly, strong) SentryObjCUnit *kibibyte;
@property (nonatomic, class, readonly, strong) SentryObjCUnit *megabyte;
@property (nonatomic, class, readonly, strong) SentryObjCUnit *mebibyte;
@property (nonatomic, class, readonly, strong) SentryObjCUnit *gigabyte;
@property (nonatomic, class, readonly, strong) SentryObjCUnit *gibibyte;
@property (nonatomic, class, readonly, strong) SentryObjCUnit *terabyte;
@property (nonatomic, class, readonly, strong) SentryObjCUnit *tebibyte;
@property (nonatomic, class, readonly, strong) SentryObjCUnit *petabyte;
@property (nonatomic, class, readonly, strong) SentryObjCUnit *pebibyte;
@property (nonatomic, class, readonly, strong) SentryObjCUnit *exabyte;
@property (nonatomic, class, readonly, strong) SentryObjCUnit *exbibyte;

// Fraction
@property (nonatomic, class, readonly, strong) SentryObjCUnit *ratio;
@property (nonatomic, class, readonly, strong) SentryObjCUnit *percent;

@end

NS_ASSUME_NONNULL_END
