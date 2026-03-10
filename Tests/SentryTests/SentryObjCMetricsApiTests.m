#import <SentryObjC/SentryObjC.h>
#import <XCTest/XCTest.h>

@interface SentryObjCMetricsApiTests : XCTestCase
@end

@implementation SentryObjCMetricsApiTests

- (void)testMetricsApiReturnsNonNil
{
    id<SentryObjCMetricsApi> metrics = [SentryObjCSDK metrics];
    XCTAssertNotNil(metrics);
}

- (void)testCountWithKeyOnly
{
    // This should not crash - just verify the API works
    [[SentryObjCSDK metrics] countWithKey:@"test.counter"];
}

- (void)testCountWithValueOnly
{
    [[SentryObjCSDK metrics] countWithKey:@"test.counter" value:5];
}

- (void)testCountWithAllParameters
{
    NSDictionary *attributes = @{
        @"screen" : [SentryObjCAttributeContent stringWithValue:@"home"],
        @"success" : [SentryObjCAttributeContent booleanWithValue:YES]
    };

    [[SentryObjCSDK metrics] countWithKey:@"button.click" value:1 attributes:attributes];
}

- (void)testDistributionWithValueOnly
{
    [[SentryObjCSDK metrics] distributionWithKey:@"response.time" value:125.5];
}

- (void)testDistributionWithUnit
{
    [[SentryObjCSDK metrics] distributionWithKey:@"response.time"
                                           value:125.5
                                            unit:SentryUnitNameMillisecond];
}

- (void)testDistributionWithAllParameters
{
    NSDictionary *attributes = @{
        @"endpoint" : [SentryObjCAttributeContent stringWithValue:@"/api/data"],
        @"cached" : [SentryObjCAttributeContent booleanWithValue:NO],
        @"status" : [SentryObjCAttributeContent integerWithValue:200]
    };

    [[SentryObjCSDK metrics] distributionWithKey:@"http.request.duration"
                                           value:187.5
                                            unit:SentryUnitNameMillisecond
                                      attributes:attributes];
}

- (void)testGaugeWithValueOnly
{
    [[SentryObjCSDK metrics] gaugeWithKey:@"queue.depth" value:42];
}

- (void)testGaugeWithUnit
{
    [[SentryObjCSDK metrics] gaugeWithKey:@"memory.usage" value:1024.0 unit:SentryUnitNameByte];
}

- (void)testGaugeWithAllParameters
{
    NSDictionary *attributes = @{
        @"queue" : [SentryObjCAttributeContent stringWithValue:@"upload"],
        @"priority" : [SentryObjCAttributeContent integerWithValue:1]
    };

    [[SentryObjCSDK metrics] gaugeWithKey:@"queue.depth"
                                    value:42
                                     unit:SentryUnitWithName(@"items")
                               attributes:attributes];
}

- (void)testGaugeWithCustomUnit
{
    [[SentryObjCSDK metrics] gaugeWithKey:@"custom.metric"
                                    value:99.9
                                     unit:SentryUnitWithName(@"custom")];
}

- (void)testAttributeTypesConversion
{
    NSDictionary *attributes = @{
        @"string" : [SentryObjCAttributeContent stringWithValue:@"value"],
        @"boolean" : [SentryObjCAttributeContent booleanWithValue:YES],
        @"integer" : [SentryObjCAttributeContent integerWithValue:123],
        @"double" : [SentryObjCAttributeContent doubleWithValue:45.67],
        @"stringArray" : [SentryObjCAttributeContent stringArrayWithValue:@[ @"a", @"b" ]],
        @"booleanArray" : [SentryObjCAttributeContent booleanArrayWithValue:@[ @YES, @NO ]],
        @"integerArray" : [SentryObjCAttributeContent integerArrayWithValue:@[ @1, @2, @3 ]],
        @"doubleArray" : [SentryObjCAttributeContent doubleArrayWithValue:@[ @1.1, @2.2 ]]
    };

    [[SentryObjCSDK metrics] countWithKey:@"test.all.types" value:1 attributes:attributes];
}

- (void)testNilAttributesHandled
{
    [[SentryObjCSDK metrics] countWithKey:@"test" value:1 attributes:nil];
    [[SentryObjCSDK metrics] distributionWithKey:@"test" value:1.0 unit:nil attributes:nil];
    [[SentryObjCSDK metrics] gaugeWithKey:@"test" value:1.0 unit:nil attributes:nil];
}

- (void)testEmptyAttributesHandled
{
    [[SentryObjCSDK metrics] countWithKey:@"test" value:1 attributes:@{ }];
    [[SentryObjCSDK metrics] distributionWithKey:@"test" value:1.0 unit:nil attributes:@{ }];
    [[SentryObjCSDK metrics] gaugeWithKey:@"test" value:1.0 unit:nil attributes:@{ }];
}

- (void)testLoggerAccess
{
    SentryLogger *logger = [SentryObjCSDK logger];
    XCTAssertNotNil(logger);
}

@end
