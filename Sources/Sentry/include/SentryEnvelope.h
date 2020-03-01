#import <Foundation/Foundation.h>
#if __has_include(<Sentry/Sentry.h>)
#import <Sentry/SentryEvent.h>
#else
#import "SentryEvent.h"
#endif

NS_ASSUME_NONNULL_BEGIN

@interface SentryEnvelopeHeader : NSObject

- (instancetype)initWithId:(NSString *) envelopeId NS_DESIGNATED_INITIALIZER;
- (instancetype)init;

/**
 * The envelope identifier..
 */
@property(nonatomic, readonly, copy) NSString *envelopeId;

@end

@interface SentryEnvelopeItemHeader : NSObject
    
- (instancetype)initWithType:(NSString *)type
                length:(NSUInteger)length NS_DESIGNATED_INITIALIZER;

/**
 * The type of the envelope item.
 */
@property(nonatomic, readonly, copy) NSString *type;
@property(nonatomic, readonly) NSUInteger length;

@end

@interface SentryEnvelopeItem : NSObject

- (instancetype)initWithEvent:(SentryEvent *)event;

- (instancetype)initWithHeader:(SentryEnvelopeItemHeader *)header
                data:(NSData *)data NS_DESIGNATED_INITIALIZER;

/**
 * The envelope item header.
 */
@property(nonatomic, readonly, strong) SentryEnvelopeItemHeader *header;

/**
 * The envelope payload.
 */
@property(nonatomic, readonly, strong) NSData *data;

@end

@interface SentryEnvelope : NSObject

- (instancetype)initWithId:(NSString *)id
                singleItem:(SentryEnvelopeItem *)item;

- (instancetype)initWithHeader:(SentryEnvelopeHeader *)header
                    singleItem:(SentryEnvelopeItem *)item;

- (instancetype)initWithId:(NSString *)id
                         items:(NSArray<SentryEnvelopeItem *> *)items;

- (instancetype)initWithHeader:(SentryEnvelopeHeader *)header
                         items:(NSArray<SentryEnvelopeItem *> *)items NS_DESIGNATED_INITIALIZER;

/**
 * The envelope header.
 */
@property(nonatomic, readonly, strong) SentryEnvelopeHeader *header;

/**
 * The envelope items.
 */
@property(nonatomic, readonly, strong) NSArray<SentryEnvelopeItem *> * items;

@end

NS_ASSUME_NONNULL_END
