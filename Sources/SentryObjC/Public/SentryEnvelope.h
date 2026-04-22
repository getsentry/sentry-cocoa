#import <Foundation/Foundation.h>

// SentryEnvelopeHeader and SentryEnvelopeItem are Swift-backed and use
// @compatibility_alias in their headers; importing the full headers avoids a
// "conflicting types for alias" error if they are later included in the same TU.
#import "SentryEnvelopeHeader.h"
#import "SentryEnvelopeItem.h"

NS_ASSUME_NONNULL_BEGIN

// See SentryFeedback.h for an explanation of why SentryObjC's public headers alias
// the plain class name to the Swift-mangled class exported by Sentry.framework.
#if SWIFT_PACKAGE
@class _TtC11SentrySwift14SentryEnvelope;
@compatibility_alias SentryEnvelope _TtC11SentrySwift14SentryEnvelope;
#else
@class _TtC6Sentry14SentryEnvelope;
@compatibility_alias SentryEnvelope _TtC6Sentry14SentryEnvelope;
#endif

/**
 * A Sentry envelope containing one or more items.
 */
@interface SentryEnvelope : NSObject

@property (nonatomic, readonly, strong) SentryEnvelopeHeader *header;
@property (nonatomic, readonly, copy) NSArray<SentryEnvelopeItem *> *items;

- (instancetype)initWithHeader:(SentryEnvelopeHeader *)header singleItem:(SentryEnvelopeItem *)item;

@end

NS_ASSUME_NONNULL_END
