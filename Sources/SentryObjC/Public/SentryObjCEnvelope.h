#import <Foundation/Foundation.h>

@class SentryObjCId;
@class SentryObjCEnvelopeHeader;
@class SentryObjCEnvelopeItem;

NS_ASSUME_NONNULL_BEGIN

/**
 * An envelope is a transport container for one or more items, such as events, attachments,
 * or sessions. It consists of a header and a list of envelope items.
 */
@interface SentryObjCEnvelope : NSObject

/// The envelope header containing metadata such as the event ID and trace context.
@property (nonatomic, readonly, strong) SentryObjCEnvelopeHeader *header;

/// The list of items contained in this envelope.
@property (nonatomic, readonly, copy) NSArray<SentryObjCEnvelopeItem *> *items;

/**
 * Initializes an envelope with the specified header and items.
 * @param header The envelope header.
 * @param items The list of envelope items.
 */
- (instancetype)initWithHeader:(SentryObjCEnvelopeHeader *)header
                         items:(NSArray<SentryObjCEnvelopeItem *> *)items;

/**
 * Initializes an envelope with the specified header and a single item.
 * @param header The envelope header.
 * @param item The single envelope item.
 */
- (instancetype)initWithHeader:(SentryObjCEnvelopeHeader *)header
                    singleItem:(SentryObjCEnvelopeItem *)item;

/**
 * Initializes an envelope with the specified event ID and a single item.
 * A new header is created from the event ID.
 * @param eventId The identifier of the event. Can be @c nil if no event in the envelope.
 * @param item The single envelope item.
 */
- (instancetype)initWithId:(nullable SentryObjCId *)eventId
                singleItem:(SentryObjCEnvelopeItem *)item;

/**
 * Initializes an envelope with the specified event ID and items.
 * A new header is created from the event ID.
 * @param eventId The identifier of the event. Can be @c nil if no event in the envelope.
 * @param items The list of envelope items.
 */
- (instancetype)initWithId:(nullable SentryObjCId *)eventId
                     items:(NSArray<SentryObjCEnvelopeItem *> *)items;

@end

NS_ASSUME_NONNULL_END
