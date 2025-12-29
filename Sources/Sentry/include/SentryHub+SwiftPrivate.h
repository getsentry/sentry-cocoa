#import "SentryHub.h"

NS_ASSUME_NONNULL_BEGIN

// Since methods here use Swift classes as arguments, they cannot be used from Swift.
// This declaration intentionally removes the types, so they are visible for Swift.

@interface SentryHubInternal ()

// Argument types are:
// - replayEvent: SentryReplayEvent
// - replayRecording: SentryReplayRecording
- (void)captureReplayEvent:(id)replayEvent
           replayRecording:(id)replayRecording
                     video:(NSURL *)videoURL;

// Argument types are:
// - listener: id<SentrySessionListener>
- (void)registerSessionListener:(id)listener;
- (void)unregisterSessionListener:(id)listener;

@end

NS_ASSUME_NONNULL_END
