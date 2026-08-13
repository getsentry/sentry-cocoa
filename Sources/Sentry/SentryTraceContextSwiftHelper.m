#import "SentryTraceContextSwiftHelper.h"
#import "SentryBaggage.h"
#import "SentrySwift.h"
#import "SentryTraceContext+Private.h"

@implementation SentryTraceContextSwiftHelper

+ (SentryBaggage *)baggageWithTraceId:(NSString *)traceId
                              options:(SentryOptions *)options
                             replayId:(nullable NSString *)replayId
{
    SentryTraceContext *traceContext =
        [[SentryTraceContext alloc] initWithTraceId:[[SentryId alloc] initWithUUIDString:traceId]
                                            options:options
                                           replayId:replayId];
    return [traceContext toBaggage];
}

@end
