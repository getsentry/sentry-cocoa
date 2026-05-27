@import SentryObjC;
@import XCTest;

@interface SentryObjCGeoTests : XCTestCase
@end

@implementation SentryObjCGeoTests

- (void)testInit_shouldBeNotNil
{
    // -- Arrange & Act --
    SentryObjCGeo *geo = [[SentryObjCGeo alloc] init];

    // -- Assert --
    XCTAssertNotNil(geo);
}

#pragma mark - city

- (void)testCity_whenDefault_shouldReturnNil
{
    // -- Arrange --
    SentryObjCGeo *geo = [[SentryObjCGeo alloc] init];

    // -- Act --
    NSString *result = geo.city;

    // -- Assert --
    XCTAssertNil(result);
}

- (void)testCity_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCGeo *geo = [[SentryObjCGeo alloc] init];

    // -- Act --
    geo.city = @"Vienna";

    // -- Assert --
    XCTAssertEqualObjects(geo.city, @"Vienna");
}

- (void)testCity_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCGeo *geo = [[SentryObjCGeo alloc] init];
    geo.city = @"Vienna";

    // -- Act --
    geo.city = nil;

    // -- Assert --
    XCTAssertNil(geo.city);
}

#pragma mark - countryCode

- (void)testCountryCode_whenDefault_shouldReturnNil
{
    // -- Arrange --
    SentryObjCGeo *geo = [[SentryObjCGeo alloc] init];

    // -- Act --
    NSString *result = geo.countryCode;

    // -- Assert --
    XCTAssertNil(result);
}

- (void)testCountryCode_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCGeo *geo = [[SentryObjCGeo alloc] init];

    // -- Act --
    geo.countryCode = @"AT";

    // -- Assert --
    XCTAssertEqualObjects(geo.countryCode, @"AT");
}

- (void)testCountryCode_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCGeo *geo = [[SentryObjCGeo alloc] init];
    geo.countryCode = @"AT";

    // -- Act --
    geo.countryCode = nil;

    // -- Assert --
    XCTAssertNil(geo.countryCode);
}

#pragma mark - region

- (void)testRegion_whenDefault_shouldReturnNil
{
    // -- Arrange --
    SentryObjCGeo *geo = [[SentryObjCGeo alloc] init];

    // -- Act --
    NSString *result = geo.region;

    // -- Assert --
    XCTAssertNil(result);
}

- (void)testRegion_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCGeo *geo = [[SentryObjCGeo alloc] init];

    // -- Act --
    geo.region = @"Vienna";

    // -- Assert --
    XCTAssertEqualObjects(geo.region, @"Vienna");
}

- (void)testRegion_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCGeo *geo = [[SentryObjCGeo alloc] init];
    geo.region = @"Vienna";

    // -- Act --
    geo.region = nil;

    // -- Assert --
    XCTAssertNil(geo.region);
}

@end
