#import "SentryTracer+Test.h"
#import <Foundation/Foundation.h>

void
testing_setMeasurementWithNilName(SentryTracer *tracer, NSNumber *value)
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    [tracer setMeasurement:nil value:value];
#pragma clang diagnostic pop
}

void
testing_setMeasurementWithNilNameAndUnit(
    SentryTracer *tracer, NSNumber *value, SentryMeasurementUnit *unit)
{

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    [tracer setMeasurement:nil value:value unit:unit];
#pragma clang diagnostic pop
}
