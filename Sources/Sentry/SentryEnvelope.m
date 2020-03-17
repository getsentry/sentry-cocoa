#if __has_include(<Sentry/Sentry.h>)
#import <Sentry/SentryEvent.h>
#import <Sentry/SentryEnvelope.h>
#else
#import "SentryEvent.h"
#import "SentryEnvelope.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@implementation SentryEnvelopeHeader

// id can be null if no event in the envelope or attachment related to event
- (instancetype)initWithId:(NSString *_Nullable) eventId {
    if (self = [super init]) {
        _eventId = eventId;
    }
    return self;
}

@end

@implementation SentryEnvelopeItemHeader

- (instancetype)initWithType:(NSString *)type
                length:(NSUInteger)length {
    if (self = [super init]) {
        _type = type;
        _length = length;
    }
    return self;
}

@end

@implementation SentryEnvelopeItem

- (instancetype)initWithHeader:(SentryEnvelopeItemHeader *)header
                          data:(NSData *)data {
    if (self = [super init]) {
        _header = header;
        _data = data;
    }
    return self;
}
- (instancetype)initWithEvent:(SentryEvent *)event {
    NSData *json = [NSJSONSerialization dataWithJSONObject:[event serialize]
                                                   options:0
            // TODO: handle error
                                                     error:nil];
    return [self initWithHeader:[[SentryEnvelopeItemHeader alloc] initWithType:@"event" length:json.length] data:json];
}

@end

@implementation SentryEnvelope

- (instancetype)initWithEvent:(SentryEvent *)event {
    SentryEnvelopeItem *item = [[SentryEnvelopeItem alloc] initWithEvent:event];
    return [self initWithHeader:[[SentryEnvelopeHeader alloc] initWithId:event.eventId] singleItem:item];
}

- (instancetype)initWithId:(NSString *_Nullable)id
                singleItem:(SentryEnvelopeItem *)item {
    return [self initWithHeader:[[SentryEnvelopeHeader alloc] initWithId:id] singleItem:item];
}

- (instancetype)initWithId:(NSString *_Nullable)id
                     items:(NSArray<SentryEnvelopeItem *> *)items {
    return [self initWithHeader:[[SentryEnvelopeHeader alloc] initWithId:id] items: items];
}

- (instancetype)initWithHeader:(SentryEnvelopeHeader *)header
                    singleItem:(SentryEnvelopeItem *)item {
    return [self initWithHeader:header items:@[item]];
}

- (instancetype)initWithHeader:(SentryEnvelopeHeader *)header
                         items:(NSArray<SentryEnvelopeItem *> *)items {
    if (self = [super init]) {
        _header = header;
        _items = items;
    }
    return self;
}

@end

NS_ASSUME_NONNULL_END
