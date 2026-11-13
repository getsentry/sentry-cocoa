#import <Foundation/Foundation.h>

#import "SentryDefines.h"
@import _SentryPrivate;

NS_ASSUME_NONNULL_BEGIN

/**
 * Bridges Objective-C hub operations whose Swift-defined parameter types cannot be accessed from a
 * separate SwiftPM module.
 */
@interface SentryTestHubWrapper : SentryHubInternal

- (instancetype)initWithClient:(SentryClientInternal *_Nullable)client
                      andScope:(nullable SENTRY_SWIFT_MIGRATION_ID(SentryScope))scope;

- (SentryId *)wrapper_captureEvent:(SentryEvent *)event
                         withScope:(SENTRY_SWIFT_MIGRATION_ID(SentryScope))scope
           additionalEnvelopeItems:(NSArray *)additionalEnvelopeItems
    NS_SWIFT_NAME(wrapper_capture(event:scope:additionalEnvelopeItems:));

- (void)wrapper_captureTransaction:(SENTRY_SWIFT_MIGRATION_ID(SentryTransaction))transaction
                         withScope:(SENTRY_SWIFT_MIGRATION_ID(SentryScope))scope
    NS_SWIFT_NAME(wrapper_capture(transaction:with:));

- (void)wrapper_setSession:(nullable id)session;

@end

NS_ASSUME_NONNULL_END
