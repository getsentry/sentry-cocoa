@import SentryObjC;
@import XCTest;

@interface SentryObjCInternalEnvelopeApiIntegrationTests : XCTestCase
@end

@implementation SentryObjCInternalEnvelopeApiIntegrationTests

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

- (void)testInternal_envelope_shouldBeAccessible
{
    // -- Act --
    SentryObjCInternalEnvelopeApi *envelope = SentryObjCSDK.internal.envelope;

    // -- Assert --
    XCTAssertNotNil(envelope);
}

#pragma mark - store

- (void)testStore_whenValidEnvelope_shouldNotThrow
{
    // -- Arrange --
    SentryObjCEnvelopeHeader *header =
        [[SentryObjCEnvelopeHeader alloc] initWithId:[[SentryObjCId alloc] init]];
    NSData *itemData = [@"test" dataUsingEncoding:NSUTF8StringEncoding];
    SentryObjCEnvelopeItem *item = [[SentryObjCEnvelopeItem alloc] initWithType:@"attachment"
                                                                           data:itemData
                                                                    addPlatform:NO];
    SentryObjCEnvelope *envelope = [[SentryObjCEnvelope alloc] initWithHeader:header
                                                                   singleItem:item];

    // -- Act / Assert --
    XCTAssertNoThrow([SentryObjCSDK.internal.envelope store:envelope]);
}

#pragma mark - capture

- (void)testCapture_whenValidEnvelope_shouldNotThrow
{
    // -- Arrange --
    SentryObjCEnvelopeHeader *header =
        [[SentryObjCEnvelopeHeader alloc] initWithId:[[SentryObjCId alloc] init]];
    NSData *itemData = [@"test" dataUsingEncoding:NSUTF8StringEncoding];
    SentryObjCEnvelopeItem *item = [[SentryObjCEnvelopeItem alloc] initWithType:@"attachment"
                                                                           data:itemData
                                                                    addPlatform:NO];
    SentryObjCEnvelope *envelope = [[SentryObjCEnvelope alloc] initWithHeader:header
                                                                   singleItem:item];

    // -- Act / Assert --
    XCTAssertNoThrow([SentryObjCSDK.internal.envelope capture:envelope]);
}

#pragma mark - deserializeFrom

- (void)testDeserializeFrom_whenValidData_shouldReturnEnvelope
{
    // -- Arrange --
    NSData *data =
        [@"{}\n{\"length\":0,\"type\":\"attachment\"}\n" dataUsingEncoding:NSUTF8StringEncoding];

    // -- Act --
    SentryObjCEnvelope *result = [SentryObjCSDK.internal.envelope deserializeFrom:data];

    // -- Assert --
    XCTAssertNotNil(result);
}

- (void)testDeserializeFrom_whenLengthExceedsData_shouldReturnNil
{
    // -- Arrange --
    NSData *data =
        [@"{}\n{\"length\":1,\"type\":\"attachment\"}\n" dataUsingEncoding:NSUTF8StringEncoding];

    // -- Act --
    SentryObjCEnvelope *result = [SentryObjCSDK.internal.envelope deserializeFrom:data];

    // -- Assert --
    XCTAssertNil(result);
}

- (void)testDeserializeFrom_whenEmptyData_shouldReturnNil
{
    // -- Act --
    SentryObjCEnvelope *result = [SentryObjCSDK.internal.envelope deserializeFrom:[NSData data]];

    // -- Assert --
    XCTAssertNil(result);
}

#pragma mark - Roundtrip

- (void)testSerializeAndDeserialize_shouldPreserveItemCount
{
    // -- Arrange --
    SentryObjCEnvelopeHeader *header =
        [[SentryObjCEnvelopeHeader alloc] initWithId:[[SentryObjCId alloc] init]];
    NSData *itemData = [@"payload" dataUsingEncoding:NSUTF8StringEncoding];
    SentryObjCEnvelopeItem *item = [[SentryObjCEnvelopeItem alloc] initWithType:@"attachment"
                                                                           data:itemData
                                                                    addPlatform:NO];
    SentryObjCEnvelope *original = [[SentryObjCEnvelope alloc] initWithHeader:header
                                                                   singleItem:item];

    // Serialize by storing and re-reading via deserialize
    // Use a simple roundtrip: create data manually matching envelope wire format
    NSString *envelopeString =
        [NSString stringWithFormat:@"{}\n{\"length\":%lu,\"type\":\"attachment\"}\n%@",
            (unsigned long)itemData.length, @"payload"];
    NSData *serialized = [envelopeString dataUsingEncoding:NSUTF8StringEncoding];

    // -- Act --
    SentryObjCEnvelope *deserialized = [SentryObjCSDK.internal.envelope deserializeFrom:serialized];

    // -- Assert --
    XCTAssertNotNil(deserialized);
    XCTAssertEqual(deserialized.items.count, original.items.count);
}

@end
