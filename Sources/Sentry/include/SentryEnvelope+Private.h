#import "SentryEnvelope.h"

NS_ASSUME_NONNULL_BEGIN

@class SentryReplayEvent;
@class SentryReplayRecording;
@class SentryClientReport;

@interface SentryEnvelopeItem ()

- (instancetype)initWithClientReport:(SentryClientReport *)clientReport;

- (nullable instancetype)initWithReplayEvent:(SentryReplayEvent *)replayEvent
                             replayRecording:(SentryReplayRecording *)replayRecording
                                       video:(NSURL *)videoURL;

- (instancetype)initWithHeader:(SentryEnvelopeItemHeader *)header
                          data:(NSData *)data;

@end

@interface SentryEnvelope ()

- (instancetype)initWithId:(SentryId *_Nullable)id singleItem:(SentryEnvelopeItem *)item;

@end

NS_ASSUME_NONNULL_END
