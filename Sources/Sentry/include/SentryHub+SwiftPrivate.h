#import "SentryHub.h"

NS_ASSUME_NONNULL_BEGIN

// Since methods here use Swift classes as arguments, they cannot be used from Swift.

@interface SentryHubInternal ()

- (void)captureReplayEvent:(id)replayEvent
           replayRecording:(id)replayRecording
                     video:(NSURL *)videoURL;

- (void)registerSessionListener:(id)listener;

- (void)unregisterSessionListener:(id)listener;

@end

NS_ASSUME_NONNULL_END
