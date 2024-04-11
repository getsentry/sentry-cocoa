#import "SentryReplayEvent.h"
#import "SentryDateUtil.h"
#import "SentryEnvelopeItemType.h"
#import "SentrySwift.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryReplayEvent

- (instancetype)init
{
    if (self = [super init]) {
        self.type = SentryEnvelopeItemTypeReplayVideo;
    }
    return self;
}

- (NSDictionary *)serialize
{
    NSMutableDictionary *result = [[super serialize] mutableCopy];

    NSMutableArray *trace_ids = [[NSMutableArray alloc] initWithCapacity:self.traceIds.count];

    for (SentryId *traceId in self.traceIds) {
        [trace_ids addObject:traceId.sentryIdString];
    }

    result[@"urls"] = self.urls;
    result[@"replay_start_timestamp"] = @(self.replayStartTimestamp.timeIntervalSince1970);
    result[@"trace_ids"] = trace_ids;
    result[@"replay_id"] = self.eventId.sentryIdString;
    result[@"segment_id"] = @(self.segmentId);
    result[@"replay_type"] = nameForSentryReplayType(self.replayType);
    result[@"error_ids"] = @[];

    return result;
}

@end

NS_ASSUME_NONNULL_END
