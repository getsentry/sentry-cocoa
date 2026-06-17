@import SentryObjC;
@import XCTest;

@interface SentryObjCInternalUserApiIntegrationTests : XCTestCase
@end

@implementation SentryObjCInternalUserApiIntegrationTests

- (void)setUp
{
    [super setUp];
    [SentryObjCSDK startWithConfigureOptions:^(SentryObjCOptions *options) {
        options.dsn = @"https://key@sentry.io/123";
        options.enableCrashHandler = NO;
    }];
}

- (void)tearDown
{
    [SentryObjCSDK close];
    [super tearDown];
}

#pragma mark - Accessor

- (void)testInternal_user_shouldBeAccessible
{
    // -- Act --
    SentryObjCInternalUserApi *user = SentryObjCSDK.internal.user;

    // -- Assert --
    XCTAssertNotNil(user);
}

#pragma mark - fromDictionary

- (void)testFromDictionary_whenPopulated_shouldMapFields
{
    // -- Arrange --
    NSDictionary *dict = @{
        @"id" : @"user123",
        @"email" : @"test@example.com",
        @"username" : @"testuser",
        @"ip_address" : @"127.0.0.1"
    };

    // -- Act --
    SentryObjCUser *user = [SentryObjCSDK.internal.user fromDictionary:dict];

    // -- Assert --
    XCTAssertEqualObjects(user.userId, @"user123");
    XCTAssertEqualObjects(user.email, @"test@example.com");
    XCTAssertEqualObjects(user.username, @"testuser");
    XCTAssertEqualObjects(user.ipAddress, @"127.0.0.1");
}

- (void)testFromDictionary_whenEmpty_shouldReturnUser
{
    // -- Act --
    SentryObjCUser *user = [SentryObjCSDK.internal.user fromDictionary:@{ }];

    // -- Assert --
    XCTAssertNotNil(user);
}

@end
