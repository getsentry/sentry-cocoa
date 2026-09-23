#import "SentryClient+Private.h"
#import "SentryEvent+Private.h"
#import "SentryMessage.h"
#import "SentryScope+Private.h"
#import "SentrySwift.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryClientInternal ()

- (SentryEvent *)buildExceptionEvent:(NSException *)exception;
- (SentryEvent *)buildErrorEvent:(NSError *)error;

- (SentryId *)sendEvent:(SentryEvent *)event
                 withScope:(SentryScope *)scope
    alwaysAttachStacktrace:(BOOL)alwaysAttachStacktrace
                      hint:(SentryHint *)hint;

- (SentryId *)sendEvent:(SentryEvent *)event
                  withScope:(SentryScope *)scope
     alwaysAttachStacktrace:(BOOL)alwaysAttachStacktrace
               isFatalEvent:(BOOL)isFatalEvent
    additionalEnvelopeItems:(NSArray<SentryEnvelopeItem *> *)additionalEnvelopeItems
                       hint:(SentryHint *)hint;

@end

@implementation SentryClientInternal (EventCapture)

- (SentryId *)captureMessage:(NSString *)message
{
    return [self captureMessage:message withScope:[[SentryScope alloc] init]];
}

- (SentryId *)captureMessage:(NSString *)message withScope:(SentryScope *)scope
{
    return [self captureMessage:message withScope:scope hint:nil];
}

- (SentryId *)captureMessage:(NSString *)message
                   withScope:(SentryScope *)scope
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

- (SentryId *)captureException:(NSException *)exception withScope:(SentryScope *)scope
{
    return [self captureException:exception withScope:scope hint:nil];
}

- (SentryId *)captureException:(NSException *)exception
                     withScope:(SentryScope *)scope
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

- (SentryId *)captureError:(NSError *)error withScope:(SentryScope *)scope
{
    return [self captureError:error withScope:scope hint:nil];
}

- (SentryId *)captureError:(NSError *)error
                 withScope:(SentryScope *)scope
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

- (SentryId *)captureEvent:(SentryEvent *)event withScope:(SentryScope *)scope
{
    return [self captureEvent:event withScope:scope hint:nil];
}

- (SentryId *)captureEvent:(SentryEvent *)event
                  withScope:(SentryScope *)scope
    additionalEnvelopeItems:(NSArray<SentryEnvelopeItem *> *)additionalEnvelopeItems
{
    SentryHint *hint = [[SentryHint alloc] init];
    return [self sendEvent:event
                      withScope:scope
         alwaysAttachStacktrace:NO
                   isFatalEvent:NO
        additionalEnvelopeItems:additionalEnvelopeItems
                           hint:hint];
}

- (SentryId *)captureEvent:(SentryEvent *)event
                 withScope:(SentryScope *)scope
                      hint:(SentryHint *_Nullable)hint
{
    SentryHint *resolvedHint = hint ?: [[SentryHint alloc] init];
    return [self sendEvent:event withScope:scope alwaysAttachStacktrace:NO hint:resolvedHint];
}

- (SentryId *)captureError:(NSError *)error
                 withScope:(SentryScope *)scope
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
                     withScope:(SentryScope *)scope
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
                   withScope:(SentryScope *)scope
                        hint:(SentryHint *_Nullable)hint
{
    SentryHint *resolvedHint = hint ?: [[SentryHint alloc] init];
    SentryEvent *event = [[SentryEvent alloc] initWithLevel:kSentryLevelInfo];
    event.message = [[SentryMessage alloc] initWithFormatted:message];
    return [self sendEvent:event withScope:scope alwaysAttachStacktrace:NO hint:resolvedHint];
}

@end

NS_ASSUME_NONNULL_END
