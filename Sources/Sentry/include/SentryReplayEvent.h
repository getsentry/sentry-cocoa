#import "SentryEvent.h"
#import "SentryReplayType.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class SentryId;

@interface SentryReplayEvent : SentryEvent

/**
 * Start time of the replay segment
 */
@property (nonatomic, strong) NSDate *replayStartTimestamp;

/**
 * Number of the segment in the replay.
 * This is an incremental number
 */
@property (nonatomic) NSInteger segmentId;

/**
 * This will be used to store the name of the screens
 * that appear during the duration of the replay segment.
 */
@property (nonatomic, strong) NSArray<NSString *> *urls;

/**
 * Trace ids happening during the duration of the replay segment.
 */
@property (nonatomic, strong) NSArray<SentryId *> *traceIds;

/**
 * The type of the replay
 */
@property (nonatomic) SentryReplayType replayType;

@end

NS_ASSUME_NONNULL_END
