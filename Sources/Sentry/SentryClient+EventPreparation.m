#import "SentryClient+EventPreparation.h"
#import "SentryLogC.h"
#import "SentrySwift.h"

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

@implementation SentryClientEventPreparationLinker
@end

@implementation SentryClientInternal (EventPreparation)

- (nullable SENTRY_SWIFT_MIGRATION_ID(SentryEvent))prepareEvent:(SENTRY_SWIFT_MIGRATION_ID(
                                                                    SentryEvent))untypedEvent
                                                      withScope:(SentryScope *)scope
                                         alwaysAttachStacktrace:(BOOL)alwaysAttachStacktrace
{
    SentryEvent *event = untypedEvent;
    return [self prepareEvent:event
                     withScope:scope
        alwaysAttachStacktrace:alwaysAttachStacktrace
                  isFatalEvent:NO];
}

- (nullable SENTRY_SWIFT_MIGRATION_ID(SentryEvent))prepareEvent:(nullable SENTRY_SWIFT_MIGRATION_ID(
                                                                    SentryEvent))untypedEvent
                                                      withScope:(SentryScope *)scope
                                         alwaysAttachStacktrace:(BOOL)alwaysAttachStacktrace
                                                   isFatalEvent:(BOOL)isFatalEvent
{
    SentryEvent *_Nullable event = untypedEvent;
    SentryHint *hint = [[SentryHint alloc] init];
    return [self prepareEvent:event
                     withScope:scope
        alwaysAttachStacktrace:alwaysAttachStacktrace
                  isFatalEvent:isFatalEvent
                          hint:hint];
}

- (nullable SENTRY_SWIFT_MIGRATION_ID(SentryEvent))prepareEvent:(nullable SENTRY_SWIFT_MIGRATION_ID(
                                                                    SentryEvent))untypedEvent
                                                      withScope:(SentryScope *)scope
                                         alwaysAttachStacktrace:(BOOL)alwaysAttachStacktrace
                                                   isFatalEvent:(BOOL)isFatalEvent
                                                           hint:(SentryHint *)hint
{
    SentryEvent *_Nullable event = untypedEvent;
    SentryScope *cs = [self.currentScopeStorage scope];
    return [self prepareEvent:event
                     withScope:scope
        alwaysAttachStacktrace:alwaysAttachStacktrace
                  isFatalEvent:isFatalEvent
                  currentScope:cs
                          hint:hint];
}

- (nullable SENTRY_SWIFT_MIGRATION_ID(SentryEvent))prepareEvent:(nullable SENTRY_SWIFT_MIGRATION_ID(
                                                                    SentryEvent))untypedEvent
                                                      withScope:(SentryScope *)scope
                                         alwaysAttachStacktrace:(BOOL)alwaysAttachStacktrace
                                                   isFatalEvent:(BOOL)isFatalEvent
                                                   currentScope:(SentryScope *_Nullable)currentScope
{
    SentryEvent *_Nullable event = untypedEvent;
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

- (nullable SENTRY_SWIFT_MIGRATION_ID(SentryEvent))callEventProcessors:(SENTRY_SWIFT_MIGRATION_ID(
                                                                           SentryEvent))untypedEvent
{
    SentryEvent *event = untypedEvent;
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
