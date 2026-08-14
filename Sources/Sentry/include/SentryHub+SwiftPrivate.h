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

- (void)registerSessionListener:(SENTRY_SWIFT_MIGRATION_ID(id<SentrySessionListener>))listener;
- (void)unregisterSessionListener:(SENTRY_SWIFT_MIGRATION_ID(id<SentrySessionListener>))listener;

- (SentryId *)captureEvent:(SentryEvent *)event
          withCurrentScope:(SentryScope *)currentScope NS_SWIFT_NAME(capture(event:currentScope:));

- (void)captureLog:(SENTRY_SWIFT_MIGRATION_ID(SentryLog))log
    withCurrentScope:(SentryScope *)currentScope NS_SWIFT_NAME(captureLog(_:currentScope:));

- (void)captureFeedback:(SENTRY_SWIFT_MIGRATION_ID(SentryFeedback))feedback
       withCurrentScope:(SentryScope *)currentScope NS_SWIFT_NAME(captureFeedback(_:currentScope:));

@end

NS_ASSUME_NONNULL_END
