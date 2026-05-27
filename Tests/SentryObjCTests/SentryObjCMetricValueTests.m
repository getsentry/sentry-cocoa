#import "SentryObjC.h"
@import XCTest;

@interface SentryObjCMetricValueTests : XCTestCase
@end

@implementation SentryObjCMetricValueTests

- (void)testCounter_shouldSetCounterValueAndType
{
    // -- Act --
    SentryObjCMetricValue *value = [SentryObjCMetricValue counter:42];

    // -- Assert --
    XCTAssertNotNil(value);
    XCTAssertTrue(value.isCounter);
    XCTAssertFalse(value.isGauge);
    XCTAssertFalse(value.isDistribution);
    XCTAssertEqual(value.counterValue, 42u);
}

- (void)testCounter_shouldReturnZeroForOtherTypes
{
    // -- Act --
    SentryObjCMetricValue *value = [SentryObjCMetricValue counter:42];

    // -- Assert --
    XCTAssertEqual(value.gaugeValue, 0.0);
    XCTAssertEqual(value.distributionValue, 0.0);
}

- (void)testGauge_shouldSetGaugeValueAndType
{
    // -- Act --
    SentryObjCMetricValue *value = [SentryObjCMetricValue gauge:3.14];

    // -- Assert --
    XCTAssertNotNil(value);
    XCTAssertTrue(value.isGauge);
    XCTAssertFalse(value.isCounter);
    XCTAssertFalse(value.isDistribution);
    XCTAssertEqualWithAccuracy(value.gaugeValue, 3.14, 0.001);
}

- (void)testGauge_shouldReturnZeroForOtherTypes
{
    // -- Act --
    SentryObjCMetricValue *value = [SentryObjCMetricValue gauge:3.14];

    // -- Assert --
    XCTAssertEqual(value.counterValue, 0u);
    XCTAssertEqual(value.distributionValue, 0.0);
}

- (void)testDistribution_shouldSetDistributionValueAndType
{
    // -- Act --
    SentryObjCMetricValue *value = [SentryObjCMetricValue distribution:99.9];

    // -- Assert --
    XCTAssertNotNil(value);
    XCTAssertTrue(value.isDistribution);
    XCTAssertFalse(value.isCounter);
    XCTAssertFalse(value.isGauge);
    XCTAssertEqualWithAccuracy(value.distributionValue, 99.9, 0.001);
}

- (void)testDistribution_shouldReturnZeroForOtherTypes
{
    // -- Act --
    SentryObjCMetricValue *value = [SentryObjCMetricValue distribution:99.9];

    // -- Assert --
    XCTAssertEqual(value.counterValue, 0u);
    XCTAssertEqual(value.gaugeValue, 0.0);
}

@end
