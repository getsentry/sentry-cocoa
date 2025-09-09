#if __has_include(<Sentry/PrivatesHeader.h>)
#    import <Sentry/PrivatesHeader.h>
#else
#    import "PrivatesHeader.h"
#endif

@class SentryAttachment;
@class SentryEnvelopeItemHeader;
@class SentryEvent;
@class SentryFeedback;
@class SentryId;
@class SentrySession;
@class SentryTraceContext;
@class SentryUserFeedback;
@class SentryEnvelopeHeader;
@class SentryEnvelopeItem;

NS_ASSUME_NONNULL_BEGIN

@interface SentryEnvelope : NSObject
SENTRY_NO_INIT

// If no event, or no data related to event, id will be null
- (instancetype)initWithId:(SentryId *_Nullable)id singleItem:(SentryEnvelopeItem *)item;

- (instancetype)initWithHeader:(SentryEnvelopeHeader *)header singleItem:(SentryEnvelopeItem *)item;

// If no event, or no data related to event, id will be null
- (instancetype)initWithId:(SentryId *_Nullable)id items:(NSArray<SentryEnvelopeItem *> *)items;

/**
 * Initializes a @c SentryEnvelope with a single session.
 * @param session to init the envelope with.
 */
- (instancetype)initWithSession:(SentrySession *)session;

/**
 * Initializes a @c SentryEnvelope with a list of sessions.
 * Can be used when an operation that starts a session closes an ongoing session.
 * @param sessions to init the envelope with.
 */
- (instancetype)initWithSessions:(NSArray<SentrySession *> *)sessions;

- (instancetype)initWithHeader:(SentryEnvelopeHeader *)header
                         items:(NSArray<SentryEnvelopeItem *> *)items NS_DESIGNATED_INITIALIZER;

/**
 * Convenience init for a single event.
 */
- (instancetype)initWithEvent:(SentryEvent *)event;

#if !SDK_V9
/**
 * @deprecated Building the envelopes for the new @c SentryFeedback type is done directly in @c
 * -[SentryClient @c captureFeedback:withScope:]
 */
- (instancetype)initWithUserFeedback:(SentryUserFeedback *)userFeedback
    DEPRECATED_MSG_ATTRIBUTE("Building the envelopes for the new SentryFeedback type is done "
                             "directly in -[SentryClient captureFeedback:withScope:].");
#endif // !SDK_V9

/**
 * The envelope header.
 */
@property (nonatomic, readonly, strong) SentryEnvelopeHeader *header;

/**
 * The envelope items.
 */
@property (nonatomic, readonly, strong) NSArray<SentryEnvelopeItem *> *items;

@end

NS_ASSUME_NONNULL_END
