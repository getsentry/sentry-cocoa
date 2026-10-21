#import "SentryClient.h"

@class SentryAttachment;
@class SentryEnvelopeItem;
@class SentryHint;
@class SentrySession;

NS_ASSUME_NONNULL_BEGIN

// Event is a Swift class, so these declarations use id. Swift callers keep the
// NS_SWIFT_NAME that the typed declarations previously imported as.

@interface SentryClientInternal (SwiftPrivate)

- (SentryId *)captureEvent:(SENTRY_SWIFT_MIGRATION_ID(SentryEvent))event
    NS_SWIFT_NAME(capture(event:));

- (SentryId *)captureEvent:(SENTRY_SWIFT_MIGRATION_ID(SentryEvent))event
                 withScope:(SentryScope *)scope NS_SWIFT_NAME(capture(event:scope:));

- (NSArray<SentryAttachment *> *)
    processAttachmentsForEvent:(SENTRY_SWIFT_MIGRATION_ID(SentryEvent))event
                   attachments:(NSArray<SentryAttachment *> *)attachments;

- (SentryId *)captureEvent:(SENTRY_SWIFT_MIGRATION_ID(SentryEvent))event
                  withScope:(SentryScope *)scope
    additionalEnvelopeItems:(NSArray<SentryEnvelopeItem *> *)additionalEnvelopeItems
    NS_SWIFT_NAME(capture(event:scope:additionalEnvelopeItems:));

- (SentryId *)captureEvent:(SENTRY_SWIFT_MIGRATION_ID(SentryEvent))event
                 withScope:(SentryScope *)scope
                      hint:(nullable SentryHint *)hint NS_SWIFT_NAME(capture(event:scope:hint:));

- (nullable SENTRY_SWIFT_MIGRATION_ID(SentryEvent))prepareEvent:(SENTRY_SWIFT_MIGRATION_ID(
                                                                    SentryEvent))event
                                                      withScope:(SentryScope *)scope
                                         alwaysAttachStacktrace:(BOOL)alwaysAttachStacktrace;

- (nullable SENTRY_SWIFT_MIGRATION_ID(SentryEvent))prepareEvent:(nullable SENTRY_SWIFT_MIGRATION_ID(
                                                                    SentryEvent))event
                                                      withScope:(SentryScope *)scope
                                         alwaysAttachStacktrace:(BOOL)alwaysAttachStacktrace
                                                   isFatalEvent:(BOOL)isFatalEvent;

- (nullable SENTRY_SWIFT_MIGRATION_ID(SentryEvent))prepareEvent:(nullable SENTRY_SWIFT_MIGRATION_ID(
                                                                    SentryEvent))event
                                                      withScope:(SentryScope *)scope
                                         alwaysAttachStacktrace:(BOOL)alwaysAttachStacktrace
                                                   isFatalEvent:(BOOL)isFatalEvent
                                                           hint:(SentryHint *)hint;

- (nullable SENTRY_SWIFT_MIGRATION_ID(
    SentryEvent))prepareEvent:(nullable SENTRY_SWIFT_MIGRATION_ID(SentryEvent))event
                    withScope:(SentryScope *)scope
       alwaysAttachStacktrace:(BOOL)alwaysAttachStacktrace
                 isFatalEvent:(BOOL)isFatalEvent
                 currentScope:(nullable SentryScope *)currentScope;

- (nullable SENTRY_SWIFT_MIGRATION_ID(SentryEvent))callEventProcessors:(SENTRY_SWIFT_MIGRATION_ID(
                                                                           SentryEvent))event;

- (SentryId *)sendEvent:(SENTRY_SWIFT_MIGRATION_ID(SentryEvent))event
                 withScope:(SentryScope *)scope
    alwaysAttachStacktrace:(BOOL)alwaysAttachStacktrace;

- (SentryId *)sendEvent:(SENTRY_SWIFT_MIGRATION_ID(SentryEvent))event
                 withScope:(SentryScope *)scope
    alwaysAttachStacktrace:(BOOL)alwaysAttachStacktrace
                      hint:(SentryHint *)hint;

- (SentryId *)sendEvent:(SENTRY_SWIFT_MIGRATION_ID(SentryEvent))event
                 withScope:(SentryScope *)scope
    alwaysAttachStacktrace:(BOOL)alwaysAttachStacktrace
              isFatalEvent:(BOOL)isFatalEvent;

- (SentryId *)sendEvent:(SENTRY_SWIFT_MIGRATION_ID(SentryEvent))event
                 withScope:(SentryScope *)scope
    alwaysAttachStacktrace:(BOOL)alwaysAttachStacktrace
              isFatalEvent:(BOOL)isFatalEvent
                      hint:(SentryHint *)hint;

- (SentryId *)sendEvent:(SENTRY_SWIFT_MIGRATION_ID(SentryEvent))event
                  withScope:(SentryScope *)scope
     alwaysAttachStacktrace:(BOOL)alwaysAttachStacktrace
               isFatalEvent:(BOOL)isFatalEvent
    additionalEnvelopeItems:(NSArray<SentryEnvelopeItem *> *)additionalEnvelopeItems;

- (SentryId *)sendEvent:(SENTRY_SWIFT_MIGRATION_ID(SentryEvent))event
                  withScope:(SentryScope *)scope
     alwaysAttachStacktrace:(BOOL)alwaysAttachStacktrace
               isFatalEvent:(BOOL)isFatalEvent
    additionalEnvelopeItems:(NSArray<SentryEnvelopeItem *> *)additionalEnvelopeItems
                       hint:(SentryHint *)hint;

- (SentryId *)sendEvent:(SENTRY_SWIFT_MIGRATION_ID(SentryEvent))event
            withSession:(nullable SentrySession *)session
              withScope:(SentryScope *)scope;

- (SentryId *)sendEvent:(SENTRY_SWIFT_MIGRATION_ID(SentryEvent))event
            withSession:(nullable SentrySession *)session
              withScope:(SentryScope *)scope
                   hint:(SentryHint *)hint;

- (SentryId *)captureFatalEvent:(SENTRY_SWIFT_MIGRATION_ID(SentryEvent))event
                      withScope:(SentryScope *)scope NS_SWIFT_NAME(captureFatalEvent(_:with:));

- (SentryId *)captureFatalEvent:(SENTRY_SWIFT_MIGRATION_ID(SentryEvent))event
                    withSession:(SentrySession *)session
                      withScope:(SentryScope *)scope NS_SWIFT_NAME(captureFatalEvent(_:with:with:));

- (SentryId *)captureEventIncrementingSessionErrorCount:(SENTRY_SWIFT_MIGRATION_ID(
                                                            SentryEvent))event
                                              withScope:(SentryScope *)scope;

- (SentryId *)captureEventIncrementingSessionErrorCount:(SENTRY_SWIFT_MIGRATION_ID(
                                                            SentryEvent))event
                                              withScope:(SentryScope *)scope
                                                   hint:(SentryHint *)hint;

@end

NS_ASSUME_NONNULL_END
