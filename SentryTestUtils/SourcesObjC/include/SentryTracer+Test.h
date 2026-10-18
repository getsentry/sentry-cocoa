#import "SentryTracer.h"

NS_ASSUME_NONNULL_BEGIN

@class SentryMeasurementUnit;

@interface SentryTracer (Test)

- (void)updateStartTime:(NSDate *)startTime;

@end

void testing_setMeasurementWithNilName(SentryTracer *tracer, NSNumber *value);

void testing_setMeasurementWithNilNameAndUnit(
    SentryTracer *tracer, NSNumber *value, SentryMeasurementUnit *unit);

NS_ASSUME_NONNULL_END
