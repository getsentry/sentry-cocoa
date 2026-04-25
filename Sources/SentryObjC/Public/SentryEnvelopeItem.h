#import <Foundation/Foundation.h>

@class SentryAttachment;

NS_ASSUME_NONNULL_BEGIN

// See SentryFeedback.h for an explanation of why SentryObjC's public headers alias
// the plain class name to the Swift-mangled class exported by Sentry.framework.
#if SWIFT_PACKAGE
@class _TtC11SentrySwift18SentryEnvelopeItem;
@compatibility_alias SentryEnvelopeItem _TtC11SentrySwift18SentryEnvelopeItem;
#else
@class _TtC6Sentry18SentryEnvelopeItem;
@compatibility_alias SentryEnvelopeItem _TtC6Sentry18SentryEnvelopeItem;
#endif

/**
 * An item within a Sentry envelope.
 */
@interface SentryEnvelopeItem : NSObject

- (nullable instancetype)initWithAttachment:(SentryAttachment *)attachment
                          maxAttachmentSize:(NSUInteger)maxAttachmentSize;

@end

NS_ASSUME_NONNULL_END
