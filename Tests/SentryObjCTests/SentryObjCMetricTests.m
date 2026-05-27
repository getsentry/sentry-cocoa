@import SentryObjC;
@import XCTest;

@interface SentryObjCMetricTests : XCTestCase
@end

@implementation SentryObjCMetricTests

- (void)testTimestamp_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCMetric *metric = [[SentryObjCMetric alloc] init];
    NSDate *now = [NSDate date];

    // -- Act --
    metric.timestamp = now;

    // -- Assert --
    XCTAssertEqualObjects(metric.timestamp, now);
}

- (void)testName_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCMetric *metric = [[SentryObjCMetric alloc] init];

    // -- Act --
    metric.name = @"api.response_time";

    // -- Assert --
    XCTAssertEqualObjects(metric.name, @"api.response_time");
}

- (void)testTraceId_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCMetric *metric = [[SentryObjCMetric alloc] init];
    SentryObjCId *traceId = [[SentryObjCId alloc] init];

    // -- Act --
    metric.traceId = traceId;

    // -- Assert --
    XCTAssertNotNil(metric.traceId);
}

- (void)testSpanId_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCMetric *metric = [[SentryObjCMetric alloc] init];
    SentryObjCSpanId *spanId = [[SentryObjCSpanId alloc] init];

    // -- Act --
    metric.spanId = spanId;

    // -- Assert --
    XCTAssertNotNil(metric.spanId);
}

- (void)testSpanId_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCMetric *metric = [[SentryObjCMetric alloc] init];
    metric.spanId = [[SentryObjCSpanId alloc] init];

    // -- Act --
    metric.spanId = nil;

    // -- Assert --
    XCTAssertNil(metric.spanId);
}

- (void)testValue_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCMetric *metric = [[SentryObjCMetric alloc] init];
    SentryObjCMetricValue *value = [SentryObjCMetricValue counter:5];

    // -- Act --
    metric.value = value;

    // -- Assert --
    XCTAssertNotNil(metric.value);
}

- (void)testUnit_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCMetric *metric = [[SentryObjCMetric alloc] init];
    SentryObjCUnit *unit = SentryObjCUnit.millisecond;

    // -- Act --
    metric.unit = unit;

    // -- Assert --
    XCTAssertNotNil(metric.unit);
}

- (void)testUnit_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCMetric *metric = [[SentryObjCMetric alloc] init];
    metric.unit = SentryObjCUnit.millisecond;

    // -- Act --
    metric.unit = nil;

    // -- Assert --
    XCTAssertNil(metric.unit);
}

- (void)testAttributes_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCMetric *metric = [[SentryObjCMetric alloc] init];
    SentryObjCAttributeContent *attrContent = [SentryObjCAttributeContent string:@"GET"];

    // -- Act --
    metric.attributes = @{ @"http.method" : attrContent };

    // -- Assert --
    XCTAssertEqual(metric.attributes.count, 1u);
    XCTAssertNotNil(metric.attributes[@"http.method"]);
}

@end
