#import "SentryHub.h"

@class SentryEnvelopeItem;
@class SentryScope;

NS_ASSUME_NONNULL_BEGIN

// Since methods here use Swift classes as arguments, they cannot be used from Swift.
// This declaration intentionally removes the types, so they are visible for Swift.

@interface SentryHubInternal ()

- (void)captureReplayEvent:(SENTRY_SWIFT_MIGRATION_ID(SentryReplayEvent))replayEvent
           replayRecording:(SENTRY_SWIFT_MIGRATION_ID(SentryReplayRecording))replayRecording
                     video:(NSURL *)videoURL;

- (SentryId *)captureEvent:(SENTRY_SWIFT_MIGRATION_ID(SentryEvent))event
    NS_SWIFT_NAME(capture(event:));

- (SentryId *)captureEvent:(SENTRY_SWIFT_MIGRATION_ID(SentryEvent))event
                 withScope:(SentryScope *)scope NS_SWIFT_NAME(capture(event:scope:));

- (SentryId *)captureEvent:(SENTRY_SWIFT_MIGRATION_ID(SentryEvent))event
                 withScope:(SentryScope *)scope
                      hint:(SENTRY_SWIFT_MIGRATION_ID(SentryHint))hint
    NS_SWIFT_NAME(capture(event:scope:hint:));

- (void)captureFatalEvent:(SENTRY_SWIFT_MIGRATION_ID(SentryEvent))event
    NS_SWIFT_NAME(captureFatalEvent(_:));

- (void)captureFatalEvent:(SENTRY_SWIFT_MIGRATION_ID(SentryEvent))event
                withScope:(SentryScope *)scope NS_SWIFT_NAME(captureFatalEvent(_:with:));

- (SentryId *)captureFatalEventWithResult:(SENTRY_SWIFT_MIGRATION_ID(SentryEvent))event
                                withScope:(SentryScope *)scope
          preserveCrashedSessionOnFailure:(BOOL)preserveCrashedSessionOnFailure
    NS_SWIFT_NAME(captureFatalEvent(_:scope:preserveCrashedSessionOnFailure:));

#if SENTRY_HAS_UIKIT && !SDK_V10
- (void)captureFatalAppHangEvent:(SENTRY_SWIFT_MIGRATION_ID(SentryEvent))event
    NS_SWIFT_NAME(captureFatalAppHang(_:));
#endif // SENTRY_HAS_UIKIT && !SDK_V10

- (SentryId *)captureEvent:(SENTRY_SWIFT_MIGRATION_ID(SentryEvent))event
                  withScope:(SentryScope *)scope
    additionalEnvelopeItems:(NSArray<SentryEnvelopeItem *> *)additionalEnvelopeItems
    NS_SWIFT_NAME(capture(event:scope:additionalEnvelopeItems:));

- (SentryId *)captureErrorEvent:(SENTRY_SWIFT_MIGRATION_ID(SentryEvent))event
    NS_SWIFT_NAME(captureErrorEvent(event:));

- (SentryId *)captureErrorEvent:(SENTRY_SWIFT_MIGRATION_ID(SentryEvent))event
                       withHint:(SENTRY_SWIFT_MIGRATION_ID(SentryHint)_Nullable)hint
    NS_SWIFT_NAME(captureErrorEvent(_:withHint:));

- (void)storeEnvelope:(SENTRY_SWIFT_MIGRATION_ID(SentryEnvelope))envelope NS_SWIFT_NAME(store(_:));
- (void)captureEnvelope:(SENTRY_SWIFT_MIGRATION_ID(SentryEnvelope))envelope
    NS_SWIFT_NAME(capture(_:));
- (void)captureNonTerminatingEnvelope:(SENTRY_SWIFT_MIGRATION_ID(SentryEnvelope))envelope
    NS_SWIFT_NAME(captureNonTerminating(_:));
- (nullable SENTRY_SWIFT_MIGRATION_ID(SentrySession))updateSessionForDroppedEventNonTerminating:
    (BOOL)unhandled NS_SWIFT_NAME(updateSessionForDroppedEventNonTerminating(unhandled:));

- (void)registerSessionListener:(SENTRY_SWIFT_MIGRATION_ID(id<SentrySessionListener>))listener;
- (void)unregisterSessionListener:(SENTRY_SWIFT_MIGRATION_ID(id<SentrySessionListener>))listener;

@end

NS_ASSUME_NONNULL_END
