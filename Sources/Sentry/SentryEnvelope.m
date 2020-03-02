#if __has_include(<Sentry/Sentry.h>)
#import <Sentry/SentryEvent.h>
#import <Sentry/SentryEnvelope.h>
#else
#import "SentryEvent.h"
#import "SentryEnvelope.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@implementation SentryEnvelopeHeader

- (instancetype)initWithId:(NSString *) envelopeId {
    if (self = [super init]) {
        self->_envelopeId = envelopeId;
    }
    return self;
}

// When envelope doesn't have a SentryEvent item
- (instancetype)init {
    return [self initWithId:[[[NSUUID UUID].UUIDString stringByReplacingOccurrencesOfString:@"-" withString:@""] lowercaseString]];
}

@end

@implementation SentryEnvelopeItemHeader

- (instancetype)initWithType:(NSString *)type
                length:(NSUInteger)length {
    if (self = [super init]) {
        self->_type = type;
        self->_length = length;
    }
    return self;
}

@end

@implementation SentryEnvelopeItem

- (instancetype)initWithHeader:(SentryEnvelopeItemHeader *)header
                          data:(NSData *)data {
    if (self = [super init]) {
        self->_header = header;
        self->_data = data;
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

- (instancetype)initWithId:(NSString *)id
                singleItem:(SentryEnvelopeItem *)item {
    return [self initWithHeader:[[SentryEnvelopeHeader alloc] initWithId:id] singleItem:item];
}

- (instancetype)initWithId:(NSString *)id
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
        self->_header = header;
        self->_items = items;
    }
    return self;
}

@end

NS_ASSUME_NONNULL_END
