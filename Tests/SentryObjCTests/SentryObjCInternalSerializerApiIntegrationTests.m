@import SentryObjC;
@import XCTest;

@interface SentryObjCInternalSerializerApiIntegrationTests : XCTestCase
@end

@implementation SentryObjCInternalSerializerApiIntegrationTests

- (void)setUp
{
    [super setUp];

#if TARGET_OS_VISION && TARGET_OS_SIMULATOR
    NSOperatingSystemVersion version = [[NSProcessInfo processInfo] operatingSystemVersion];
    if (version.majorVersion == 27) {
        XCTSkip(@"Full SDK start is too slow on visionOS 27 simulator");
        return;
    }
#endif

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
