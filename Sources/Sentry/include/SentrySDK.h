#import <Foundation/Foundation.h>

#import "SentryDefines.h"

@class SentryHub, SentryOptions, SentryEvent, SentryBreadcrumb, SentryScope, SentryUser;

@class SentryId;

NS_ASSUME_NONNULL_BEGIN

// NS_SWIFT_NAME(SDK)
/**
 "static api" for easy access to most common sentry sdk features

 try `SentryHub` for advanced features
 */
@interface SentrySDK : NSObject
SENTRY_NO_INIT

/**
 * Returns current hub
 */
+ (SentryHub *)currentHub;

/**
 * This forces a crash, useful to test the SentryCrash integration
 */
+ (void)crash;

/**
 * Sets current hub
 */
+ (void)setCurrentHub:(SentryHub *)hub;

/**
 * Inits and configures Sentry (SentryHub, SentryClient) and sets up all integrations.
 */
+ (void)startWithOptions:(NSDictionary<NSString *, id> *)optionsDict NS_SWIFT_NAME(start(options:));

/**
 * Inits and configures Sentry (SentryHub, SentryClient) and sets up all integrations.
 */
+ (void)startWithOptionsObject:(SentryOptions *)options NS_SWIFT_NAME(start(options:));

/**
 * Inits and configures Sentry (SentryHub, SentryClient) and sets up all integrations. Make sure to
 * set a valid DSN otherwise.
 */
+ (void)startWithConfigureOptions:(void (^)(SentryOptions *options))configureOptions
    NS_SWIFT_NAME(start(configureOptions:));

/**
 * captures an event aka. sends an event to sentry
 *
 * uses default `SentryHub`
 *
 * USAGE: Create a `SentryEvent`, fill it up with data, and send it with this
 * method.
 *
 * @return The SentryId of the event or SentryId.empty if the event is not sent.
 */
+ (SentryId *)captureEvent:(SentryEvent *)event NS_SWIFT_NAME(capture(event:));
+ (SentryId *)captureEvent:(SentryEvent *)event
                 withScope:(SentryScope *_Nullable)scope NS_SWIFT_NAME(capture(event:scope:));
+ (SentryId *)captureEvent:(SentryEvent *)event
            withScopeBlock:(void (^)(SentryScope *scope))block NS_SWIFT_NAME(capture(event:block:));

/**
 * captures an error aka. sends an NSError to sentry.

 * uses default `SentryHub`
 *
 * @return The SentryId of the event or SentryId.empty if the event is not sent.
 */
+ (SentryId *)captureError:(NSError *)error NS_SWIFT_NAME(capture(error:));
+ (SentryId *)captureError:(NSError *)error
                 withScope:(SentryScope *_Nullable)scope NS_SWIFT_NAME(capture(error:scope:));
+ (SentryId *)captureError:(NSError *)error
            withScopeBlock:(void (^)(SentryScope *scope))block NS_SWIFT_NAME(capture(error:block:));

/**
 * captures an exception aka. sends an NSException to sentry.


 * uses default `SentryHub`
 * @return The SentryId of the event or SentryId.empty if the event is not sent.
 */
+ (SentryId *)captureException:(NSException *)exception NS_SWIFT_NAME(capture(exception:));
+ (SentryId *)captureException:(NSException *)exception
                     withScope:(SentryScope *_Nullable)scope
    NS_SWIFT_NAME(capture(exception:scope:));
+ (SentryId *)captureException:(NSException *)exception
                withScopeBlock:(void (^)(SentryScope *scope))block
    NS_SWIFT_NAME(capture(exception:block:));

/**
 * captures a message aka. sends a string to sentry.
 *
 * uses default `SentryHub`
 *
 * @return The SentryId of the event or SentryId.empty if the event is not sent.
 */
+ (SentryId *)captureMessage:(NSString *)message NS_SWIFT_NAME(capture(message:));
+ (SentryId *)captureMessage:(NSString *)message
                   withScope:(SentryScope *_Nullable)scope NS_SWIFT_NAME(capture(message:scope:));
+ (SentryId *)captureMessage:(NSString *)message
              withScopeBlock:(void (^)(SentryScope *scope))block
    NS_SWIFT_NAME(capture(message:block:));

/**
 * Adds a SentryBreadcrumb to the current Scope on the `currentHub`.
 * If the total number of breadcrumbs exceeds the `max_breadcrumbs` setting, the
 * oldest breadcrumb is removed.
 */
+ (void)addBreadcrumb:(SentryBreadcrumb *)crumb NS_SWIFT_NAME(addBreadcrumb(crumb:));

//- `configure_scope(callback)`: Calls a callback with a scope object that can
// be reconfigured. This is used to attach contextual data for future events in
// the same scope.
+ (void)configureScope:(void (^)(SentryScope *scope))callback;

/**
 * Set logLevel for the current client default kSentryLogLevelError
 */
@property (nonatomic, class) SentryLogLevel logLevel;

/**
 * Set global user -> thus will be sent with every event
 */
+ (void)setUser:(SentryUser *_Nullable)user;

@end

NS_ASSUME_NONNULL_END
