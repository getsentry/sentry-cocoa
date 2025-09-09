#import "SentryEnvelope.h"
#import "SentryAttachment.h"
#import "SentryBreadcrumb.h"
#import "SentryEnvelopeAttachmentHeader.h"
#import "SentryEnvelopeItemHeader.h"
#import "SentryEvent+Serialize.h"
#import "SentryEvent.h"
#import "SentryInternalDefines.h"
#import "SentryLogC.h"
#import "SentryMessage.h"
#import "SentryMsgPackSerializer.h"
#import "SentrySerialization.h"
#import "SentrySwift.h"
#import "SentryTransaction.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryEnvelope

- (instancetype)initWithSession:(SentrySession *)session
{
    SentryEnvelopeItem *item = [[SentryEnvelopeItem alloc] initWithSession:session];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [self initWithHeader:[[SentryEnvelopeHeader alloc] initWithId:nil] singleItem:item];
#pragma clang diagnostic pop
}

- (instancetype)initWithSessions:(NSArray<SentrySession *> *)sessions
{
    NSMutableArray *envelopeItems = [[NSMutableArray alloc] initWithCapacity:sessions.count];
    for (int i = 0; i < sessions.count; ++i) {
        SentryEnvelopeItem *item =
            [[SentryEnvelopeItem alloc] initWithSession:[sessions objectAtIndex:i]];
        [envelopeItems addObject:item];
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [self initWithHeader:[[SentryEnvelopeHeader alloc] initWithId:nil] items:envelopeItems];
#pragma clang diagnostic pop
}

- (instancetype)initWithEvent:(SentryEvent *)event
{
    SentryEnvelopeItem *item = [[SentryEnvelopeItem alloc] initWithEvent:event];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [self initWithHeader:[[SentryEnvelopeHeader alloc] initWithId:event.eventId]
                     singleItem:item];
#pragma clang diagnostic pop
}

#if !SDK_V9
- (instancetype)initWithUserFeedback:(SentryUserFeedback *)userFeedback
{
    SentryEnvelopeItem *item = [[SentryEnvelopeItem alloc] initWithUserFeedback:userFeedback];

    return [self initWithHeader:[[SentryEnvelopeHeader alloc] initWithId:userFeedback.eventId]
                     singleItem:item];
}
#endif // !SDK_V9

- (instancetype)initWithId:(SentryId *_Nullable)id singleItem:(SentryEnvelopeItem *)item
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [self initWithHeader:[[SentryEnvelopeHeader alloc] initWithId:id] singleItem:item];
#pragma clang diagnostic pop
}

- (instancetype)initWithId:(SentryId *_Nullable)id items:(NSArray<SentryEnvelopeItem *> *)items
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [self initWithHeader:[[SentryEnvelopeHeader alloc] initWithId:id] items:items];
#pragma clang diagnostic pop
}

- (instancetype)initWithHeader:(SentryEnvelopeHeader *)header singleItem:(SentryEnvelopeItem *)item
{
    return [self initWithHeader:header items:@[ item ]];
}

- (instancetype)initWithHeader:(SentryEnvelopeHeader *)header
                         items:(NSArray<SentryEnvelopeItem *> *)items
{
    if (self = [super init]) {
        _header = header;
        _items = items;
    }
    return self;
}

@end

NS_ASSUME_NONNULL_END
