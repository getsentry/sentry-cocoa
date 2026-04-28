#import <Foundation/Foundation.h>

@class SentryAttachment;

NS_ASSUME_NONNULL_BEGIN

/**
 * An item within a Sentry envelope.
 */
@interface SentryEnvelopeItem : NSObject

- (nullable instancetype)initWithAttachment:(SentryAttachment *)attachment
                          maxAttachmentSize:(NSUInteger)maxAttachmentSize;

@end

NS_ASSUME_NONNULL_END
