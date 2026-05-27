@import SentryObjC;
@import XCTest;

@interface SentryObjCMetricsApiTests : XCTestCase
@end

@implementation SentryObjCMetricsApiTests

#pragma mark - Class existence

- (void)testClass_shouldExist
{
    // -- Arrange & Act --
    Class metricsClass = NSClassFromString(@"SentryObjCMetricsApi");

    // -- Assert --
    XCTAssertNotNil(metricsClass);
}

#pragma mark - count selectors

- (void)testCountKeyValueAttributes_selectorShouldExist
{
    // -- Arrange --
    Class cls = NSClassFromString(@"SentryObjCMetricsApi");

    // -- Assert --
    XCTAssertTrue([cls instancesRespondToSelector:@selector(countWithKey:value:attributes:)]);
}

- (void)testCountKeyValue_selectorShouldExist
{
    // -- Arrange --
    Class cls = NSClassFromString(@"SentryObjCMetricsApi");

    // -- Assert --
    XCTAssertTrue([cls instancesRespondToSelector:@selector(countWithKey:value:)]);
}

- (void)testCountKey_selectorShouldExist
{
    // -- Arrange --
    Class cls = NSClassFromString(@"SentryObjCMetricsApi");

    // -- Assert --
    XCTAssertTrue([cls instancesRespondToSelector:@selector(countWithKey:)]);
}

#pragma mark - distribution selectors

- (void)testDistributionKeyValueUnitAttributes_selectorShouldExist
{
    // -- Arrange --
    Class cls = NSClassFromString(@"SentryObjCMetricsApi");

    // -- Assert --
    XCTAssertTrue(
        [cls instancesRespondToSelector:@selector(distributionWithKey:value:unit:attributes:)]);
}

- (void)testDistributionKeyValueUnit_selectorShouldExist
{
    // -- Arrange --
    Class cls = NSClassFromString(@"SentryObjCMetricsApi");

    // -- Assert --
    XCTAssertTrue([cls instancesRespondToSelector:@selector(distributionWithKey:value:unit:)]);
}

- (void)testDistributionKeyValue_selectorShouldExist
{
    // -- Arrange --
    Class cls = NSClassFromString(@"SentryObjCMetricsApi");

    // -- Assert --
    XCTAssertTrue([cls instancesRespondToSelector:@selector(distributionWithKey:value:)]);
}

#pragma mark - gauge selectors

- (void)testGaugeKeyValueUnitAttributes_selectorShouldExist
{
    // -- Arrange --
    Class cls = NSClassFromString(@"SentryObjCMetricsApi");

    // -- Assert --
    XCTAssertTrue([cls instancesRespondToSelector:@selector(gaugeWithKey:value:unit:attributes:)]);
}

- (void)testGaugeKeyValueUnit_selectorShouldExist
{
    // -- Arrange --
    Class cls = NSClassFromString(@"SentryObjCMetricsApi");

    // -- Assert --
    XCTAssertTrue([cls instancesRespondToSelector:@selector(gaugeWithKey:value:unit:)]);
}

- (void)testGaugeKeyValue_selectorShouldExist
{
    // -- Arrange --
    Class cls = NSClassFromString(@"SentryObjCMetricsApi");

    // -- Assert --
    XCTAssertTrue([cls instancesRespondToSelector:@selector(gaugeWithKey:value:)]);
}

@end
