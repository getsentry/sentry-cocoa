#import "SentryPropagationContext.h"
#import "SentryScope+PropagationContext.h"
#import "SentryScope+Private.h"

@implementation SentryScope (PropagationContext)

- (SentryId *)propagationContextTraceId
{
    return self.propagationContext.traceId;
}

@end 
