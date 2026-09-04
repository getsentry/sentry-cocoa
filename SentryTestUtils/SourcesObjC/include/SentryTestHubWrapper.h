#import <Foundation/Foundation.h>

@import _SentryPrivate;

NS_ASSUME_NONNULL_BEGIN

/**
 * Bridges Objective-C hub operations whose Swift-defined parameter types cannot be accessed from a
 * separate SwiftPM module.
 */
@interface SentryTestHubWrapper : SentryHubInternal

- (instancetype)initWithClient:(SentryClientInternal *_Nullable)client
                      andScope:(SentryScope *_Nullable)scope;

- (SentryId *)wrapper_captureEvent:(SentryEvent *)event
                         withScope:(SentryScope *)scope
           additionalEnvelopeItems:(NSArray *)additionalEnvelopeItems
    NS_SWIFT_NAME(wrapper_capture(event:scope:additionalEnvelopeItems:));

- (void)wrapper_setSession:(nullable id)session;

@end

NS_ASSUME_NONNULL_END
