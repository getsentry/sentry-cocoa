#import "SentryEnvelope.h"

NS_ASSUME_NONNULL_BEGIN

@class SentryReplayEvent, SentryReplayRecording;

@interface
SentryEnvelopeItem ()

- (instancetype)initWithClientReport:(SentryClientReport *)clientReport;

- (instancetype)initWithReplayEvent:(SentryReplayEvent *)replayEvent
                    replayRecording:(SentryReplayRecording *)replayRecording
                              video:(NSURL *)videoURL;

@end

NS_ASSUME_NONNULL_END
