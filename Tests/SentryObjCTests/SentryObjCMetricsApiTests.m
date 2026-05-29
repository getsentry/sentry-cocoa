@import SentryObjC;
@import SentryTestUtilsDynamic;
@import XCTest;

@interface SentryObjCMetricsApiTests : XCTestCase
@property (nonatomic, strong) SentryTestMetricsApi *mock;
@property (nonatomic, strong) SentryObjCMetricsApi *sut;
@end

@implementation SentryObjCMetricsApiTests

- (void)setUp
{
    [super setUp];
    self.mock = [[SentryTestMetricsApi alloc] init];
    self.sut = [[SentryObjCMetricsApi alloc] initWithTestApi:self.mock];
}

#pragma mark - count

- (void)testCountWithKeyValueAttributes_shouldForwardAllParameters
{
    // -- Act --
    [self.sut countWithKey:@"events"
                     value:5
                attributes:@{ @"source" : [SentryObjCAttributeContent string:@"test"] }];

    // -- Assert --
    XCTAssertEqual(self.mock.countInvocations.count, 1);
    XCTAssertEqualObjects(self.mock.countInvocations.first[@"key"], @"events");
    XCTAssertEqualObjects(self.mock.countInvocations.first[@"value"], @5);
}

- (void)testCountWithKeyValue_shouldForwardWithEmptyAttributes
{
    // -- Act --
    [self.sut countWithKey:@"events" value:3];

    // -- Assert --
    XCTAssertEqual(self.mock.countInvocations.count, 1);
    XCTAssertEqualObjects(self.mock.countInvocations.first[@"key"], @"events");
    XCTAssertEqualObjects(self.mock.countInvocations.first[@"value"], @3);
}

- (void)testCountWithKey_shouldForwardWithValueOneAndEmptyAttributes
{
    // -- Act --
    [self.sut countWithKey:@"events"];

    // -- Assert --
    XCTAssertEqual(self.mock.countInvocations.count, 1);
    XCTAssertEqualObjects(self.mock.countInvocations.first[@"key"], @"events");
    XCTAssertEqualObjects(self.mock.countInvocations.first[@"value"], @1);
}

#pragma mark - distribution

- (void)testDistributionWithKeyValueUnitAttributes_shouldForwardAllParameters
{
    // -- Act --
    [self.sut distributionWithKey:@"latency"
                            value:42.5
                             unit:SentryObjCUnit.millisecond
                       attributes:@{ @"endpoint" : [SentryObjCAttributeContent string:@"/api"] }];

    // -- Assert --
    XCTAssertEqual(self.mock.distributionInvocations.count, 1);
    XCTAssertEqualObjects(self.mock.distributionInvocations.first[@"key"], @"latency");
    XCTAssertEqualObjects(self.mock.distributionInvocations.first[@"value"], @42.5);
    XCTAssertEqualObjects(self.mock.distributionInvocations.first[@"unit"], @"millisecond");
}

- (void)testDistributionWithKeyValueUnit_shouldForwardWithEmptyAttributes
{
    // -- Act --
    [self.sut distributionWithKey:@"latency" value:10.0 unit:SentryObjCUnit.second];

    // -- Assert --
    XCTAssertEqual(self.mock.distributionInvocations.count, 1);
    XCTAssertEqualObjects(self.mock.distributionInvocations.first[@"key"], @"latency");
    XCTAssertEqualObjects(self.mock.distributionInvocations.first[@"value"], @10.0);
    XCTAssertEqualObjects(self.mock.distributionInvocations.first[@"unit"], @"second");
}

- (void)testDistributionWithKeyValue_shouldForwardWithNilUnitAndEmptyAttributes
{
    // -- Act --
    [self.sut distributionWithKey:@"latency" value:5.0];

    // -- Assert --
    XCTAssertEqual(self.mock.distributionInvocations.count, 1);
    XCTAssertEqualObjects(self.mock.distributionInvocations.first[@"key"], @"latency");
    XCTAssertEqualObjects(self.mock.distributionInvocations.first[@"value"], @5.0);
    XCTAssertNil(self.mock.distributionInvocations.first[@"unit"]);
}

#pragma mark - gauge

- (void)testGaugeWithKeyValueUnitAttributes_shouldForwardAllParameters
{
    // -- Act --
    [self.sut gaugeWithKey:@"memory"
                     value:1024.0
                      unit:SentryObjCUnit.byte
                attributes:@{ @"process" : [SentryObjCAttributeContent string:@"main"] }];

    // -- Assert --
    XCTAssertEqual(self.mock.gaugeInvocations.count, 1);
    XCTAssertEqualObjects(self.mock.gaugeInvocations.first[@"key"], @"memory");
    XCTAssertEqualObjects(self.mock.gaugeInvocations.first[@"value"], @1024.0);
    XCTAssertEqualObjects(self.mock.gaugeInvocations.first[@"unit"], @"byte");
}

- (void)testGaugeWithKeyValueUnit_shouldForwardWithEmptyAttributes
{
    // -- Act --
    [self.sut gaugeWithKey:@"memory" value:512.0 unit:SentryObjCUnit.megabyte];

    // -- Assert --
    XCTAssertEqual(self.mock.gaugeInvocations.count, 1);
    XCTAssertEqualObjects(self.mock.gaugeInvocations.first[@"key"], @"memory");
    XCTAssertEqualObjects(self.mock.gaugeInvocations.first[@"value"], @512.0);
    XCTAssertEqualObjects(self.mock.gaugeInvocations.first[@"unit"], @"megabyte");
}

- (void)testGaugeWithKeyValue_shouldForwardWithNilUnitAndEmptyAttributes
{
    // -- Act --
    [self.sut gaugeWithKey:@"memory" value:256.0];

    // -- Assert --
    XCTAssertEqual(self.mock.gaugeInvocations.count, 1);
    XCTAssertEqualObjects(self.mock.gaugeInvocations.first[@"key"], @"memory");
    XCTAssertEqualObjects(self.mock.gaugeInvocations.first[@"value"], @256.0);
    XCTAssertNil(self.mock.gaugeInvocations.first[@"unit"]);
}

@end
