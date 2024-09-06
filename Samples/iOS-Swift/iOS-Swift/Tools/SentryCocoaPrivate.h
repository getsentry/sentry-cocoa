#import <Foundation/Foundation.h>
#import <Sentry/Sentry.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryEnvelopeHeader : NSObject

- (instancetype)initWithId:(SentryId *_Nullable)eventId;

@property (nullable, nonatomic, copy) NSDate *sentAt;
@property (nullable, nonatomic, readonly, copy) SentryId *eventId;

@end

@interface SentryEnvelopeItem : NSObject

- (instancetype)initWithEvent:(SentryEvent *)event;

@property (nonatomic, readonly, strong) SentryEnvelopeItemHeader *header;
@property (nonatomic, readonly, strong) NSData *data;

@end

@interface SentryEnvelope : NSObject

@property (nonatomic, readonly, strong) SentryEnvelopeHeader *header;
@property (nonatomic, readonly, strong) NSArray<SentryEnvelopeItem *> *items;

- (instancetype)initWithId:(SentryId *_Nullable)id singleItem:(SentryEnvelopeItem *)item;
@end

NS_ASSUME_NONNULL_END
