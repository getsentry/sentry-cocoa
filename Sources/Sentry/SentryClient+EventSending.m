#import "SentryClient+Private.h"
#import "SentryEvent+Private.h"
#import "SentryInternalDefines.h"
#import "SentryLogC.h"
#import "SentryScope+Private.h"
#import "SentrySwift.h"
#import "SentryTraceContext.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *const DropSessionLogMessage;

@interface SentryClientInternal ()

- (SentryCurrentScopeStorage *)currentScopeStorage;
- (SentryTransportAdapter *)transportAdapter;

- (void)populateHintAttachments:(SentryHint *)hint
                          scope:(SentryScope *)scope
                   isFatalEvent:(BOOL)isFatalEvent;

- (NSArray<SentryAttachment *> *)processAttachmentsForEvent:(SentryEvent *)event
                                                attachments:
                                                    (NSArray<SentryAttachment *> *)attachments;

- (nullable SentryEvent *)prepareEvent:(nullable SentryEvent *)event
                             withScope:(SentryScope *)scope
                alwaysAttachStacktrace:(BOOL)alwaysAttachStacktrace
                          isFatalEvent:(BOOL)isFatalEvent
                                  hint:(SentryHint *)hint;

- (nullable SentryTraceContext *)getTraceStateWithEvent:(SentryEvent *)event
                                              withScope:(SentryScope *)scope
                                           currentScope:(nullable SentryScope *)currentScope;

@end

@implementation SentryClientInternal (EventSending)

- (SentryId *)sendEvent:(SentryEvent *)event
                 withScope:(SentryScope *)scope
    alwaysAttachStacktrace:(BOOL)alwaysAttachStacktrace
{
    SentryHint *hint = [[SentryHint alloc] init];
    return [self sendEvent:event
                      withScope:scope
         alwaysAttachStacktrace:alwaysAttachStacktrace
                   isFatalEvent:NO
        additionalEnvelopeItems:@[]
                           hint:hint];
}

- (SentryId *)sendEvent:(SentryEvent *)event
                 withScope:(SentryScope *)scope
    alwaysAttachStacktrace:(BOOL)alwaysAttachStacktrace
                      hint:(SentryHint *)hint
{
    return [self sendEvent:event
                      withScope:scope
         alwaysAttachStacktrace:alwaysAttachStacktrace
                   isFatalEvent:NO
        additionalEnvelopeItems:@[]
                           hint:hint];
}

- (SentryId *)sendEvent:(SentryEvent *)event
                 withScope:(SentryScope *)scope
    alwaysAttachStacktrace:(BOOL)alwaysAttachStacktrace
              isFatalEvent:(BOOL)isFatalEvent
{
    SentryHint *hint = [[SentryHint alloc] init];
    return [self sendEvent:event
                      withScope:scope
         alwaysAttachStacktrace:alwaysAttachStacktrace
                   isFatalEvent:isFatalEvent
        additionalEnvelopeItems:@[]
                           hint:hint];
}

- (SentryId *)sendEvent:(SentryEvent *)event
                 withScope:(SentryScope *)scope
    alwaysAttachStacktrace:(BOOL)alwaysAttachStacktrace
              isFatalEvent:(BOOL)isFatalEvent
                      hint:(SentryHint *)hint
{
    return [self sendEvent:event
                      withScope:scope
         alwaysAttachStacktrace:alwaysAttachStacktrace
                   isFatalEvent:isFatalEvent
        additionalEnvelopeItems:@[]
                           hint:hint];
}

- (SentryId *)sendEvent:(SentryEvent *)event
                  withScope:(SentryScope *)scope
     alwaysAttachStacktrace:(BOOL)alwaysAttachStacktrace
               isFatalEvent:(BOOL)isFatalEvent
    additionalEnvelopeItems:(NSArray<SentryEnvelopeItem *> *)additionalEnvelopeItems
{
    SentryHint *hint = [[SentryHint alloc] init];
    return [self sendEvent:event
                      withScope:scope
         alwaysAttachStacktrace:alwaysAttachStacktrace
                   isFatalEvent:isFatalEvent
        additionalEnvelopeItems:additionalEnvelopeItems
                           hint:hint];
}

- (SentryId *)sendEvent:(SentryEvent *)event
                  withScope:(SentryScope *)scope
     alwaysAttachStacktrace:(BOOL)alwaysAttachStacktrace
               isFatalEvent:(BOOL)isFatalEvent
    additionalEnvelopeItems:(NSArray<SentryEnvelopeItem *> *)additionalEnvelopeItems
                       hint:(SentryHint *)hint
{
    [self populateHintAttachments:hint scope:scope isFatalEvent:isFatalEvent];
    hint.attachments = [self processAttachmentsForEvent:event attachments:hint.attachments];
    SentryEvent *preparedEvent = [self prepareEvent:event
                                          withScope:scope
                             alwaysAttachStacktrace:alwaysAttachStacktrace
                                       isFatalEvent:isFatalEvent
                                               hint:hint];

    if (preparedEvent == nil) {
        return SentryId.empty;
    }

    SentryTraceContext *traceContext =
        [self getTraceStateWithEvent:event
                           withScope:scope
                        currentScope:isFatalEvent ? nil : [self.currentScopeStorage scope]];

    [self.transportAdapter sendEvent:preparedEvent
                        traceContext:traceContext
                         attachments:hint.attachments
             additionalEnvelopeItems:additionalEnvelopeItems];

    return preparedEvent.eventId;
}

- (SentryId *)sendEvent:(SentryEvent *)event
            withSession:(nullable SentrySession *)session
              withScope:(SentryScope *)scope
{
    SentryHint *hint = [[SentryHint alloc] init];
    [self populateHintAttachments:hint scope:scope isFatalEvent:event.isFatalEvent];
    hint.attachments = [self processAttachmentsForEvent:event attachments:hint.attachments];
    return [self sendEvent:event withSession:session withScope:scope hint:hint];
}

- (SentryId *)sendEvent:(SentryEvent *)event
            withSession:(nullable SentrySession *)session
              withScope:(SentryScope *)scope
                   hint:(SentryHint *)hint
{
    if (event == nil) {
        return SentryId.empty;
    }

    NSArray<SentryAttachment *> *attachments = hint.attachments;

    if (event.isFatalEvent && event.context[@"replay"] &&
        [event.context[@"replay"] isKindOfClass:NSDictionary.class]) {
        NSDictionary *replay = event.context[@"replay"];
        scope.replayId = replay[@"replay_id"];
    }

    SentryTraceContext *traceContext =
        [self getTraceStateWithEvent:event
                           withScope:scope
                        currentScope:event.isFatalEvent ? nil : [self.currentScopeStorage scope]];

    if (session == nil) {
        [self.transportAdapter sendEvent:event traceContext:traceContext attachments:attachments];
        return event.eventId;
    }

    SentrySession *nonnullSession = SENTRY_UNWRAP_NULLABLE(SentrySession, session);

    if (nonnullSession.releaseName == nil || [nonnullSession.releaseName length] == 0) {
        SENTRY_LOG_DEBUG(DropSessionLogMessage);

        [self.transportAdapter sendEvent:event traceContext:traceContext attachments:attachments];
        return event.eventId;
    }

    [self.transportAdapter sendEvent:event
                         withSession:nonnullSession
                        traceContext:traceContext
                         attachments:attachments];

    return event.eventId;
}

@end

NS_ASSUME_NONNULL_END
