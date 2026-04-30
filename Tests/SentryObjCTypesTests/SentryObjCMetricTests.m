#import <XCTest/XCTest.h>

#if __has_include(<SentryObjCTypes/SentryObjCAttributeContent.h>)
#    import <SentryObjCTypes/SentryObjCAttributeContent.h>
#    import <SentryObjCTypes/SentryObjCMetric.h>
#    import <SentryObjCTypes/SentryObjCMetricValue.h>
#else
#    import "SentryObjCAttributeContent.h"
#    import "SentryObjCMetric.h"
#    import "SentryObjCMetricValue.h"
#endif

#if __has_include(<SentryHeaders/SentryId.h>)
#    import <SentryHeaders/SentryId.h>
#    import <SentryHeaders/SentrySpanId.h>
#else
#    import "SentryId.h"
#    import "SentrySpanId.h"
#endif

@interface SentryObjCMetricTests : XCTestCase
@end

@implementation SentryObjCMetricTests

- (void)testProperties_whenAssigned_shouldStoreAllValues
{
    // -- Arrange --
    SentryObjCMetric *metric = [[SentryObjCMetric alloc]
        initWithTimestamp:[NSDate dateWithTimeIntervalSince1970:1]
                     name:@"original.metric"
                  traceId:[[SentryId alloc] initWithUUIDString:@"550e8400e29b41d4a716446655440000"]
                   spanId:[[SentrySpanId alloc] initWithValue:@"b0e6f15b45c36b12"]
                    value:[SentryObjCMetricValue counterWithValue:1]
                     unit:@"millisecond"
               attributes:@{ @"source" : [SentryObjCAttributeContent stringWithValue:@"initial"] }];

    NSDate *updatedTimestamp = [NSDate dateWithTimeIntervalSince1970:123];
    SentryId *updatedTraceId =
        [[SentryId alloc] initWithUUIDString:@"12345678123456781234567812345678"];
    SentrySpanId *updatedSpanId = [[SentrySpanId alloc] initWithValue:@"8765432112345678"];

    // -- Act --
    metric.timestamp = updatedTimestamp;
    metric.name = @"updated.metric";
    metric.traceId = updatedTraceId;
    metric.spanId = updatedSpanId;
    metric.value = [SentryObjCMetricValue gaugeWithValue:5.5];
    metric.unit = @"second";
    metric.attributes = @{ @"source" : [SentryObjCAttributeContent stringWithValue:@"objc"] };

    // -- Assert --
    XCTAssertEqualObjects(metric.timestamp, updatedTimestamp);
    XCTAssertEqualObjects(metric.name, @"updated.metric");
    XCTAssertEqualObjects(metric.traceId, updatedTraceId);
    XCTAssertEqualObjects(metric.spanId, updatedSpanId);
    XCTAssertEqual(metric.value.type, SentryObjCMetricValueTypeGauge);
    XCTAssertEqualWithAccuracy(metric.value.gaugeValue, 5.5, 0.001);
    XCTAssertEqualObjects(metric.unit, @"second");
    XCTAssertEqualObjects(metric.attributes[@"source"].stringValue, @"objc");
}

@end
