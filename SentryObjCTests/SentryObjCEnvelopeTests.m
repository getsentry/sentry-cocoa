@import SentryObjC;
@import XCTest;

@interface SentryObjCEnvelopeTests : XCTestCase
@end

@implementation SentryObjCEnvelopeTests

#pragma mark - SentryObjCEnvelopeHeader

- (void)testInitWithId_whenValidId_shouldSetEventId
{
    // -- Arrange --
    SentryObjCId *eventId = [[SentryObjCId alloc] init];

    // -- Act --
    SentryObjCEnvelopeHeader *header = [[SentryObjCEnvelopeHeader alloc] initWithId:eventId];

    // -- Assert --
    XCTAssertNotNil(header);
    XCTAssertNotNil(header.eventId);
}

- (void)testInitWithId_whenNilId_shouldHaveNilEventId
{
    // -- Act --
    SentryObjCEnvelopeHeader *header = [[SentryObjCEnvelopeHeader alloc] initWithId:nil];

    // -- Assert --
    XCTAssertNotNil(header);
    XCTAssertNil(header.eventId);
}

- (void)testInitWithIdAndTraceContext_whenNilTraceContext_shouldHaveNilTraceContext
{
    // -- Arrange --
    SentryObjCId *eventId = [[SentryObjCId alloc] init];

    // -- Act --
    SentryObjCEnvelopeHeader *header = [[SentryObjCEnvelopeHeader alloc] initWithId:eventId
                                                                       traceContext:nil];

    // -- Assert --
    XCTAssertNotNil(header);
    XCTAssertNotNil(header.eventId);
    XCTAssertNil(header.traceContext);
}

- (void)testTraceContext_whenNotProvided_shouldBeAccessible
{
    // -- Arrange --
    SentryObjCId *eventId = [[SentryObjCId alloc] init];
    SentryObjCEnvelopeHeader *header = [[SentryObjCEnvelopeHeader alloc] initWithId:eventId];

    // -- Act --
    id traceContext = header.traceContext;

    // -- Assert --
    (void)traceContext; // readonly nullable property; verify it compiles
}

- (void)testSentAt_whenSet_shouldReturnNewValue
{
    // -- Arrange --
    SentryObjCEnvelopeHeader *header =
        [[SentryObjCEnvelopeHeader alloc] initWithId:[[SentryObjCId alloc] init]];
    NSDate *now = [NSDate date];

    // -- Act --
    header.sentAt = now;

    // -- Assert --
    XCTAssertEqualObjects(header.sentAt, now);
}

- (void)testSentAt_whenDefault_shouldBeNil
{
    // -- Arrange --
    SentryObjCEnvelopeHeader *header =
        [[SentryObjCEnvelopeHeader alloc] initWithId:[[SentryObjCId alloc] init]];

    // -- Assert --
    XCTAssertNil(header.sentAt);
}

- (void)testSentAt_whenSetToNil_shouldReturnNil
{
    // -- Arrange --
    SentryObjCEnvelopeHeader *header =
        [[SentryObjCEnvelopeHeader alloc] initWithId:[[SentryObjCId alloc] init]];
    header.sentAt = [NSDate date];

    // -- Act --
    header.sentAt = nil;

    // -- Assert --
    XCTAssertNil(header.sentAt);
}

- (void)testEmpty_shouldReturnHeaderWithNilEventIdAndTraceContext
{
    // -- Act --
    SentryObjCEnvelopeHeader *header = [SentryObjCEnvelopeHeader empty];

    // -- Assert --
    XCTAssertNotNil(header);
    XCTAssertNil(header.eventId);
    XCTAssertNil(header.traceContext);
}

#pragma mark - SentryObjCEnvelopeItem

- (void)testItemInitWithTypeDataContentTypeItemCount_shouldSetTypeAndData
{
    // -- Arrange --
    NSData *data = [@"payload" dataUsingEncoding:NSUTF8StringEncoding];

    // -- Act --
    SentryObjCEnvelopeItem *item = [[SentryObjCEnvelopeItem alloc] initWithType:@"attachment"
                                                                           data:data
                                                                    contentType:@"text/plain"
                                                                      itemCount:@1];

    // -- Assert --
    XCTAssertNotNil(item);
    XCTAssertEqualObjects(item.type, @"attachment");
    XCTAssertNotNil(item.data);
}

- (void)testItemInitWithTypeDataAddPlatform_shouldSetTypeAndData
{
    // -- Arrange --
    NSData *data = [@"payload" dataUsingEncoding:NSUTF8StringEncoding];

    // -- Act --
    SentryObjCEnvelopeItem *item = [[SentryObjCEnvelopeItem alloc] initWithType:@"event"
                                                                           data:data
                                                                    addPlatform:YES];

    // -- Assert --
    XCTAssertNotNil(item);
    XCTAssertEqualObjects(item.type, @"event");
    XCTAssertNotNil(item.data);
}

- (void)testItemInitWithTypeDataAddPlatform_whenNilData_shouldHaveNilData
{
    // -- Act --
    SentryObjCEnvelopeItem *item = [[SentryObjCEnvelopeItem alloc] initWithType:@"attachment"
                                                                           data:nil
                                                                    addPlatform:NO];

    // -- Assert --
    XCTAssertNotNil(item);
    XCTAssertNil(item.data);
}

- (void)testItemInitWithEvent_shouldSetTypeToEventAndHaveData
{
    // -- Arrange --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];

    // -- Act --
    SentryObjCEnvelopeItem *item = [[SentryObjCEnvelopeItem alloc] initWithEvent:event];

    // -- Assert --
    XCTAssertNotNil(item);
    XCTAssertEqualObjects(item.type, @"event");
    XCTAssertNotNil(item.data);
}

#pragma mark - SentryObjCEnvelope

- (void)testEnvelopeInitWithHeaderAndItems_shouldSetHeaderAndItems
{
    // -- Arrange --
    SentryObjCEnvelopeHeader *header = [[SentryObjCEnvelopeHeader alloc] initWithId:nil];
    NSData *data = [@"test" dataUsingEncoding:NSUTF8StringEncoding];
    SentryObjCEnvelopeItem *item = [[SentryObjCEnvelopeItem alloc] initWithType:@"attachment"
                                                                           data:data
                                                                    addPlatform:NO];

    // -- Act --
    SentryObjCEnvelope *envelope = [[SentryObjCEnvelope alloc] initWithHeader:header
                                                                        items:@[ item ]];

    // -- Assert --
    XCTAssertNotNil(envelope);
    XCTAssertNotNil(envelope.header);
    XCTAssertEqual(envelope.items.count, 1u);
}

- (void)testEnvelopeInitWithHeaderAndSingleItem_shouldContainOneItem
{
    // -- Arrange --
    SentryObjCEnvelopeHeader *header = [[SentryObjCEnvelopeHeader alloc] initWithId:nil];
    NSData *data = [@"test" dataUsingEncoding:NSUTF8StringEncoding];
    SentryObjCEnvelopeItem *item = [[SentryObjCEnvelopeItem alloc] initWithType:@"attachment"
                                                                           data:data
                                                                    addPlatform:NO];

    // -- Act --
    SentryObjCEnvelope *envelope = [[SentryObjCEnvelope alloc] initWithHeader:header
                                                                   singleItem:item];

    // -- Assert --
    XCTAssertNotNil(envelope);
    XCTAssertEqual(envelope.items.count, 1u);
}

- (void)testEnvelopeInitWithIdAndSingleItem_whenValidId_shouldSetEventId
{
    // -- Arrange --
    SentryObjCId *eventId = [[SentryObjCId alloc] init];
    NSData *data = [@"test" dataUsingEncoding:NSUTF8StringEncoding];
    SentryObjCEnvelopeItem *item = [[SentryObjCEnvelopeItem alloc] initWithType:@"attachment"
                                                                           data:data
                                                                    addPlatform:NO];

    // -- Act --
    SentryObjCEnvelope *envelope = [[SentryObjCEnvelope alloc] initWithId:eventId singleItem:item];

    // -- Assert --
    XCTAssertNotNil(envelope);
    XCTAssertNotNil(envelope.header);
    XCTAssertNotNil(envelope.header.eventId);
    XCTAssertEqual(envelope.items.count, 1u);
}

- (void)testEnvelopeInitWithIdAndSingleItem_whenNilId_shouldHaveNilEventId
{
    // -- Arrange --
    NSData *data = [@"test" dataUsingEncoding:NSUTF8StringEncoding];
    SentryObjCEnvelopeItem *item = [[SentryObjCEnvelopeItem alloc] initWithType:@"attachment"
                                                                           data:data
                                                                    addPlatform:NO];

    // -- Act --
    SentryObjCEnvelope *envelope = [[SentryObjCEnvelope alloc] initWithId:nil singleItem:item];

    // -- Assert --
    XCTAssertNotNil(envelope);
    XCTAssertNil(envelope.header.eventId);
}

- (void)testEnvelopeInitWithIdAndItems_shouldSetEventIdAndContainAllItems
{
    // -- Arrange --
    SentryObjCId *eventId = [[SentryObjCId alloc] init];
    NSData *data = [@"test" dataUsingEncoding:NSUTF8StringEncoding];
    SentryObjCEnvelopeItem *item1 = [[SentryObjCEnvelopeItem alloc] initWithType:@"attachment"
                                                                            data:data
                                                                     addPlatform:NO];
    SentryObjCEnvelopeItem *item2 = [[SentryObjCEnvelopeItem alloc] initWithType:@"event"
                                                                            data:data
                                                                     addPlatform:YES];

    // -- Act --
    SentryObjCEnvelope *envelope = [[SentryObjCEnvelope alloc] initWithId:eventId
                                                                    items:@[ item1, item2 ]];

    // -- Assert --
    XCTAssertNotNil(envelope);
    XCTAssertNotNil(envelope.header.eventId);
    XCTAssertEqual(envelope.items.count, 2u);
}

@end
