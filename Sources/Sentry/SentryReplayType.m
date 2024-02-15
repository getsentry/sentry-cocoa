#import "SentryReplayType.h"

NSString *const kSentryReplayTypeNameBuffer = @"buffer";
NSString *const kSentryReplayTypeNameSession = @"session";

NSString *_Nonnull nameForSentryReplayType(SentryReplayType replayType)
{
    switch (replayType) {
    case kSentryReplayTypeBuffer:
        return kSentryReplayTypeNameBuffer;
    case kSentryReplayTypeSession:
        return kSentryReplayTypeNameSession;
    }
}
