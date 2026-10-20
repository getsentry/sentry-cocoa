#import "SentryTestHubWrapper.h"

#import "SentryEvent.h"
#import "SentryHub+Private.h"
#import "SentrySwift.h"

@implementation SentryTestHubWrapper

- (instancetype)initWithClient:(SentryClientInternal *_Nullable)client
                      andScope:(SentryScope *_Nullable)scope
{
    return [super initWithClient:client andScope:scope];
}

- (SentryId *)captureEvent:(SentryEvent *)event
                  withScope:(SentryScope *)scope
    additionalEnvelopeItems:(NSArray<SentryEnvelopeItem *> *)additionalEnvelopeItems
{
    return [self wrapper_captureEvent:event
                            withScope:scope
              additionalEnvelopeItems:additionalEnvelopeItems];
}

- (SentryId *)wrapper_captureEvent:(SentryEvent *)event
                         withScope:(SentryScope *)scope
           additionalEnvelopeItems:(NSArray *)additionalEnvelopeItems
{
    // Return only the event ID: Swift TestHub overrides this SwiftPM-compatible bridge method
    // to record the invocation without capturing a real event.
    return event.eventId;
}

- (void)wrapper_setSession:(nullable id)session
{
    self.session = session;
}

@end
