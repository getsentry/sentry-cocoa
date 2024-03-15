
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SentryReplayType) {
    kSentryReplayTypeBuffer = 0, // Replay triggered by an action
    kSentryReplayTypeSession // Full session replay
};

FOUNDATION_EXPORT NSString *const kSentryReplayTypeNameBuffer;
FOUNDATION_EXPORT NSString *const kSentryReplayTypeNameSession;

NSString *nameForSentryReplayType(SentryReplayType replayType);

NS_ASSUME_NONNULL_END
