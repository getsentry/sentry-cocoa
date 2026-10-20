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

- (void)testSerializeScope_whenScopeContainsData_shouldReturnWireFormat
{
    // -- Arrange --
    SentryObjCScope *scope = [[SentryObjCScope alloc] init];
    [scope setTagValue:@"value" forKey:@"tag"];
    [scope setContextValue:@{ @"key" : @"value" } forKey:@"custom"];

    // -- Act --
    NSDictionary<NSString *, id> *serialized =
        [SentryObjCSDK.internal.serializer serializeScope:scope];

    // -- Assert --
    XCTAssertEqualObjects(serialized[@"tags"][@"tag"], @"value");
    XCTAssertEqualObjects(serialized[@"context"][@"custom"][@"key"], @"value");
    XCTAssertTrue([NSJSONSerialization isValidJSONObject:serialized]);
}

- (void)testSerializeDebugMeta_whenDebugMetaContainsData_shouldReturnWireFormat
{
    // -- Arrange --
    SentryObjCDebugMeta *debugMeta = [[SentryObjCDebugMeta alloc] init];
    debugMeta.debugID = @"debug-id";
    debugMeta.type = @"macho";
    debugMeta.imageAddress = @"0x1000";

    // -- Act --
    NSDictionary<NSString *, id> *serialized =
        [SentryObjCSDK.internal.serializer serializeDebugMeta:debugMeta];

    // -- Assert --
    XCTAssertEqualObjects(serialized[@"debug_id"], @"debug-id");
    XCTAssertEqualObjects(serialized[@"type"], @"macho");
    XCTAssertEqualObjects(serialized[@"image_addr"], @"0x1000");
    XCTAssertTrue([NSJSONSerialization isValidJSONObject:serialized]);
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
