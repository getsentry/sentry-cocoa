#import "SentryDefines.h"
@import _SentryPrivate;

NS_ASSUME_NONNULL_BEGIN

// Swift-owned parameters must be erased at this Clang boundary. The selector still invokes
// the real SDK initializer, not the mock client's overrides.
@interface SentryClientInternal (TestInit)

- (instancetype)
         initWithOptions:(NSObject *)options
            dateProvider:(SENTRY_SWIFT_MIGRATION_ID(id<SentryCurrentDateProvider>))dateProvider
        transportAdapter:(SENTRY_SWIFT_MIGRATION_ID(SentryTransportAdapter))transportAdapter
             fileManager:(SENTRY_SWIFT_MIGRATION_ID(SentryFileManager))fileManager
         threadInspector:(SENTRY_SWIFT_MIGRATION_ID(SentryDefaultThreadInspector))threadInspector
      debugImageProvider:(SENTRY_SWIFT_MIGRATION_ID(SentryDebugImageProvider))debugImageProvider
                  random:(SENTRY_SWIFT_MIGRATION_ID(id<SentryRandomProtocol>))random
                  locale:(NSLocale *)locale
                timezone:(NSTimeZone *)timezone
    eventContextEnricher:(SENTRY_SWIFT_MIGRATION_ID(
                             id<SentryEventContextEnricher>))eventContextEnricher
        binaryImageCache:(SENTRY_SWIFT_MIGRATION_ID(SentryBinaryImageCache))binaryImageCache
    dispatchQueueWrapper:(SENTRY_SWIFT_MIGRATION_ID(SentryDispatchQueueWrapper))dispatchQueueWrapper
    NS_SWIFT_NAME(init(testOptions:dateProvider:transportAdapter:fileManager:threadInspector:debugImageProvider:random:locale:timezone:eventContextEnricher:binaryImageCache:dispatchQueueWrapper:));

@end

@interface SentryClientInternal (TestAccess)
- (SENTRY_SWIFT_MIGRATION_ID(SentryFileManager))fileManager NS_SWIFT_NAME(test_fileManager());
- (void)setFileManager:(SENTRY_SWIFT_MIGRATION_ID(SentryFileManager))fileManager
    NS_SWIFT_NAME(test_setFileManager(_:));
- (SentryId *)captureFatalEvent:(SentryEvent *)event
                    withSession:(SENTRY_SWIFT_MIGRATION_ID(SentrySession))session
                      withScope:(SentryScope *)scope
    NS_SWIFT_NAME(test_captureFatalEvent(_:session:scope:));

- (void)captureSession:(SENTRY_SWIFT_MIGRATION_ID(SentrySession))session
    NS_SWIFT_NAME(capture(session:));
- (void)captureReplayEvent:(SENTRY_SWIFT_MIGRATION_ID(SentryReplayEvent))event
           replayRecording:(SENTRY_SWIFT_MIGRATION_ID(SentryReplayRecording))recording
                     video:(NSURL *)video
                 withScope:(SentryScope *)scope
    NS_SWIFT_NAME(test_captureReplayEvent(_:recording:video:scope:));
- (void)storeEnvelope:(SENTRY_SWIFT_MIGRATION_ID(SentryEnvelope))envelope
    NS_SWIFT_NAME(test_storeEnvelope(_:));

- (SentryId *)captureEvent:(SentryEvent *)event
                 withScope:(SentryScope *)scope
                      hint:(nullable SENTRY_SWIFT_MIGRATION_ID(SentryHint))hint
    NS_SWIFT_NAME(capture(event:scope:hint:));
- (SentryId *)captureError:(NSError *)error
                 withScope:(SentryScope *)scope
                      hint:(nullable SENTRY_SWIFT_MIGRATION_ID(SentryHint))hint
    NS_SWIFT_NAME(capture(error:scope:hint:));
- (SentryId *)captureException:(NSException *)exception
                     withScope:(SentryScope *)scope
                          hint:(nullable SENTRY_SWIFT_MIGRATION_ID(SentryHint))hint
    NS_SWIFT_NAME(capture(exception:scope:hint:));
- (SentryId *)captureMessage:(NSString *)message
                   withScope:(SentryScope *)scope
                        hint:(nullable SENTRY_SWIFT_MIGRATION_ID(SentryHint))hint
    NS_SWIFT_NAME(capture(message:scope:hint:));
- (SentryId *)captureEvent:(SentryEvent *)event
                  withScope:(SentryScope *)scope
    additionalEnvelopeItems:(NSArray *)items
    NS_SWIFT_NAME(capture(event:scope:additionalEnvelopeItems:));
@end

// Erased override seam for the session delegate declared by SentryClient+Private.h.
@interface SentryTestSessionDelegateWrapper : NSObject <SentrySessionDelegate>
- (nullable SENTRY_SWIFT_MIGRATION_ID(SentrySession))wrapper_incrementSessionErrors;
@end

NS_ASSUME_NONNULL_END
