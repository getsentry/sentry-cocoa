#import <Foundation/Foundation.h>

@class SentryObjCId;
@class SentryObjCEnvelopeHeader;
@class SentryObjCEnvelopeItem;

NS_ASSUME_NONNULL_BEGIN

@interface SentryObjCEnvelope : NSObject

@property (nonatomic, readonly, strong) SentryObjCEnvelopeHeader *header;
@property (nonatomic, readonly, copy) NSArray<SentryObjCEnvelopeItem *> *items;

- (instancetype)initWithHeader:(SentryObjCEnvelopeHeader *)header
                         items:(NSArray<SentryObjCEnvelopeItem *> *)items;
- (instancetype)initWithHeader:(SentryObjCEnvelopeHeader *)header
                    singleItem:(SentryObjCEnvelopeItem *)item;
- (instancetype)initWithId:(nullable SentryObjCId *)eventId
                singleItem:(SentryObjCEnvelopeItem *)item;
- (instancetype)initWithId:(nullable SentryObjCId *)eventId
                     items:(NSArray<SentryObjCEnvelopeItem *> *)items;

@end

NS_ASSUME_NONNULL_END
