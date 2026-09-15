#import <Foundation/Foundation.h>

#import "SentryDefines.h"
@import _SentryPrivate;

NS_ASSUME_NONNULL_BEGIN

/**
 * Bridges Objective-C SDK selectors whose Swift-defined parameter types cannot be overridden
 * directly from a separate SwiftPM module.
 */
@interface SentryTestClientWrapper : SentryClientInternal

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
    eventContextEnricher:(SENTRY_SWIFT_MIGRATION_ID(SentryEventContextEnricher))eventContextEnricher
        binaryImageCache:(SENTRY_SWIFT_MIGRATION_ID(SentryBinaryImageCache))binaryImageCache
    dispatchQueueWrapper:
        (SENTRY_SWIFT_MIGRATION_ID(SentryDispatchQueueWrapper))dispatchQueueWrapper;

- (void)wrapper_captureSession:(SENTRY_SWIFT_MIGRATION_ID(SentrySession))session
    NS_SWIFT_NAME(wrapper_capture(session:));

- (SentryId *)wrapper_captureEvent:(SentryEvent *)event
                         withScope:(SentryScope *)scope
           additionalEnvelopeItems:(NSArray *)additionalEnvelopeItems
    NS_SWIFT_NAME(wrapper_capture(event:scope:additionalEnvelopeItems:));

- (SentryId *)wrapper_captureFatalEvent:(SentryEvent *)event
                            withSession:(SENTRY_SWIFT_MIGRATION_ID(SentrySession))session
                              withScope:(SentryScope *)scope
    NS_SWIFT_NAME(wrapper_captureFatalEvent(_:session:scope:));

- (void)wrapper_captureFeedback:(SENTRY_SWIFT_MIGRATION_ID(SentryFeedback))feedback
                      withScope:(SentryScope *)scope
    NS_SWIFT_NAME(wrapper_capture(feedback:scope:));

- (void)wrapper_captureEnvelope:(SENTRY_SWIFT_MIGRATION_ID(SentryEnvelope))envelope
    NS_SWIFT_NAME(wrapper_capture(envelope:));

- (void)wrapper_storeEnvelope:(SENTRY_SWIFT_MIGRATION_ID(SentryEnvelope))envelope
    NS_SWIFT_NAME(wrapper_store(envelope:));

- (void)wrapper_recordLostEvent:(NSUInteger)category
                         reason:(NSUInteger)reason
    NS_SWIFT_NAME(wrapper_recordLostEvent(_:reason:));

- (void)wrapper_recordLostEvent:(NSUInteger)category
                         reason:(NSUInteger)reason
                       quantity:(NSUInteger)quantity
    NS_SWIFT_NAME(wrapper_recordLostEvent(_:reason:quantity:));

@end

NS_ASSUME_NONNULL_END
