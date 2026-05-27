#import "SentryObjC.h"
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
    XCTAssertEqualObjects(header.eventId.sentryIdString, eventId.sentryIdString);
}

- (void)testInitWithId_whenNilId_shouldHaveNilEventId
{
    // -- Act --
    SentryObjCEnvelopeHeader *header = [[SentryObjCEnvelopeHeader alloc] initWithId:nil];

    // -- Assert --
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
    XCTAssertEqualObjects(header.eventId.sentryIdString, eventId.sentryIdString);
    XCTAssertNil(header.traceContext);
}

- (void)testTraceContext_whenNotProvided_shouldBeNil
{
    // -- Arrange --
    SentryObjCEnvelopeHeader *header =
        [[SentryObjCEnvelopeHeader alloc] initWithId:[[SentryObjCId alloc] init]];

    // -- Assert --
    XCTAssertNil(header.traceContext);
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
    XCTAssertNil(header.eventId);
    XCTAssertNil(header.traceContext);
}

#pragma mark - SentryObjCEnvelopeItem

- (void)testItemInitWithTypeDataContentTypeItemCount_shouldSetAllProperties
{
    // -- Arrange --
    NSData *data = [@"payload" dataUsingEncoding:NSUTF8StringEncoding];

    // -- Act --
    SentryObjCEnvelopeItem *item = [[SentryObjCEnvelopeItem alloc] initWithType:@"attachment"
                                                                           data:data
                                                                    contentType:@"text/plain"
                                                                      itemCount:@1];

    // -- Assert --
    XCTAssertEqualObjects(item.type, @"attachment");
    XCTAssertEqualObjects(item.data, data);
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
    XCTAssertEqualObjects(item.type, @"event");
    XCTAssertEqualObjects(item.data, data);
}

- (void)testItemInitWithTypeDataAddPlatform_whenNilData_shouldHaveNilData
{
    // -- Act --
    SentryObjCEnvelopeItem *item = [[SentryObjCEnvelopeItem alloc] initWithType:@"attachment"
                                                                           data:nil
                                                                    addPlatform:NO];

    // -- Assert --
    XCTAssertEqualObjects(item.type, @"attachment");
    XCTAssertNil(item.data);
}

- (void)testItemInitWithEvent_shouldSetTypeToEventAndHaveData
{
    // -- Arrange --
    SentryObjCEvent *event = [[SentryObjCEvent alloc] init];

    // -- Act --
    SentryObjCEnvelopeItem *item = [[SentryObjCEnvelopeItem alloc] initWithEvent:event];

    // -- Assert --
    XCTAssertEqualObjects(item.type, @"event");
    XCTAssertGreaterThan(item.data.length, 0u);
}

#pragma mark - SentryObjCEnvelope

- (void)testEnvelopeInitWithHeaderAndItems_shouldSetHeaderAndItems
{
    // -- Arrange --
    SentryObjCId *eventId = [[SentryObjCId alloc] init];
    SentryObjCEnvelopeHeader *header = [[SentryObjCEnvelopeHeader alloc] initWithId:eventId];
    NSData *data = [@"test" dataUsingEncoding:NSUTF8StringEncoding];
    SentryObjCEnvelopeItem *item = [[SentryObjCEnvelopeItem alloc] initWithType:@"attachment"
                                                                           data:data
                                                                    addPlatform:NO];

    // -- Act --
    SentryObjCEnvelope *envelope = [[SentryObjCEnvelope alloc] initWithHeader:header
                                                                        items:@[ item ]];

    // -- Assert --
    XCTAssertEqualObjects(envelope.header.eventId.sentryIdString, eventId.sentryIdString);
    XCTAssertEqual(envelope.items.count, 1u);
    XCTAssertEqualObjects(envelope.items[0].type, @"attachment");
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
    XCTAssertEqual(envelope.items.count, 1u);
    XCTAssertEqualObjects(envelope.items[0].type, @"attachment");
    XCTAssertEqualObjects(envelope.items[0].data, data);
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
    XCTAssertEqualObjects(envelope.header.eventId.sentryIdString, eventId.sentryIdString);
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
    XCTAssertNil(envelope.header.eventId);
    XCTAssertEqual(envelope.items.count, 1u);
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
    XCTAssertEqualObjects(envelope.header.eventId.sentryIdString, eventId.sentryIdString);
    XCTAssertEqual(envelope.items.count, 2u);
    XCTAssertEqualObjects(envelope.items[0].type, @"attachment");
    XCTAssertEqualObjects(envelope.items[1].type, @"event");
}

@end
