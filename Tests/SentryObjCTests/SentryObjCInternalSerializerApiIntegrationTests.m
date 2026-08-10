@import SentryObjC;
@import XCTest;

@interface SentryObjCInternalSerializerApiIntegrationTests : XCTestCase
@end

@implementation SentryObjCInternalSerializerApiIntegrationTests

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

- (void)testSerializeEvent_whenEventContainsData_shouldReturnWireFormat
{
    // -- Arrange --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];
    event.message = [[SentryObjCMessage alloc] initWithFormatted:@"test message"];
    event.tags = @{ @"tag" : @"value" };
    event.context = @{ @"custom" : @ { @"key" : @"value" } };

    // -- Act --
    NSDictionary<NSString *, id> *serialized =
        [SentryObjCSDK.internal.serializer serializeEvent:event];

    // -- Assert --
    XCTAssertEqualObjects(serialized[@"message"][@"formatted"], @"test message");
    XCTAssertEqualObjects(serialized[@"tags"][@"tag"], @"value");
    XCTAssertEqualObjects(serialized[@"contexts"][@"custom"][@"key"], @"value");
    XCTAssertTrue([NSJSONSerialization isValidJSONObject:serialized]);
}

@end
