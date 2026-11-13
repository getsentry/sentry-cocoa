#import "SentryTestHubWrapper.h"

#import "SentryHub+Private.h"
#import "SentrySwift.h"

@implementation SentryTestHubWrapper

- (instancetype)initWithClient:(SentryClientInternal *_Nullable)client
                      andScope:(SentryScope *_Nullable)scope
{
    return [super initWithClient:client andScope:scope];
}

- (SentryId *)captureEvent:(SENTRY_SWIFT_MIGRATION_ID(SentryEvent))untypedEvent
                  withScope:(SentryScope *)scope
    additionalEnvelopeItems:(NSArray<SentryEnvelopeItem *> *)additionalEnvelopeItems
{
    SentryEvent *event = untypedEvent;
    return [self wrapper_captureEvent:event
                            withScope:scope
              additionalEnvelopeItems:additionalEnvelopeItems];
}

- (SentryId *)wrapper_captureEvent:(SENTRY_SWIFT_MIGRATION_ID(SentryEvent))untypedEvent
                         withScope:(SentryScope *)scope
           additionalEnvelopeItems:(NSArray *)additionalEnvelopeItems
{
    SentryEvent *event = untypedEvent;
    // Return only the event ID: Swift TestHub overrides this SwiftPM-compatible bridge method
    // to record the invocation without capturing a real event.
    return event.eventId;
}

- (void)captureTransaction:(SENTRY_SWIFT_MIGRATION_ID(SentryTransaction))transaction
                 withScope:(SentryScope *)scope
{
    [self wrapper_captureTransaction:transaction withScope:scope];
    [super captureTransaction:transaction withScope:scope];
}

- (void)wrapper_captureTransaction:(id)transaction withScope:(SentryScope *)scope
{
    // Intentionally empty: Swift TestHub overrides this SwiftPM-compatible bridge method
    // to record the invocation before hub capture continues.
}

- (void)wrapper_setSession:(nullable id)session
{
    self.session = session;
}

@end
