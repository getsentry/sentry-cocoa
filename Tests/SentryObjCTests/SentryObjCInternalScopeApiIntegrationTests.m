@import SentryObjC;
@import XCTest;

@interface SentryObjCInternalScopeApiIntegrationTests : XCTestCase
@end

@implementation SentryObjCInternalScopeApiIntegrationTests

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

- (void)testSerializedContexts_whenScopeContainsCustomContext_shouldReturnEventContexts
{
    // -- Arrange --
    [SentryObjCSDK configureScope:^(SentryObjCScope *scope) {
        [scope setContextValue:@ { @"value" : @"test" } forKey:@"hybrid"];
    }];

    // -- Act --
    NSDictionary<NSString *, NSDictionary<NSString *, id> *> *contexts =
        [SentryObjCSDK.internal.scope serializedContexts];

    // -- Assert --
    XCTAssertEqualObjects(contexts[@"hybrid"][@"value"], @"test");
    XCTAssertNotNil(contexts[@"trace"]);
}

@end
