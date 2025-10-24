#import "SentryPublicSerializer.h"
#import "SentryModels+Serializable.h"

@implementation SentryPublicSerializer

+ (NSDictionary<NSString *, id> *)serializeUser:(SentryUser *)user {
    return [user serialize];
}

+ (NSDictionary<NSString *, id> *)serializeTraceContext:(SentryTraceContext *)traceContext {
    return [traceContext serialize];
}

+ (NSDictionary<NSString *, id> *)serializeEnvelopeHeader:(SentryEnvelopeItemHeader *)header {
    return [header serialize];
}

+ (NSDictionary<NSString *, id> *)serializeEvent:(SentryEvent *)event {
    return [event serializeBaseEvent];
}

@end
