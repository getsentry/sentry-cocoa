#import "SentryClient+SessionsAndCrashes.h"
#import "SentryLogC.h"
#import "SentrySwift.h"
#import "SentryTraceContext.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *const DropSessionLogMessage;

@interface SentryClientInternal ()

- (SentryTransportAdapter *)transportAdapter;

- (nullable SentryTraceContext *)getTraceStateWithEvent:(SentryEvent *)event
                                              withScope:(SentryScope *)scope
                                           currentScope:(nullable SentryScope *)currentScope;

@end

@implementation SentryClientSessionsAndCrashesLinker
@end

@implementation SentryClientInternal (SessionsAndCrashes)

- (SentryId *)captureFatalEvent:(SENTRY_SWIFT_MIGRATION_ID(SentryEvent))untypedEvent
                      withScope:(SentryScope *)scope
{
    SentryEvent *event = untypedEvent;
    SentryHint *hint = [[SentryHint alloc] init];
    return [self sendEvent:event
                     withScope:scope
        alwaysAttachStacktrace:NO
                  isFatalEvent:YES
                          hint:hint];
}

- (SentryId *)captureFatalEvent:(SENTRY_SWIFT_MIGRATION_ID(SentryEvent))untypedEvent
                    withSession:(SentrySession *)session
                      withScope:(SentryScope *)scope
{
    SentryEvent *event = untypedEvent;
    SentryHint *hint = [[SentryHint alloc] init];
    [self populateHintAttachments:hint scope:scope isFromPreviousProcess:YES];
    hint.attachments = [self processAttachmentsForEvent:event attachments:hint.attachments];
    SentryEvent *preparedEvent = [self prepareEvent:event
                                          withScope:scope
                             alwaysAttachStacktrace:NO
                                       isFatalEvent:YES
                                               hint:hint];
    return [self sendEvent:preparedEvent withSession:session withScope:scope hint:hint];
}

- (void)saveCrashTransaction:(SENTRY_SWIFT_MIGRATION_ID(SentryTransaction))transaction
                   withScope:(SentryScope *)scope
{
    SentryTransaction *typedTransaction = (SentryTransaction *)transaction;
    // Populate the hint so beforeSendTransaction sees the same attachments as for regular
    // transactions. Attachments are only informational here because storeEvent doesn't send them.
    SentryHint *hint = [[SentryHint alloc] init];
    [self populateHintAttachments:hint scope:scope isFromPreviousProcess:NO];
    SentryEvent *preparedEvent = [self prepareEvent:typedTransaction
                                          withScope:scope
                             alwaysAttachStacktrace:NO
                                       isFatalEvent:NO
                                               hint:hint];

    if (preparedEvent == nil) {
        return;
    }

    SentryTraceContext *traceContext = [self getTraceStateWithEvent:typedTransaction
                                                          withScope:scope
                                                       currentScope:nil];

    [self.transportAdapter storeEvent:preparedEvent traceContext:traceContext];
}

- (SentryId *)captureEventIncrementingSessionErrorCount:(SENTRY_SWIFT_MIGRATION_ID(
                                                            SentryEvent))untypedEvent
                                              withScope:(SentryScope *)scope
{
    SentryEvent *event = untypedEvent;
    SentryHint *hint = [[SentryHint alloc] init];
    return [self captureEventIncrementingSessionErrorCount:event withScope:scope hint:hint];
}

- (SentryId *)captureEventIncrementingSessionErrorCount:(SENTRY_SWIFT_MIGRATION_ID(
                                                            SentryEvent))untypedEvent
                                              withScope:(SentryScope *)scope
                                                   hint:(SentryHint *)hint
{
    SentryEvent *event = untypedEvent;
    [self populateHintAttachments:hint
                            scope:scope
            isFromPreviousProcess:event.isFromPreviousProcess];
    hint.attachments = [self processAttachmentsForEvent:event attachments:hint.attachments];
    SentryEvent *preparedEvent = [self prepareEvent:event
                                          withScope:scope
                             alwaysAttachStacktrace:YES
                                       isFatalEvent:NO
                                               hint:hint];

    if (preparedEvent != nil) {
        SentrySession *session = nil;
        id<SentrySessionDelegate> delegate = self.sessionDelegate;
        if (delegate != nil) {
            session = [delegate incrementSessionErrors];
        }

        return [self sendEvent:preparedEvent withSession:session withScope:scope hint:hint];
    }

    return SentryId.empty;
}

- (void)captureSession:(SentrySession *)session
{
    if (nil == session.releaseName || [session.releaseName length] == 0) {
        SENTRY_LOG_DEBUG(DropSessionLogMessage);
        return;
    }

    SentryEnvelopeItem *item = [[SentryEnvelopeItem alloc] initWithSession:session];
    SentryEnvelope *envelope = [[SentryEnvelope alloc] initWithHeader:[SentryEnvelopeHeader empty]
                                                           singleItem:item];
    [self captureEnvelope:envelope];
}

@end

NS_ASSUME_NONNULL_END
