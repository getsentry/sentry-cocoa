#import "SentryClient+Private.h"
#import "SentryEvent+Private.h"
#import "SentryLogC.h"
#import "SentrySwift.h"
#import "SentryTransaction+Private.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryClientInternal ()

- (SentryCurrentScopeStorage *)currentScopeStorage;
- (id<SentryRandomProtocol>)random;

- (nullable SentryEvent *)prepareEvent:(nullable SentryEvent *)event
                             withScope:(SentryScope *)scope
                alwaysAttachStacktrace:(BOOL)alwaysAttachStacktrace
                          isFatalEvent:(BOOL)isFatalEvent
                          currentScope:(nullable SentryScope *)currentScope
                                  hint:(SentryHint *)hint;

@end

@implementation SentryClientInternal (EventPreparation)

- (SentryEvent *_Nullable)prepareEvent:(SentryEvent *)event
                             withScope:(SentryScope *)scope
                alwaysAttachStacktrace:(BOOL)alwaysAttachStacktrace
{
    return [self prepareEvent:event
                     withScope:scope
        alwaysAttachStacktrace:alwaysAttachStacktrace
                  isFatalEvent:NO];
}

- (SentryEvent *_Nullable)prepareEvent:(SentryEvent *_Nullable)event
                             withScope:(SentryScope *)scope
                alwaysAttachStacktrace:(BOOL)alwaysAttachStacktrace
                          isFatalEvent:(BOOL)isFatalEvent
{
    SentryHint *hint = [[SentryHint alloc] init];
    return [self prepareEvent:event
                     withScope:scope
        alwaysAttachStacktrace:alwaysAttachStacktrace
                  isFatalEvent:isFatalEvent
                          hint:hint];
}

- (SentryEvent *_Nullable)prepareEvent:(SentryEvent *_Nullable)event
                             withScope:(SentryScope *)scope
                alwaysAttachStacktrace:(BOOL)alwaysAttachStacktrace
                          isFatalEvent:(BOOL)isFatalEvent
                                  hint:(SentryHint *)hint
{
    SentryScope *cs = [self.currentScopeStorage scope];
    return [self prepareEvent:event
                     withScope:scope
        alwaysAttachStacktrace:alwaysAttachStacktrace
                  isFatalEvent:isFatalEvent
                  currentScope:cs
                          hint:hint];
}

- (SentryEvent *_Nullable)prepareEvent:(SentryEvent *_Nullable)event
                             withScope:(SentryScope *)scope
                alwaysAttachStacktrace:(BOOL)alwaysAttachStacktrace
                          isFatalEvent:(BOOL)isFatalEvent
                          currentScope:(SentryScope *_Nullable)currentScope
{
    SentryHint *hint = [[SentryHint alloc] init];
    return [self prepareEvent:event
                     withScope:scope
        alwaysAttachStacktrace:alwaysAttachStacktrace
                  isFatalEvent:isFatalEvent
                  currentScope:currentScope
                          hint:hint];
}

- (void)recordPartiallyDroppedSpans:(SentryTransaction *)transaction
                         withReason:(SentryDiscardReason)reason
               withCurrentSpanCount:(NSUInteger *)currentSpanCount
{
    // If some spans got removed we still report them as dropped
    NSUInteger spanCountAfter = transaction.spans.count;
    NSUInteger droppedSpanCount = *currentSpanCount - spanCountAfter;
    if (droppedSpanCount > 0) {
        [self recordLostSpanWithReason:reason quantity:droppedSpanCount];
    }
    *currentSpanCount = spanCountAfter;
}

- (BOOL)isSampled:(NSNumber *_Nullable)sampleRate
{
    if (sampleRate == nil) {
        return NO;
    }

    return [self.random nextNumber] <= sampleRate.doubleValue ? NO : YES;
}

- (SentryEvent *_Nullable)callEventProcessors:(SentryEvent *)event
{
    SentryGlobalEventProcessor *globalEventProcessor
        = SentryDependencyContainer.sharedInstance.globalEventProcessor;

    SentryEvent *newEvent = [globalEventProcessor reportAll:event];
    if (newEvent == nil) {
        SENTRY_LOG_DEBUG(@"SentryScope callEventProcessors: An event processor decided to "
                         @"remove this event.");
    }
    return newEvent;
}

- (void)recordLost:(BOOL)eventIsNotATransaction reason:(SentryDiscardReason)reason
{
    if (eventIsNotATransaction) {
        [self recordLostEvent:SentryDataCategoryError reason:reason];
    } else {
        [self recordLostEvent:SentryDataCategoryTransaction reason:reason];
    }
}

- (void)recordLostSpanWithReason:(SentryDiscardReason)reason quantity:(NSUInteger)quantity
{
    [self recordLostEvent:SentryDataCategorySpan reason:reason quantity:quantity];
}

@end

NS_ASSUME_NONNULL_END
