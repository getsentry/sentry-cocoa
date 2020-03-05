#import <XCTest/XCTest.h>
#import <Sentry/Sentry.h>
#import "SentrySerialization.h"

@interface SentrySerializationTests : XCTestCase

@end

@implementation SentrySerializationTests

- (void)testSentryEnvelopeSerializesWithSingleEvent {
    // Arrange
    SentryEvent *event = [[SentryEvent alloc] init];

    SentryEnvelopeItem *item = [[SentryEnvelopeItem alloc] initWithEvent:event];
    SentryEnvelope *envelope = [[SentryEnvelope alloc] initWithId:event.eventId singleItem:item];
    // Sanity check
    XCTAssertEqual(event.eventId, envelope.header.eventId);
    XCTAssertEqual(1, envelope.items.count);
    XCTAssertEqualObjects(@"event", [envelope.items objectAtIndex:0].header.type);

    // Act
    NSData *serializedEnvelope = [SentrySerialization dataWithEnvelope:envelope
                                                   options:0
                                                     error:nil];
    SentryEnvelope *deserializedEnvelope = [SentrySerialization envelopeWithData:serializedEnvelope];

    // Assert
    XCTAssertEqualObjects(envelope.header.eventId, deserializedEnvelope.header.eventId);
    XCTAssertEqual(1, (int)envelope.items.count);
    XCTAssertEqualObjects(@"event", [envelope.items objectAtIndex:0].header.type);
    XCTAssertEqual([envelope.items objectAtIndex:0].header.length,
                          [deserializedEnvelope.items objectAtIndex:0].header.length);
    XCTAssertTrue([[envelope.items objectAtIndex:0].data isEqualToData:
                   [deserializedEnvelope.items objectAtIndex:0].data]);
}

- (void)testSentryEnvelopeSerializesWithManyItems {
    // Arrange
    int itemsCount = 15;
    NSMutableArray<SentryEnvelopeItem *> *items = [NSMutableArray new];
    for (int i = 0; i < itemsCount; i++) {
        NSString *bodyChar = [NSString stringWithFormat:@"%d", i];
        NSString *bodyString = [bodyChar stringByPaddingToLength:i + 1 withString: bodyChar startingAtIndex:0];

        NSData *itemData = [bodyString dataUsingEncoding:NSUTF8StringEncoding];
        SentryEnvelopeItemHeader *itemHeader = [[SentryEnvelopeItemHeader alloc] initWithType:bodyChar length:itemData.length];
        SentryEnvelopeItem *item = [[SentryEnvelopeItem alloc] initWithHeader:itemHeader data:itemData];
        [items addObject:item];
    }

    SentryEnvelope *envelope = [[SentryEnvelope alloc] initWithId:nil items:items];
    // Sanity check
    XCTAssertNil(envelope.header.eventId);
    XCTAssertEqual(itemsCount, (int)envelope.items.count);

    // Act
    NSData *serializedEnvelope = [SentrySerialization dataWithEnvelope:envelope
                                                   options:0
                                                     error:nil];
    SentryEnvelope *deserializedEnvelope = [SentrySerialization envelopeWithData:serializedEnvelope];

    // Assert
    XCTAssertNil(deserializedEnvelope.header.eventId);
    XCTAssertEqual(itemsCount, (int)deserializedEnvelope.items.count);
    for (int j = 0; j < itemsCount; ++j) {
        NSString *type = [NSString stringWithFormat:@"%d", j];

        XCTAssertEqualObjects(type, [envelope.items objectAtIndex:j].header.type);
        XCTAssertEqual([envelope.items objectAtIndex:j].header.length,
                [deserializedEnvelope.items objectAtIndex:j].header.length);
        XCTAssertTrue([[envelope.items objectAtIndex:j].data isEqualToData:
                [deserializedEnvelope.items objectAtIndex:j].data]);
    }
}

- (void)testSentryEnvelopeSerializesWithZeroByteItem {
    // Arrange
    NSData *itemData = [[NSData alloc] initWithBytes:nil length:0];
    SentryEnvelopeItemHeader *itemHeader = [[SentryEnvelopeItemHeader alloc] initWithType:@"attachment" length:itemData.length];
    
    SentryEnvelopeItem *item = [[SentryEnvelopeItem alloc] initWithHeader:itemHeader data:itemData];
    SentryEnvelope *envelope = [[SentryEnvelope alloc] initWithId:nil singleItem:item];
    
    // Sanity check
    XCTAssertEqual(1, envelope.items.count);
    XCTAssertEqualObjects(@"attachment", [envelope.items objectAtIndex:0].header.type);
    XCTAssertEqual(0, (int)([envelope.items objectAtIndex:0].header.length));

    // Act
    NSData *serializedEnvelope = [SentrySerialization dataWithEnvelope:envelope
                                                   options:0
                                                     error:nil];
    SentryEnvelope *deserializedEnvelope = [SentrySerialization envelopeWithData:serializedEnvelope];

    // Assert
    XCTAssertEqual(1, deserializedEnvelope.items.count);
    XCTAssertEqualObjects(@"attachment", [deserializedEnvelope.items objectAtIndex:0].header.type);
    XCTAssertEqual(0, (int)([deserializedEnvelope.items objectAtIndex:0].header.length));
    XCTAssertEqual(0, (int)([deserializedEnvelope.items objectAtIndex:0].data.length));
}

- (void)testSentryEnvelopeSerializerZeroByteItemReturnsEnvelope {
    NSData *itemData = [@"{}\n{\"length\":0,\"type\":\"attachment\"}\n" dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertNotNil([SentrySerialization envelopeWithData:itemData]);
}

- (void)testSentryEnvelopeSerializerItemWithoutTypeReturnsNil {
    NSData *itemData = [@"{}\n{\"length\":0}" dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertNil([SentrySerialization envelopeWithData:itemData]);
}

- (void)testSentryEnvelopeSerializerWithoutItemReturnsNill {
    NSData *itemData = [@"{}\n" dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertNil([SentrySerialization envelopeWithData:itemData]);
}

- (void)testSentryEnvelopeSerializerWithoutLineBreak {
    NSData *itemData = [@"{}" dataUsingEncoding:NSUTF8StringEncoding];
    XCTAssertNil([SentrySerialization envelopeWithData:itemData]);
}

- (void)testSentryEnvelopeSerializerWithNilInput {
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wnonnull"
    XCTAssertNil([SentrySerialization envelopeWithData:nil]);
    #pragma clang diagnostic pop
}

@end
