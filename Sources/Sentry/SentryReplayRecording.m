#import "SentryReplayRecording.h"
#import "SentryDateUtil.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryReplayRecording

- (instancetype)initWithSegmentId:(NSInteger)segmentId
                             size:(NSInteger)size
                            start:(NSDate *)start
                         duration:(NSTimeInterval)duration
                       frameCount:(NSInteger)frameCount
                        frameRate:(NSInteger)frameRate
                           height:(NSInteger)height
                            width:(NSInteger)width
{
    if (self = [super init]) {
        self.segmentId = segmentId;
        self.size = size;
        self.start = start;
        self.duration = duration;
        self.frameCount = frameCount;
        self.frameRate = frameRate;
        self.height = height;
        self.width = width;
    }
    return self;
}

- (NSDictionary *)headerForReplayRecording
{
    return @{ @"segment_id" : @(self.segmentId) };
}

- (NSArray<NSDictionary<NSString *, id> *> *)serialize
{

    long timestamp = [SentryDateUtil millisecondsSince1970:self.start];

    // This format is defined by RRWeb
    // empty values are required by the format
    NSDictionary *metaInfo = @{
        @"type" : @4,
        @"timestamp" : @(timestamp),
        @"data" : @ { @"href" : @"", @"height" : @(self.height), @"width" : @(self.width) }
    };

    NSDictionary *recordingInfo = @{
        @"type" : @5,
        @"timestamp" : @(timestamp),
        @"data" : @ {
            @"tag" : @"video",
            @"payload" : @ {
                @"segmentId" : @(self.segmentId),
                @"size" : @(self.size),
                @"duration" : @(self.duration),
                @"encoding" : SentryReplayEncoding,
                @"container" : SentryReplayContainer,
                @"height" : @(self.height),
                @"width" : @(self.width),
                @"frameCount" : @(self.frameCount),
                @"frameRateType" : SentryReplayFrameRateType,
                @"frameRate" : @(self.frameRate),
                @"left" : @0,
                @"top" : @0,
            }
        }
    };

    return @[ metaInfo, recordingInfo ];
}

@end

NS_ASSUME_NONNULL_END
