#import "SentryTraceHeader.h"
#import "SentryId.h"
#import "SentrySpanId.h"

@implementation SentryTraceHeader

@synthesize traceId = _traceId;
@synthesize spanId = _spanId;
@synthesize sampleDecision = _sampleDecision;

- (instancetype)initWithTraceId:(SentryId *)traceId spanId:(SentrySpanId *)spanId sampleDecision:(SentrySampleDecision)sampleDecision
{
    if (self = [super init]) {
        _traceId = traceId;
        _spanId = spanId;
        _sampleDecision = sampleDecision;
    }
    return self;
}

- (NSString *)value
{
    return _sampleDecision != kSentrySampleDecisionUndecided
    ? [NSString stringWithFormat:@"%@-%@-%i", _traceId.sentryIdString, _spanId.sentrySpanIdString, _sampleDecision == kSentrySampleDecisionYes ? 1 : 0 ]
    : [NSString stringWithFormat:@"%@-%@", _traceId.sentryIdString, _spanId.sentrySpanIdString ];
}

@end
