#import "SentryAttachment.h"
#import "SentryClient+Private.h"
#import "SentryEvent+Private.h"
#import "SentryLogC.h"
#import "SentryScope+Private.h"
#import "SentrySwift.h"
#import "SentryTraceContext.h"

__attribute__((visibility("hidden"))) void
sentry_client_replay_and_feedback_linker_anchor(void)
{
}

NS_ASSUME_NONNULL_BEGIN

@interface SentryClientInternal ()

- (SentryCurrentScopeStorage *)currentScopeStorage;
- (SentryTransportAdapter *)transportAdapter;

- (nullable SentryEvent *)prepareEvent:(SentryEvent *)event
                             withScope:(SentryScope *)scope
                alwaysAttachStacktrace:(BOOL)alwaysAttachStacktrace;

- (nullable SentryEvent *)prepareEvent:(nullable SentryEvent *)event
                             withScope:(SentryScope *)scope
                alwaysAttachStacktrace:(BOOL)alwaysAttachStacktrace
                          isFatalEvent:(BOOL)isFatalEvent
                          currentScope:(nullable SentryScope *)currentScope;

- (nullable SentryTraceContext *)getTraceStateWithEvent:(SentryEvent *)event
                                              withScope:(SentryScope *)scope
                                           currentScope:(nullable SentryScope *)currentScope;

- (NSArray<SentryAttachment *> *)processAttachmentsForEvent:(SentryEvent *)event
                                                attachments:
                                                    (NSArray<SentryAttachment *> *)attachments;

@end

@implementation SentryClientInternal (ReplayAndFeedback)

- (void)captureReplayEvent:(SentryReplayEvent *)replayEvent
           replayRecording:(SentryReplayRecording *)replayRecording
                     video:(NSURL *)videoURL
                 withScope:(SentryScope *)scope
{
    replayEvent = (SentryReplayEvent *)[self prepareEvent:replayEvent
                                                withScope:scope
                                   alwaysAttachStacktrace:NO];

    if (replayEvent == nil) {
        SENTRY_LOG_DEBUG(@"The replay event was filtered out in prepare event. "
                         @"The replay was discarded.");
        return;
    }

    // Only check the type of the returned event, as the instance could be changed in the event
    // preprocessor and before-send handlers.
    if (![replayEvent isKindOfClass:SentryReplayEvent.class]) {
        SENTRY_LOG_ERROR(@"The event preprocessor didn't update the replay event in place. The "
                         @"replay was discarded.");
        return;
    }

    SentryEnvelopeItem *videoEnvelopeItem =
        [[SentryEnvelopeItem alloc] initWithReplayEvent:replayEvent
                                        replayRecording:replayRecording
                                                  video:videoURL];

    if (videoEnvelopeItem == nil) {
        SENTRY_LOG_ERROR(@"The Session Replay segment will not be sent to Sentry because an "
                         @"Envelope Item could not be created.");
        // Record a counted lost event in case preparing the event (e.g. encoding the event) failed.
        // This is used to determine if replay events are missing due to an error in the SDK.
        [self recordLostEvent:SentryDataCategoryReplay
                       reason:SentryDiscardReasonInsufficientData
                     quantity:1];
        return;
    }

    // Hybrid SDKs may override the sdk info for a replay Event,
    // the same SDK should be used for the envelope header.
    SentryEnvelopeHeader *envelopeHeader =
        [[SentryEnvelopeHeader alloc] initWithId:replayEvent.eventId sdkInfo:replayEvent.sdk];

    SentryEnvelope *envelope = [[SentryEnvelope alloc] initWithHeader:envelopeHeader
                                                                items:@[ videoEnvelopeItem ]];
    [self captureEnvelope:envelope];
}

- (void)captureSerializedFeedback:(NSDictionary *)serializedFeedback
                      withEventId:(NSString *)feedbackEventId
                      attachments:(NSArray<SentryAttachment *> *)feedbackAttachments
                            scope:(SentryScope *)scope
                     currentScope:(nullable SentryScope *)currentScope
{
    if ([self isDisabled]) {
        [self logDisabledMessage];
        return;
    }

    SentryEvent *feedbackEvent = [[SentryEvent alloc] init];
    feedbackEvent.eventId = [[SentryId alloc] initWithUUIDString:feedbackEventId];
    feedbackEvent.type = SentryEnvelopeItemTypes.feedback;

    NSString *replayId = serializedFeedback[@"replay_id"] ?: currentScope.replayId ?: scope.replayId;
    NSUInteger optionalItems = (scope.span == nil ? 0 : 1) + (replayId == nil ? 0 : 1);
    NSMutableDictionary *context = [NSMutableDictionary dictionaryWithCapacity:1 + optionalItems];
    NSMutableDictionary *feedbackContext = [serializedFeedback mutableCopy];
    feedbackContext[@"replay_id"] = replayId;
    context[@"feedback"] = feedbackContext;

    if (replayId != nil) {
        NSMutableDictionary *replayContext = [NSMutableDictionary dictionaryWithCapacity:1];
        replayContext[@"replay_id"] = replayId;
        context[@"replay"] = replayContext;
    }

    feedbackEvent.context = context;

    SentryEvent *preparedEvent = [self prepareEvent:feedbackEvent
                                          withScope:scope
                             alwaysAttachStacktrace:NO
                                       isFatalEvent:NO
                                       currentScope:currentScope];

    if (preparedEvent == nil) {
        return;
    }

    SentryTraceContext *traceContext = [self getTraceStateWithEvent:preparedEvent
                                                          withScope:scope
                                                       currentScope:currentScope];

    NSMutableArray<SentryAttachment *> *allAttachments = [NSMutableArray array];
    [allAttachments addObjectsFromArray:scope.attachments];
    for (SentryAttachment *attachment in currentScope.attachments) {
        if ([allAttachments indexOfObjectIdenticalTo:attachment] == NSNotFound) {
            [allAttachments addObject:attachment];
        }
    }
    NSArray<SentryAttachment *> *attachments = [[self processAttachmentsForEvent:preparedEvent
                                                                     attachments:allAttachments]
        arrayByAddingObjectsFromArray:feedbackAttachments];

    [self.transportAdapter sendEvent:preparedEvent
                        traceContext:traceContext
                         attachments:attachments
             additionalEnvelopeItems:@[]];
}

- (void)captureSerializedFeedback:(NSDictionary *)serializedFeedback
                      withEventId:(NSString *)feedbackEventId
                      attachments:(NSArray<SentryAttachment *> *)feedbackAttachments
                            scope:(SentryScope *)scope
{
    SentryScope *cs = [self.currentScopeStorage scope];
    [self captureSerializedFeedback:serializedFeedback
                        withEventId:feedbackEventId
                        attachments:feedbackAttachments
                              scope:scope
                       currentScope:cs];
}

@end

NS_ASSUME_NONNULL_END
