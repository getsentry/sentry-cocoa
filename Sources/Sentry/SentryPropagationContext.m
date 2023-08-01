#import "SentryPropagationContext.h"
#import "SentryId.h"
#import "SentrySpanId.h"
#import "SentryTraceHeader.h"
#import "SentryTraceContext.h"
#import "SentrySDK+Private.h"
#import "SentryOptions+Private.h"
#import "SentryScope+Private.h"
#import "SentryHub+Private.h"
#import "SentryUser+Private.h"
#import "SentryDSN.h"

@implementation SentryPropagationContext

- (instancetype)init {
    if (self = [super init]) {
        self.traceId = [[SentryId alloc] init];
        self.spanId = [[SentrySpanId alloc] init];
    }
    return self;
}

- (SentryTraceHeader *) traceHeader {
    return [[SentryTraceHeader alloc] initWithTraceId:self.traceId
                                               spanId:self.spanId
                                              sampled:kSentrySampleDecisionNo];
}

- (SentryTraceContext *) traceContext {
    SentryOptions * options = SentrySDK.options;
    SentryScope * scope = SentrySDK.currentHub.scope;
    return [[SentryTraceContext alloc] initWithTraceId:self.traceId
                                        publicKey:options.parsedDsn.url.user
                                      releaseName:options.releaseName
                                      environment:options.environment
                                      transaction:nil
                                      userSegment:scope.userObject.segment
                                       sampleRate:nil];
}

@end
