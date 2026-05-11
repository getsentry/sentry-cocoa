#import <Foundation/Foundation.h>

#import "SentryEnvelopeHeader.h"
#import "SentryEnvelopeItem.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * A Sentry envelope containing one or more items.
 */
@interface SentryEnvelope : NSObject

@property (nonatomic, readonly, strong) SentryEnvelopeHeader *header;
@property (nonatomic, readonly, copy) NSArray<SentryEnvelopeItem *> *items;

- (instancetype)initWithHeader:(SentryEnvelopeHeader *)header singleItem:(SentryEnvelopeItem *)item;

@end

NS_ASSUME_NONNULL_END
