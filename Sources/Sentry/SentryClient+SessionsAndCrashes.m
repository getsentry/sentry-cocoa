#import "SentryClient+Private.h"
#import "SentryEvent+Private.h"
#import "SentryLogC.h"
#import "SentrySwift.h"
#import "SentryTraceContext.h"
#import "SentryTransaction+Private.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *const DropSessionLogMessage;

@interface SentryClientInternal ()

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
                          isFatalEvent:(BOOL)isFatalEvent;

- (nullable SentryEvent *)prepareEvent:(nullable SentryEvent *)event
                             withScope:(SentryScope *)scope
                alwaysAttachStacktrace:(BOOL)alwaysAttachStacktrace
                          isFatalEvent:(BOOL)isFatalEvent
                                  hint:(SentryHint *)hint;

- (SentryId *)sendEvent:(SentryEvent *)event
                 withScope:(SentryScope *)scope
    alwaysAttachStacktrace:(BOOL)alwaysAttachStacktrace
              isFatalEvent:(BOOL)isFatalEvent
                      hint:(SentryHint *)hint;

- (SentryId *)sendEvent:(SentryEvent *)event
            withSession:(nullable SentrySession *)session
              withScope:(SentryScope *)scope
                   hint:(SentryHint *)hint;

- (nullable SentryTraceContext *)getTraceStateWithEvent:(SentryEvent *)event
                                              withScope:(SentryScope *)scope
                                           currentScope:(nullable SentryScope *)currentScope;

@end

@implementation SentryClientInternal (SessionsAndCrashes)

- (SentryId *)captureFatalEvent:(SentryEvent *)event withScope:(SentryScope *)scope
{
    SentryHint *hint = [[SentryHint alloc] init];
    return [self sendEvent:event
                     withScope:scope
        alwaysAttachStacktrace:NO
                  isFatalEvent:YES
                          hint:hint];
}

- (SentryId *)captureFatalEvent:(SentryEvent *)event
                    withSession:(SentrySession *)session
                      withScope:(SentryScope *)scope
{
    SentryHint *hint = [[SentryHint alloc] init];
    [self populateHintAttachments:hint scope:scope isFatalEvent:YES];
    hint.attachments = [self processAttachmentsForEvent:event attachments:hint.attachments];
    SentryEvent *preparedEvent = [self prepareEvent:event
                                          withScope:scope
                             alwaysAttachStacktrace:NO
                                       isFatalEvent:YES
                                               hint:hint];
    return [self sendEvent:preparedEvent withSession:session withScope:scope hint:hint];
}

- (void)saveCrashTransaction:(SentryTransaction *)transaction withScope:(SentryScope *)scope
{
    SentryEvent *preparedEvent = [self prepareEvent:transaction
                                          withScope:scope
                             alwaysAttachStacktrace:NO
                                       isFatalEvent:NO];

    if (preparedEvent == nil) {
        return;
    }

    SentryTraceContext *traceContext = [self getTraceStateWithEvent:transaction
                                                          withScope:scope
                                                       currentScope:nil];

    [self.transportAdapter storeEvent:preparedEvent traceContext:traceContext];
}

- (SentryId *)captureEventIncrementingSessionErrorCount:(SentryEvent *)event
                                              withScope:(SentryScope *)scope
{
    SentryHint *hint = [[SentryHint alloc] init];
    return [self captureEventIncrementingSessionErrorCount:event withScope:scope hint:hint];
}

- (SentryId *)captureEventIncrementingSessionErrorCount:(SentryEvent *)event
                                              withScope:(SentryScope *)scope
                                                   hint:(SentryHint *)hint
{
    [self populateHintAttachments:hint scope:scope isFatalEvent:NO];
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
