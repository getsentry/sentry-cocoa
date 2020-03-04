#import <XCTest/XCTest.h>
#import <Sentry/Sentry.h>
#import "SentrySerialization.h"

@interface SentrySerializationTests : XCTestCase

@end

@implementation SentrySerializationTests

- (void)testSentryEnvelopeSerializesWithEvent {
    SentryEvent *event = [[SentryEvent alloc] init];

    SentryEnvelopeItem *item = [[SentryEnvelopeItem alloc] initWithEvent:event];
    SentryEnvelope *envelope = [[SentryEnvelope alloc] initWithId:event.eventId singleItem:item];

    XCTAssertEqual(event.eventId, envelope.header.eventId);
    XCTAssertEqual(1, envelope.items.count);
    XCTAssertEqualObjects(@"event", [envelope.items objectAtIndex:0].header.type);

    NSData *serializedEnvelope = [SentrySerialization dataWithEnvelope:envelope
                                                   options:0
                                                     error:nil];
    SentryEnvelope *deserializedEnvelope = [SentrySerialization envelopeWithData:serializedEnvelope];
    XCTAssertEqual(envelope.header.eventId, deserializedEnvelope.header.eventId);
}

- (void)testSentryEnvelopeWithExplicitInitMessages {
    NSString* attachment= @"{}";
    NSData* data=[attachment dataUsingEncoding:NSUTF8StringEncoding];

    SentryEnvelopeItemHeader *itemHeader = [[SentryEnvelopeItemHeader alloc] initWithType:@"attachment" length:data.length];
    SentryEnvelopeItem *item = [[SentryEnvelopeItem alloc] initWithHeader:itemHeader data:data];

    NSString *envelopeId = @"hopefully valid envelope id";
    SentryEnvelopeHeader *header = [[SentryEnvelopeHeader alloc] initWithId:envelopeId];
    SentryEnvelope *envelope = [[SentryEnvelope alloc] initWithHeader:header singleItem:item];

    XCTAssertEqual(envelopeId, envelope.header.eventId);
    XCTAssertEqual(1, envelope.items.count);
    XCTAssertEqualObjects(@"attachment", [envelope.items objectAtIndex:0].header.type);
    XCTAssertEqual(attachment.length, [envelope.items objectAtIndex:0].header.length);
    XCTAssertTrue([[envelope.items objectAtIndex:0].data isEqualToData: data]);
}

- (void)testSentryEnvelopeWithExplicitInitMessagesMultipleItems {
    NSMutableArray *items = [[NSMutableArray alloc] init];
    NSUInteger itemCount = 3;
    NSMutableString* attachment = [[NSMutableString alloc] init];
    [attachment appendString:[NSUUID UUID].UUIDString];

    for (NSUInteger i = 0; i < itemCount; i++) {
        [attachment appendString:[NSUUID UUID].UUIDString];
        NSData* data=[attachment dataUsingEncoding:NSUTF8StringEncoding];
        SentryEnvelopeItemHeader *itemHeader = [[SentryEnvelopeItemHeader alloc] initWithType:@"attachment" length:data.length];
        SentryEnvelopeItem *item = [[SentryEnvelopeItem alloc] initWithHeader:itemHeader data:data];
        [items addObject:item];
    }

    NSString *envelopeId = @"hopefully valid envelope id";
    SentryEnvelope *envelope = [[SentryEnvelope alloc] initWithId:envelopeId items:items];

    XCTAssertEqual(envelopeId, envelope.header.eventId);
    XCTAssertEqual(itemCount, envelope.items.count);

    for (NSUInteger j = 0; j < itemCount; ++j) {
        XCTAssertEqualObjects(@"attachment", [envelope.items objectAtIndex:j].header.type);
    }
}

@end
