#import "SentryObjC.h"
@import XCTest;

@interface SentryObjCUserTests : XCTestCase
@end

@implementation SentryObjCUserTests

- (void)testInit_whenDefault_shouldCreateInstance
{
    // -- Arrange & Act --
    SentryObjCUser *user = [[SentryObjCUser alloc] init];

    // -- Assert --
    XCTAssertNotNil(user);
}

- (void)testInitWithUserId_whenProvided_shouldSetUserId
{
    // -- Arrange --
    NSString *userId = @"user-123";

    // -- Act --
    SentryObjCUser *user = [[SentryObjCUser alloc] initWithUserId:userId];

    // -- Assert --
    XCTAssertNotNil(user);
    XCTAssertEqualObjects(user.userId, @"user-123");
}

- (void)testUserId_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCUser *user = [[SentryObjCUser alloc] init];

    // -- Act --
    user.userId = @"abc";

    // -- Assert --
    XCTAssertEqualObjects(user.userId, @"abc");
}

- (void)testUserId_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCUser *user = [[SentryObjCUser alloc] init];
    user.userId = @"abc";

    // -- Act --
    user.userId = nil;

    // -- Assert --
    XCTAssertNil(user.userId);
}

- (void)testEmail_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCUser *user = [[SentryObjCUser alloc] init];

    // -- Act --
    user.email = @"test@example.com";

    // -- Assert --
    XCTAssertEqualObjects(user.email, @"test@example.com");
}

- (void)testEmail_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCUser *user = [[SentryObjCUser alloc] init];
    user.email = @"test@example.com";

    // -- Act --
    user.email = nil;

    // -- Assert --
    XCTAssertNil(user.email);
}

- (void)testUsername_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCUser *user = [[SentryObjCUser alloc] init];

    // -- Act --
    user.username = @"johndoe";

    // -- Assert --
    XCTAssertEqualObjects(user.username, @"johndoe");
}

- (void)testUsername_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCUser *user = [[SentryObjCUser alloc] init];
    user.username = @"johndoe";

    // -- Act --
    user.username = nil;

    // -- Assert --
    XCTAssertNil(user.username);
}

- (void)testIpAddress_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCUser *user = [[SentryObjCUser alloc] init];

    // -- Act --
    user.ipAddress = @"127.0.0.1";

    // -- Assert --
    XCTAssertEqualObjects(user.ipAddress, @"127.0.0.1");
}

- (void)testIpAddress_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCUser *user = [[SentryObjCUser alloc] init];
    user.ipAddress = @"127.0.0.1";

    // -- Act --
    user.ipAddress = nil;

    // -- Assert --
    XCTAssertNil(user.ipAddress);
}

- (void)testName_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCUser *user = [[SentryObjCUser alloc] init];

    // -- Act --
    user.name = @"John Doe";

    // -- Assert --
    XCTAssertEqualObjects(user.name, @"John Doe");
}

- (void)testName_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCUser *user = [[SentryObjCUser alloc] init];
    user.name = @"John Doe";

    // -- Act --
    user.name = nil;

    // -- Assert --
    XCTAssertNil(user.name);
}

- (void)testGeo_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCUser *user = [[SentryObjCUser alloc] init];
    SentryObjCGeo *geo = [[SentryObjCGeo alloc] init];
    geo.city = @"Vienna";
    geo.countryCode = @"AT";
    geo.region = @"Vienna";

    // -- Act --
    user.geo = geo;

    // -- Assert --
    XCTAssertNotNil(user.geo);
    XCTAssertEqualObjects(user.geo.city, @"Vienna");
}

- (void)testGeo_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCUser *user = [[SentryObjCUser alloc] init];
    SentryObjCGeo *geo = [[SentryObjCGeo alloc] init];
    geo.city = @"Vienna";
    user.geo = geo;

    // -- Act --
    user.geo = nil;

    // -- Assert --
    XCTAssertNil(user.geo);
}

- (void)testData_whenSet_shouldReturnValue
{
    // -- Arrange --
    SentryObjCUser *user = [[SentryObjCUser alloc] init];

    // -- Act --
    user.data = @{ @"key" : @"value" };

    // -- Assert --
    XCTAssertEqualObjects(user.data[@"key"], @"value");
}

- (void)testData_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCUser *user = [[SentryObjCUser alloc] init];
    user.data = @{ @"key" : @"value" };

    // -- Act --
    user.data = nil;

    // -- Assert --
    XCTAssertNil(user.data);
}

@end
