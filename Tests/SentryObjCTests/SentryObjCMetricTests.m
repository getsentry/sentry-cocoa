@import SentryObjC;
@import XCTest;

@interface SentryObjCMetricTests : XCTestCase
@end

@implementation SentryObjCMetricTests

#pragma mark - Init

- (void)testInitWithAllParameters_shouldSetProperties
{
    // -- Arrange --
    NSDate *timestamp = [NSDate dateWithTimeIntervalSince1970:123];
    SentryObjCId *traceId = [[SentryObjCId alloc] init];
    SentryObjCMetricValue *value = [SentryObjCMetricValue distribution:4.25];
    SentryObjCUnit *unit = SentryObjCUnit.millisecond;
    NSDictionary<NSString *, SentryObjCAttributeContent *> *attributes =
        @{ @"source" : [SentryObjCAttributeContent string:@"test"] };

    // -- Act --
    SentryObjCMetric *metric = [[SentryObjCMetric alloc] initWithTimestamp:timestamp
                                                                   traceId:traceId
                                                                      name:@"api.response_time"
                                                                     value:value
                                                                      unit:unit
                                                                attributes:attributes];

    // -- Assert --
    XCTAssertNotNil(metric);
    XCTAssertEqualObjects(metric.timestamp, timestamp);
    XCTAssertEqualObjects(metric.traceId.sentryIdString, traceId.sentryIdString);
    XCTAssertEqualObjects(metric.name, @"api.response_time");
    XCTAssertTrue(metric.value.isDistribution);
    XCTAssertEqualWithAccuracy(metric.value.distributionValue, 4.25, 0.001);
    XCTAssertEqualObjects(metric.unit.rawValue, @"millisecond");
    XCTAssertEqual(metric.attributes.count, 1u);
}

- (void)testInitWithNilUnit_shouldSetUnitToNil
{
    // -- Arrange --
    NSDate *timestamp = [NSDate date];
    SentryObjCId *traceId = [[SentryObjCId alloc] init];
    SentryObjCMetricValue *value = [SentryObjCMetricValue counter:1];

    // -- Act --
    SentryObjCMetric *metric = [[SentryObjCMetric alloc] initWithTimestamp:timestamp
                                                                   traceId:traceId
                                                                      name:@"events"
                                                                     value:value
                                                                      unit:nil
                                                                attributes:@{ }];

    // -- Assert --
    XCTAssertNotNil(metric);
    XCTAssertNil(metric.unit);
    XCTAssertTrue(metric.value.isCounter);
    XCTAssertEqual(metric.value.counterValue, 1u);
}

- (void)testInitWithEmptyAttributes_shouldSetEmptyAttributes
{
    // -- Arrange --
    NSDate *timestamp = [NSDate date];
    SentryObjCId *traceId = [[SentryObjCId alloc] init];
    SentryObjCMetricValue *value = [SentryObjCMetricValue gauge:99.5];

    // -- Act --
    SentryObjCMetric *metric = [[SentryObjCMetric alloc] initWithTimestamp:timestamp
                                                                   traceId:traceId
                                                                      name:@"cpu"
                                                                     value:value
                                                                      unit:SentryObjCUnit.percent
                                                                attributes:@{ }];

    // -- Assert --
    XCTAssertNotNil(metric);
    XCTAssertEqual(metric.attributes.count, 0u);
    XCTAssertTrue(metric.value.isGauge);
    XCTAssertEqualWithAccuracy(metric.value.gaugeValue, 99.5, 0.001);
}

#pragma mark - Properties

- (void)testTimestamp_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCMetric *metric = [self createDefaultMetric];
    NSDate *newTimestamp = [NSDate dateWithTimeIntervalSince1970:999];

    // -- Act --
    metric.timestamp = newTimestamp;

    // -- Assert --
    XCTAssertEqualObjects(metric.timestamp, newTimestamp);
}

- (void)testName_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCMetric *metric = [self createDefaultMetric];

    // -- Act --
    metric.name = @"updated.metric";

    // -- Assert --
    XCTAssertEqualObjects(metric.name, @"updated.metric");
}

- (void)testTraceId_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCMetric *metric = [self createDefaultMetric];
    SentryObjCId *newTraceId = [[SentryObjCId alloc] init];

    // -- Act --
    metric.traceId = newTraceId;

    // -- Assert --
    XCTAssertEqualObjects(metric.traceId.sentryIdString, newTraceId.sentryIdString);
}

- (void)testSpanId_whenDefault_shouldBeNil
{
    // -- Arrange --
    SentryObjCMetric *metric = [self createDefaultMetric];

    // -- Assert --
    XCTAssertNil(metric.spanId);
}

- (void)testSpanId_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCMetric *metric = [self createDefaultMetric];
    SentryObjCSpanId *spanId = [[SentryObjCSpanId alloc] init];

    // -- Act --
    metric.spanId = spanId;

    // -- Assert --
    XCTAssertNotNil(metric.spanId);
}

- (void)testSpanId_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCMetric *metric = [self createDefaultMetric];
    metric.spanId = [[SentryObjCSpanId alloc] init];

    // -- Act --
    metric.spanId = nil;

    // -- Assert --
    XCTAssertNil(metric.spanId);
}

- (void)testValue_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCMetric *metric = [self createDefaultMetric];

    // -- Act --
    metric.value = [SentryObjCMetricValue gauge:7.5];

    // -- Assert --
    XCTAssertTrue(metric.value.isGauge);
    XCTAssertEqualWithAccuracy(metric.value.gaugeValue, 7.5, 0.001);
}

- (void)testUnit_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCMetric *metric = [self createDefaultMetric];

    // -- Act --
    metric.unit = SentryObjCUnit.byte;

    // -- Assert --
    XCTAssertEqualObjects(metric.unit.rawValue, @"byte");
}

- (void)testUnit_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCMetric *metric = [self createDefaultMetric];
    metric.unit = SentryObjCUnit.millisecond;

    // -- Act --
    metric.unit = nil;

    // -- Assert --
    XCTAssertNil(metric.unit);
}

- (void)testAttributes_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCMetric *metric = [self createDefaultMetric];
    NSDictionary<NSString *, SentryObjCAttributeContent *> *newAttributes = @{
        @"key1" : [SentryObjCAttributeContent string:@"val1"],
        @"key2" : [SentryObjCAttributeContent integer:42]
    };

    // -- Act --
    metric.attributes = newAttributes;

    // -- Assert --
    XCTAssertEqual(metric.attributes.count, 2u);
}

#pragma mark - Helpers

- (SentryObjCMetric *)createDefaultMetric
{
    return [[SentryObjCMetric alloc] initWithTimestamp:[NSDate date]
                                               traceId:[[SentryObjCId alloc] init]
                                                  name:@"test.metric"
                                                 value:[SentryObjCMetricValue counter:1]
                                                  unit:nil
                                            attributes:@{ }];
}

@end
