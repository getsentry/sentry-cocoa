#import "SentryReplayEnvelopeItemHeader.h"
#import "SentryEnvelopeItemType.h"

@implementation SentryReplayEnvelopeItemHeader

- (instancetype)initWithType:(NSString *)type
                   segmentId:(NSInteger)segmentId
                      length:(NSUInteger)length
{
    if (self = [super initWithType:type length:length]) {
        self.segmentId = segmentId;
    }
    return self;
}

+ (instancetype)replayRecordingHeaderWithSegmentId:(NSInteger)segmentId length:(NSUInteger)length
{
    return [[self alloc] initWithType:SentryEnvelopeItemTypeReplayRecording
                            segmentId:segmentId
                               length:length];
}

+ (instancetype)replayVideoHeaderWithSegmentId:(NSInteger)segmentId length:(NSUInteger)length
{
    return [[self alloc] initWithType:SentryEnvelopeItemTypeReplayVideo
                            segmentId:segmentId
                               length:length];
}

- (NSDictionary *)serialize
{
    return @{ @"type" : self.type, @"length" : @(self.length), @"segment_id" : @(self.segmentId) };
}

@end
