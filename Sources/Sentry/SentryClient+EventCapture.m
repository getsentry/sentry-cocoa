#import "SentryClient+ErrorEvents.h"
#import "SentryClient+EventCapture.h"
#import "SentryEvent+Private.h"
#import "SentryMessage.h"
#import "SentrySwift.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryClientEventCaptureLinker
@end

/**
 * Whether a captured event counts as an error of the current session, like errors captured through
 * the event-capture API of the Java and Native SDKs.
 *
 * App hangs and MetricKit diagnostics from a previous process are captured through this path too,
 * but they don't describe an error of the running session, so they don't count.
 */
static BOOL
shouldIncrementSessionErrors(SentryEvent *event)
{
    if (event.isFromPreviousProcess) {
        return NO;
    }
#if !SDK_V10
    if (event.isAppHangEvent) {
        return NO;
    }
#endif // !SDK_V10

    if (event.level >= kSentryLevelError) {
        return YES;
    }
    // Events without a level default to error in Sentry.
    return event.level == kSentryLevelNone && event.exceptions.count > 0;
}

@implementation SentryClientInternal (EventCapture)

- (SentryId *)captureMessage:(NSString *)message
{
    return [self captureMessage:message withScope:[[SentryScope alloc] init]];
}

- (SentryId *)captureMessage:(NSString *)message
                   withScope:(SENTRY_SWIFT_MIGRATION_ID(SentryScope))scope
{
    return [self captureMessage:message withScope:scope hint:nil];
}

- (SentryId *)captureMessage:(NSString *)message
                   withScope:(SENTRY_SWIFT_MIGRATION_ID(SentryScope))scope
            attachAllThreads:(NSNumber *_Nullable)attachAllThreads
{
    SentryEvent *event = [[SentryEvent alloc] initWithLevel:kSentryLevelInfo];
    event.message = [[SentryMessage alloc] initWithFormatted:message];
    event.attachAllThreadsOverride = attachAllThreads;
    SentryHint *hint = [[SentryHint alloc] init];
    return [self sendEvent:event withScope:scope alwaysAttachStacktrace:NO hint:hint];
}

- (SentryId *)captureException:(NSException *)exception
{
    return [self captureException:exception withScope:[[SentryScope alloc] init]];
}

- (SentryId *)captureException:(NSException *)exception
                     withScope:(SENTRY_SWIFT_MIGRATION_ID(SentryScope))scope
{
    return [self captureException:exception withScope:scope hint:nil];
}

- (SentryId *)captureException:(NSException *)exception
                     withScope:(SENTRY_SWIFT_MIGRATION_ID(SentryScope))scope
              attachAllThreads:(NSNumber *_Nullable)attachAllThreads
{
    SentryEvent *event = [self buildExceptionEvent:exception];
    event.attachAllThreadsOverride = attachAllThreads;
    SentryHint *hint = [[SentryHint alloc] initWithException:exception];
    return [self captureEventIncrementingSessionErrorCount:event withScope:scope hint:hint];
}

- (SentryId *)captureError:(NSError *)error
{
    return [self captureError:error withScope:[[SentryScope alloc] init]];
}

- (SentryId *)captureError:(NSError *)error withScope:(SENTRY_SWIFT_MIGRATION_ID(SentryScope))scope
{
    return [self captureError:error withScope:scope hint:nil];
}

- (SentryId *)captureError:(NSError *)error
                 withScope:(SENTRY_SWIFT_MIGRATION_ID(SentryScope))scope
          attachAllThreads:(NSNumber *_Nullable)attachAllThreads
{
    SentryEvent *event = [self buildErrorEvent:error];
    event.attachAllThreadsOverride = attachAllThreads;
    SentryHint *hint = [[SentryHint alloc] initWithError:error];
    return [self captureEventIncrementingSessionErrorCount:event withScope:scope hint:hint];
}

- (SentryId *)captureEvent:(SentryEvent *)event
{
    return [self captureEvent:event withScope:[[SentryScope alloc] init]];
}

- (SentryId *)captureEvent:(SentryEvent *)event
                 withScope:(SENTRY_SWIFT_MIGRATION_ID(SentryScope))scope
{
    return [self captureEvent:event withScope:scope hint:nil];
}

- (SentryId *)captureEvent:(SentryEvent *)event
                  withScope:(SENTRY_SWIFT_MIGRATION_ID(SentryScope))scope
    additionalEnvelopeItems:(NSArray<SentryEnvelopeItem *> *)additionalEnvelopeItems
{
    SentryHint *hint = [[SentryHint alloc] init];
    // Only transactions pass additional envelope items, and the session path can't send them.
    if (additionalEnvelopeItems.count == 0 && shouldIncrementSessionErrors(event)) {
        return [self captureEventIncrementingSessionErrorCount:event
                                                     withScope:scope
                                        alwaysAttachStacktrace:NO
                                                          hint:hint];
    }
    return [self sendEvent:event
                      withScope:scope
         alwaysAttachStacktrace:NO
                   isFatalEvent:NO
        additionalEnvelopeItems:additionalEnvelopeItems
                           hint:hint];
}

- (SentryId *)captureEvent:(SentryEvent *)event
                 withScope:(SENTRY_SWIFT_MIGRATION_ID(SentryScope))scope
                      hint:(SentryHint *_Nullable)hint
{
    SentryHint *resolvedHint = hint ?: [[SentryHint alloc] init];
    if (shouldIncrementSessionErrors(event)) {
        return [self captureEventIncrementingSessionErrorCount:event
                                                     withScope:scope
                                        alwaysAttachStacktrace:NO
                                                          hint:resolvedHint];
    }
    return [self sendEvent:event withScope:scope alwaysAttachStacktrace:NO hint:resolvedHint];
}

- (SentryId *)captureError:(NSError *)error
                 withScope:(SENTRY_SWIFT_MIGRATION_ID(SentryScope))scope
                      hint:(SentryHint *_Nullable)hint
{
    SentryHint *resolvedHint = hint ?: [[SentryHint alloc] init];
    SentryEvent *event = [self buildErrorEvent:error];
    if (resolvedHint.originalError == nil) {
        resolvedHint.originalError = error;
    }
    return [self captureEventIncrementingSessionErrorCount:event withScope:scope hint:resolvedHint];
}

- (SentryId *)captureException:(NSException *)exception
                     withScope:(SENTRY_SWIFT_MIGRATION_ID(SentryScope))scope
                          hint:(SentryHint *_Nullable)hint
{
    SentryHint *resolvedHint = hint ?: [[SentryHint alloc] init];
    SentryEvent *event = [self buildExceptionEvent:exception];
    if (resolvedHint.originalException == nil) {
        resolvedHint.originalException = exception;
    }
    return [self captureEventIncrementingSessionErrorCount:event withScope:scope hint:resolvedHint];
}

- (SentryId *)captureMessage:(NSString *)message
                   withScope:(SENTRY_SWIFT_MIGRATION_ID(SentryScope))scope
                        hint:(SentryHint *_Nullable)hint
{
    SentryHint *resolvedHint = hint ?: [[SentryHint alloc] init];
    SentryEvent *event = [[SentryEvent alloc] initWithLevel:kSentryLevelInfo];
    event.message = [[SentryMessage alloc] initWithFormatted:message];
    return [self sendEvent:event withScope:scope alwaysAttachStacktrace:NO hint:resolvedHint];
}

@end

NS_ASSUME_NONNULL_END
