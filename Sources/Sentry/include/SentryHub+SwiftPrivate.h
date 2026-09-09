#import "SentryHub.h"

NS_ASSUME_NONNULL_BEGIN

// Since methods here use Swift classes as arguments, they cannot be used from Swift.
// This declaration intentionally removes the types, so they are visible for Swift.

@interface SentryHubInternal ()

- (void)captureReplayEvent:(SENTRY_SWIFT_MIGRATION_ID(SentryReplayEvent))replayEvent
           replayRecording:(SENTRY_SWIFT_MIGRATION_ID(SentryReplayRecording))replayRecording
                     video:(NSURL *)videoURL;

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
