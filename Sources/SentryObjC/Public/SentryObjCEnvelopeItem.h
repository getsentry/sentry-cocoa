#import <Foundation/Foundation.h>

@class SentryObjCEvent;

NS_ASSUME_NONNULL_BEGIN

/**
 * A single item within a @c SentryObjCEnvelope. Each item has a type, optional payload data,
 * and associated header metadata.
 */
@interface SentryObjCEnvelopeItem : NSObject

/// The envelope payload.
@property (nonatomic, readonly, strong, nullable) NSData *data;

/// The type of the envelope item (e.g. event, session, attachment).
@property (nonatomic, readonly, copy) NSString *type;

/**
 * Initializes an envelope item with the specified type, data, content type, and item count.
 * @param type The type of the envelope item.
 * @param data The payload data.
 * @param contentType The MIME content type of the data.
 * @param itemCount The number of items represented by this payload.
 */
- (instancetype)initWithType:(NSString *)type
                        data:(nullable NSData *)data
                 contentType:(NSString *)contentType
                   itemCount:(NSNumber *)itemCount;

/**
 * Initializes an envelope item with the specified type and data.
 * @param type The type of the envelope item.
 * @param data The payload data.
 * @param addPlatform If @c YES, sets the platform to "cocoa" on the item header.
 */
- (instancetype)initWithType:(NSString *)type
                        data:(nullable NSData *)data
                 addPlatform:(BOOL)addPlatform;

/**
 * Initializes an envelope item with an event.
 * @param event The event to serialize into the envelope item.
 */
- (instancetype)initWithEvent:(SentryObjCEvent *)event;

@end

NS_ASSUME_NONNULL_END
